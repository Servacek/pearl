--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO: Check for bans on some public banlists.

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

local function CalculateProfileReputation(steamid, cfd, cb)
    local rep = MAX_PROFILE_REP

    PEARL.SteamAPI:CreateDataQuerySequenceFor(steamid, function()
        if type(cb) == "function" then
            cb(rep)
        end
    end)

    -- VAC - Valve Anti-Cheat
    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_BANS, function(data)
        -- Handle Player Ban Data
        print("P_BANS:", rep)
        if not data or not data.players or not data.players[1] then
            return
        end

        local player = data.players[1]
        if player.CommunityBanned then
            rep = rep + REP_PER_COMMUNITY_BAN
        end

        if type(player.EconomyBan) == "string" and player.EconomyBan ~= "none" then
            rep = rep + REP_PER_ECONOMY_BAN
        end

        if type(player.NumberOfVACBans) == "number" and player.NumberOfVACBans > 0 then
            rep = rep + (player.NumberOfVACBans * REP_PER_VAC_BAN)
        end

        if type(player.NumberOfGameBans) == "number" and player.NumberOfGameBans > 0 then
            rep = rep + (player.NumberOfGameBans * REP_PER_GAME_BAN)
        end
    end)

    -- This will also check the currently used name.
    PEARL.SteamAPI:AddRawQueryToSequence(steamid, QUERIES.P_NAMEHISTORY, function(str)
        print("P_NAMEHISTORY:", str, rep)

        local toxicity_count = ProfanityFilter:CountInappropriateWords(str)
        if toxicity_count > 0 then
            OnToxicNameDetected(steamid)

            rep = rep + (toxicity_count * REP_PER_TOXIC_NAME)
        end
    end)

    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_FRIENDLIST, function(data)
        print("P_FRIENDLIST:", rep)
        local banned_count = 0
        for _, friend in pairs(data.friendslist.friends) do
            if PEARL.BlackList:Contains(friend.steamid) then
                banned_count = banned_count + 1
            end
        end

        if banned_count > 0 then
            OnBannedFriendsDetected(steamid, banned_count)

            rep = rep + (banned_count * REP_PER_BANNED_FRIEND)
        end

        PEARL.info("User's friends are fine")
    end)

    PEARL.SteamAPI:AddRawQueryToSequence(steamid, QUERIES.P_COMMENTS, function(str)
        print("P_COMMENTS", rep)

        if type(str) ~= "string" then
            return
        end

        local comment_rep = CalculateRepInComments(str, cfd.username)
        if comment_rep < MIN_COMMENT_REP then
            rep = -MAX_COMMENT_REP
        else
            rep = rep + comment_rep
        end
    end, MAX_COMMENTS_CHECK_COUNT)

    --- @TODO: Maybe we should save timecreated and countrycode.
    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_SUMMARIES, function(data)
        local player = data and data.response and data.response.players and data.response.players[1]
        if not player then
            return
        end

        -- If the locale on profile doesn't match the locale
        -- set on the steam profile (only if set).
        if (
            type(player.loccountrycode) == "string" and
            type(cfd.locale) == "string" and
            player.loccountrycode ~= cfd.locale
        ) then
            rep = rep + REP_PER_UNMATCHED_LOCALE
        end

        --- Maybe we should check all the clans here?
        local primaryclanid = tostring(player.primaryclanid)
        if PEARL.CONFIG.STEAM_GROUP_BLOCKLIST[primaryclanid] == true or
            table.contains(PEARL.CONFIG.STEAM_GROUP_BLOCKLIST, primaryclanid)
        then
            rep = rep + REP_PER_BANNED_CLAN
        end

        if player.timecreated then
            local acc_years = os.timediffyears(tonumber(player.timecreated))

            -- Usually older accounts mean older audience which means
            -- less probability for griefing.
            if acc_years >= MIN_REP_PROFILE_AGE then
                rep = rep + (acc_years * REP_PER_ACCOUNT_YEAR)
            end
        end
    end)

    PEARL.SteamAPI:ExecuteDataQuerySequenceFor(steamid)
end

local function CalculateProfileReputationForUser(userid, cfd, ...)
    local steamid = userid and TheNet:GetNetIdForUser(userid) -- "76561198050735090"
    if not steamid then
        return PEARL.error("Failed to get steam ID for", userid)
    end

    return CalculateProfileReputation(steamid, cfd, ...)
end

local function FilterByReputation(userid, rep, filtercb)
    if rep < MIN_PROFILE_REP then
        PEARL.info("VERY BAD PROFILE REP!!")
        return filtercb(false, "ID_DST_PROFILE_REP_TOO_LOW")
    end

    filtercb(true)
end

--------------------------------
-- [[ Setup - Server ]]
--------------------------------

PEARL.ServerNetwork:AddAsyncConnectionFilter(function(userid, data, cb)
    local rep = PEARL.PlayerDB:GetField(userid, "profilerep")
    if type(rep) == "number" then
        return FilterByReputation(userid, rep, cb)
    end

    CalculateProfileReputationForUser(userid, data, function(_rep)
        PEARL.PlayerDB:OptionalSafeSetField(userid, "profilerep", _rep)

        if _rep < BAD_PROFILE_REP then
            OnBadProfileRep(userid)
        end

        FilterByReputation(userid, _rep, cb)
    end)
end)
