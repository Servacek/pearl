--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @TODO: Make the profile reputation affect the starting reputation for a player.
--- So that players with bad profiles are closer to a ban in case they start to be nasty.


local MARKDOWN = PEARL.loadfile("libraries/markdown")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local QUERIES = PEARL.SteamAPI.QUERIES

local MAX_PROFILE_REP = 100

local MAX_COMMENT_REP = 50
local MIN_COMMENT_REP = 0

local MIN_REP_PROFILE_AGE = 3 -- Players start to get reputation for older accounts

local REP_PER_TOXIC_NAME        = -10
local REP_PER_BANNED_FRIEND     = -25
local REP_PER_POSITIVE_COMMENT  = 10
local REP_PER_NEGATIVE_COMMENT  = -10
local REP_PER_UNMATCHED_LOCALE = -10

local REP_PER_ACCOUNT_YEAR  = 5

local REP_PER_BANNED_CLAN   = -50
local REP_PER_VAC_BAN       = -25
local REP_PER_GAME_BAN      = -40
local REP_PER_COMMUNITY_BAN = -15
local REP_PER_ECONOMY_BAN   = -10

local MAX_COMMENTS_CHECK_COUNT = 25

local COMMENT_PATTERN = "<bdi>(.-)<\\/bdi>.-<div class=\\\"commentthread_comment_text\\\" id=\\\"comment_content_%d+\\\">(.-)<\\/div>"

local POSITIVE_COMMENT_PATTERNS = {
    "+rep",
}
local NEGATIVE_COMMENT_PATTERNS = {
    "-rep", "griefer", "hacker", "troll",
}

-- Keep these in sync with the names in the DB.
local PROFILE_DATA = {
    profilerep          = MAX_PROFILE_REP,
    -- Let's make it fail safe.
    communityprofile    = true,
    privateprofile      = false, -- Profiles are public by default.

    --- optional
    gameplaytime        = nil,
    profilecountrycode  = nil,
    profiletimecreated  = nil,
    avatar              = nil,
}

local COMMENT_TYPE = {
    NEUTRAL     = nil,
    POSITIVE    = true,
    NEGATIVE    = false,
}

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

local function OnBannedFriendsDetected(username, steamid, banned, total)
    PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.STEAM_BANNED_FRIENDS:format(
        MARKDOWN.hlink(username, MARKDOWN.escape_link_embeds(
            PEARL.CONSTS.STEAM_ACCOUNT_URL:format(steamid)
        )), banned, total
    ))
end

local function OnCountryInfoMismatch(username, steamid, profile, assumed)
    PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.STEAM_LOCALE_MISMATCH:format(
        assumed, profile, MARKDOWN.hlink(username, MARKDOWN.escape_link_embeds(
            PEARL.CONSTS.STEAM_ACCOUNT_URL:format(steamid)
        ))
    ))
end

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

--- @param comment string
local function GetCommentType(comment)
    if ProfanityFilter:Detect(comment) then
        return COMMENT_TYPE.NEGATIVE
    end

    local negativity = 0
    for pt in ipairs(NEGATIVE_COMMENT_PATTERNS) do
        if comment:find(pt) then
            negativity = negativity + 1
        end
    end

    local positivity = 0
    for pt in ipairs(POSITIVE_COMMENT_PATTERNS) do
        if comment:find(pt) then
            positivity = positivity + 1
        end
    end

    if positivity == 0 and negativity == 0 then
        return COMMENT_TYPE.NEUTRAL
    end

    return positivity > negativity
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

            local cmt_type = GetCommentType(comment:lower())
            if cmt_type == COMMENT_TYPE.NEGATIVE then
                neg_count = neg_count + 1
            elseif cmt_type == COMMENT_TYPE.POSITIVE then
                pos_count = pos_count + 1
            else -- For Neutral Comments
                ignore[author] = false
            end
        end
    end

    return math.min(
        (pos_count * REP_PER_POSITIVE_COMMENT) + (neg_count * REP_PER_NEGATIVE_COMMENT), MAX_COMMENT_REP
    )
end

local function HasAllRequiredProfileData(record)
    -- Traverse the required profile data and check if they are not absent.
    for key, _ in pairs(PROFILE_DATA) do
        -- Even if the types do not match we have to recollect the data.
        if type(record[key]) ~= type(PROFILE_DATA[key]) then
            return false
        end
    end

    return true
end

local function CalculateProfileData(profile_userid, cb)
    local record = PEARL.DB:GetRecordFor(profile_userid)
    if not record then
        return PEARL.error("Calculating profile data failed! No record exists for", profile_userid)
    end

    local steamid = profile_userid and TheNet:GetNetIdForUser(profile_userid)
    if not steamid then
        return PEARL.error("Failed to get steam ID for", profile_userid)
    end

    local data = shallowcopy(PROFILE_DATA)

    -- VAC - Valve Anti-Cheat
    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_BANS, function(query)
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
        local toxicity_count = ProfanityFilter:CountSwears(str)
        if toxicity_count > 0 then
            data.profilerep = data.profilerep + (toxicity_count * REP_PER_TOXIC_NAME)
        end
    end)

    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_FRIENDLIST, function(query)
        if not (query.friendslist and query.friendslist.friends) then
            return -- no friends or profile is private
        end

        -- Count banned friends.
        local banned_count = 0
        local friends = query.friendslist.friends
        for _, friend in pairs(friends) do
            -- Attempt to conver the Steam ID to Klei ID since its used more frequently for banning.
            local userid = PEARL.AccountBindings:MapSteamID(friend.steamid) or friend.steamid
            if PEARL.BlackList:Contains(userid) then
                banned_count = banned_count + 1
            end
        end

        if banned_count > 0 then
            PEARL.info("Banned friends detected for user!")
            OnBannedFriendsDetected(
                record.username, steamid, banned_count, table.size(friends)
            )

            data.profilerep = data.profilerep + (banned_count * REP_PER_BANNED_FRIEND)
        end
    end)

    PEARL.SteamAPI:AddRawQueryToSequence(steamid, QUERIES.P_COMMENTS, function(str)
        if type(str) ~= "string" then
            return
        end

        local comment_rep = CalculateRepInComments(str, record.username)
        if comment_rep < MIN_COMMENT_REP then
            data.profilerep = -MAX_COMMENT_REP
        else
            data.profilerep = data.profilerep + comment_rep
        end
    end, MAX_COMMENTS_CHECK_COUNT)

    PEARL.SteamAPI:AddQueryToSequence(steamid, QUERIES.P_SUMMARIES, function(query)
        local player = query and query.response and query.response.players and query.response.players[1]
        if not player then
            PEARL.error("Invalid query response received!")
            return
        end

        data.profilecountrycode = player.loccountrycode
        data.profiletimecreated = player.timecreated

        -- If the locale on profile doesn't match the locale
        -- set on the steam profile (only if set).
        if (
            type(player.loccountrycode) == "string" and
            type(record.lastlocale) == "string" and
            player.loccountrycode:lower() ~= record.lastlocale:lower()
        ) then
            OnCountryInfoMismatch(
                player.personaname or record.username or "UNKNOWN", steamid,
                player.loccountrycode, record.lastlocale
            )

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

        if tostring(player.profilestate) ~= PEARL.SteamAPI.PROFILE_CONFIGURED then
            data.communityprofile = false
        end

        if tostring(player.communityvisibilitystate) ~= PEARL.SteamAPI.PROFILE_VISIBILITY.PUBLIC then
            data.privateprofile = true
        end

        data.avatar = player.avatarfull or player.avatarmedium or player.avatar
    end)

    local function RecordGamePlayTime(querydata)
        local games = type(querydata.response) == "table" and querydata.response.games
        local playtime = type(games) == "table" and #games > 0 and games[1].playtime_forever
        if type(playtime) == "number" and playtime > 0 then
            data.gameplaytime = (querydata.gameplaytime or 0) + playtime
        end
    end

    PEARL.SteamAPI:AddQueryToSequence(
        steamid, QUERIES.P_PLAYTIME, RecordGamePlayTime, DONT_STARVE_TOGETHER_APPID
    )
    PEARL.SteamAPI:AddQueryToSequence(
        steamid, QUERIES.P_PLAYTIME, RecordGamePlayTime, DONT_STARVE_APPID
    )

    PEARL.SteamAPI:ExecuteDataQuerySequenceFor(steamid, function()
        if type(cb) == "function" then
            cb(data)
        end
    end)
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnDatabaseRecordLoaded(userid, record)
    if not HasAllRequiredProfileData(record) then
        PEARL.info("Player has not all the required profile data! Fetching...")
        CalculateProfileData(userid, function(resultdata)
            PEARL.info("Player profile data fetched!")

            PEARL.EventProcessor:HandleEvent("clientprofiledata", userid, resultdata)
        end)
    end
end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddSafeEventHandler("db_recordloaded", OnDatabaseRecordLoaded)
PEARL.EventProcessor:AddSafeEventHandler("db_recordcreated", OnDatabaseRecordLoaded)
