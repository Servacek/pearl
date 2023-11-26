--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

-------------------------------------
-- [[ Contants ]]
-------------------------------------

local QUERIES = PEARL.SteamAPI.QUERIES

local MAX_PROFILE_REP = 100
local MIN_PROFILE_REP = 1
local BAD_PROFILE_REP = 25

local MAX_COMMENT_REP = 50
local MIN_COMMENT_REP = 0

local MIN_REP_PROFILE_AGE = 3 -- Players start to get reputation for older accounts

local REP_PER_TOXIC_NAME        = -10
local REP_PER_BANNED_FRIEND     = -25
local REP_PER_POSITIVE_COMMENT  = 20
local REP_PER_NEGATIVE_COMMENT  = -20
local REP_PER_UNMATCHED_LOCALE = -10

local REP_PER_ACCOUNT_YEAR  = 5

local REP_PER_BANNED_CLAN   = -50
local REP_PER_VAC_BAN       = -25
local REP_PER_GAME_BAN      = -40
local REP_PER_COMMUNITY_BAN = -15
local REP_PER_ECONOMY_BAN   = -10

--- Check only the first 50 comments of a profile
local MAX_COMMENTS_CHECK_COUNT = 25
local MAX_NEGATIVE_COMMENTS_PERCENT = .6

local COMMENT_PATTERN = "<bdi>(.-)<\\/bdi>.-<div class=\\\"commentthread_comment_text\\\" id=\\\"comment_content_%d+\\\">(.-)<\\/div>"

local POSITIVE_COMMENT_PATTERN = "+rep"
local NEGATIVE_COMMENT_PATTERN = "-rep"

-------------------------------------
-- [[ Declarations ]]
-------------------------------------

local OnToxicNameDetected, OnBannedFriendsDetected

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function OnBannedFriendsDetected(userid, count)
    return PEARL.DiscordReporter:SendRawReportString("One or more of player's friends are banned! "..tostring(count))
end

function OnToxicNameDetected(steamid)
    return PEARL.DiscordReporter:SendRawReportString("Toxic Name Detected in Players name history!")
end

local function OnBadProfileRep(userid)
    return PEARL.DiscordReporter:SendRawReportString("Profile Repuation For Client Is TOO BAD!")
end

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function IsCommentNegative(comment)
    return comment:lower():find(NEGATIVE_COMMENT_PATTERN) or ProfanityFilter:Detect(comment)
end

local function IsCommentPositive(comment)
    return comment:lower():find(POSITIVE_COMMENT_PATTERN)
end

local function CalculateRepInComments(comments_html, profileusername)
    local ignore = {
        -- Ignore comments from the profile author itself.
        [profileusername] = true
    }

    local neg_count = 0
    local pos_count = 0
    local tot_count = 0
    for author, comment in comments_html:gmatch(COMMENT_PATTERN) do
        tot_count = tot_count + 1

        author = author:strip()
        if not ignore[author] then
            ignore[author] = true

            if IsCommentNegative(comment) then
                neg_count = neg_count + 1
            elseif IsCommentPositive(comment) then
                pos_count = pos_count + 1
            else -- For Neutral Comments
                ignore[author] = false
            end
        end
    end

    if tot_count <= 0 then
        return 0
    end

    -- Handle Special Cases
    local neg_percent = neg_count / tot_count
    if neg_percent > MAX_NEGATIVE_COMMENTS_PERCENT then
        return -1
    end

    if neg_count == 0 and pos_count > 2 then
        return MAX_COMMENT_REP
    end

    return math.min((pos_count * REP_PER_POSITIVE_COMMENT) + (neg_count * REP_PER_NEGATIVE_COMMENT), MAX_COMMENT_REP)
end

local function CalculateProfileData(steamid, cfd, cb)
    -- Keep these in sync with the names in the DB.
    local data = {
        profilerep = MAX_PROFILE_REP,
        -- Let's make it fail safe.
        communityprofile = true,
    }

    PEARL.SteamAPI:CreateDataQuerySequenceFor(steamid, function()
        if type(cb) == "function" then
            cb(data)
        end
    end)

    -- VAC - Valve Anti-Cheat
    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_BANS, function(query)
        PEARL.debug("P_BANS:", data.profilerep)

        local player = query and query.players and query.players[1]
        if not player then
            PEARL.error("Invalid query response received!")
            return
        end

        if player.CommunityBanned then
            data.profilerep = data.profilerep + REP_PER_COMMUNITY_BAN
        end

        if type(player.EconomyBan) == "string" and player.EconomyBan ~= "none" then
            data.profilerep = data.profilerep + REP_PER_ECONOMY_BAN
        end

        if type(player.NumberOfVACBans) == "number" and player.NumberOfVACBans > 0 then
            data.profilerep = data.profilerep + (player.NumberOfVACBans * REP_PER_VAC_BAN)
        end

        if type(player.NumberOfGameBans) == "number" and player.NumberOfGameBans > 0 then
            data.profilerep = data.profilerep + (player.NumberOfGameBans * REP_PER_GAME_BAN)
        end
    end)

    -- This will also check the currently used name.
    PEARL.SteamAPI:AddRawQueryToSequence(steamid, QUERIES.P_NAMEHISTORY, function(str)
        PEARL.debug("P_NAMEHISTORY:", str, data.profilerep)

        local toxicity_count = ProfanityFilter:CountSwears(str)
        if toxicity_count > 0 then
            OnToxicNameDetected(steamid)

            data.profilerep = data.profilerep + (toxicity_count * REP_PER_TOXIC_NAME)
        end
    end)

    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_FRIENDLIST, function(query)
        PEARL.debug("P_FRIENDLIST:", data.rep)

        if not (query.friendslist and query.friendslist.friends) then
            return -- no friends or profile is private
        end

        -- Count banned friends.
        local banned_count = 0
        for _, friend in pairs(query.friendslist.friends) do
            -- Attempt to conver the Steam ID to Klei ID since its used more frequently for banning.
            local userid = PEARL.DB:MapSteamID(friend.steamid) or friend.steamid
            if PEARL.BlackList:Contains(userid) then
                banned_count = banned_count + 1
            end
        end

        if banned_count > 0 then
            PEARL.info("Banned friends detected for user!")
            OnBannedFriendsDetected(steamid, banned_count)

            data.profilerep = data.profilerep + (banned_count * REP_PER_BANNED_FRIEND)
        end
    end)

    PEARL.SteamAPI:AddRawQueryToSequence(steamid, QUERIES.P_COMMENTS, function(str)
        PEARL.debug("P_COMMENTS", data.profilerep)

        if type(str) ~= "string" then
            return
        end

        local comment_rep = CalculateRepInComments(str, cfd.username)
        if comment_rep < MIN_COMMENT_REP then
            data.profilerep = -MAX_COMMENT_REP
        else
            data.profilerep = data.profilerep + comment_rep
        end
    end, MAX_COMMENTS_CHECK_COUNT)

    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_SUMMARIES, function(query)
        PEARL.debug("P_SUMMARIES", data.rep)

        local player = query and query.response and query.response.players and query.response.players[1]
        if not player then
            PEARL.error("Invalid query response received!")
            return
        end

        data.loccountrycode = player.loccountrycode
        data.timecreated    = player.timecreated
        data.profilerep     = MAX_PROFILE_REP

        -- If the locale on profile doesn't match the locale
        -- set on the steam profile (only if set).
        if (
            type(player.loccountrycode) == "string" and
            type(cfd.locale) == "string" and
            player.loccountrycode ~= cfd.locale
        ) then
            data.profilerep = data.profilerep + REP_PER_UNMATCHED_LOCALE
        end

        --- Maybe we should check all the clans here?
        local primaryclanid = tostring(player.primaryclanid)
        if PEARL.CONFIG.STEAM_GROUP_BLOCKLIST[primaryclanid] == true or
            table.contains(PEARL.CONFIG.STEAM_GROUP_BLOCKLIST, primaryclanid)
        then
            data.profilerep = data.profilerep + REP_PER_BANNED_CLAN
        end

        if player.timecreated then
            local acc_years = os.timediffyears(tonumber(player.timecreated))

            -- Usually older accounts mean older audience which means
            -- less probability for griefing.
            if acc_years >= MIN_REP_PROFILE_AGE then
                data.profilerep = data.profilerep + (acc_years * REP_PER_ACCOUNT_YEAR)
            end
        end

        print("COMMUNITYPROFILE:", tostring(player.profilestate))
        if tostring(player.profilestate) ~= "1" then
            data.communityprofile = false
        end

        data.avatar = player.avatarfull or player.avatarmedium or player.avatar
    end)

    PEARL.SteamAPI:ExecuteDataQuerySequenceFor(steamid)
end

local function CalculateProfileDataForUser(userid, cfd, ...)
    local steamid = userid and TheNet:GetNetIdForUser(userid) -- "76561198050735090"
    if not steamid then
        return PEARL.error("Failed to get steam ID for", userid)
    end

    return CalculateProfileData(steamid, cfd, ...)
end

local function RunSteamProfileFilters(data, filtercb)
    -- Check both because if we have only one set then the query most likely just failed.
    if data.communityprofile == nil and data.profilerep == nil then
        filtercb(true)
        return false -- There is still some data to be catched up
    end

    print("COMMUNITYPROFILE:", tostring(data.communityprofile))
    if data.communityprofile == false then
        filtercb(false, "ID_DST_NO_COMMUNITY_PROFILE")
        return true
    end

    if type(data.profilerep) == "number" and data.profilerep < MIN_PROFILE_REP then
        filtercb(false, "ID_DST_PROFILE_REP_TOO_LOW")
        return true
    end

    filtercb(true)
    return true
end

--------------------------------
-- [[ Setup - Server ]]
--------------------------------

PEARL.ServerNetwork:AddAsyncConnectionFilter(function(userid, cfd, cb)
    local record = PEARL.DB:GetRecordFor(userid)
    if record and RunSteamProfileFilters(record, cb) then
        return -- We already have all the required data to complete the verification.
    end

    CalculateProfileDataForUser(userid, cfd, function(pdata)
        PEARL.EventProcessor:HandleEvent("clientprofiledata", userid, pdata)

        if pdata.profilerep < BAD_PROFILE_REP then
            OnBadProfileRep(userid)
        end

        RunSteamProfileFilters(pdata, cb)
    end)
end)
