--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local MARKDOWN = PEARL.loadfile("libraries/markdown")

--- @type Leaderboard
local Leaderboard = PEARL.loadfile("libraries/database/models/leaderboard")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local MIN_GAINS_FOR_LEADERBOARDING = 25
local MIN_REP_FOR_LEADERBOARDING   = 150

local MIN_ABS_RECORDS = 3
local MIN_CURRENT_RECORDS = 5

local MIN_DAY_LEADER_GAINS = 25

local MAX_MESSAGE_RETRIES = 1

local REP_BUFFER_TIME = 5

--------------------------------------
-- [[ Locals ]]
--------------------------------------

--- @type Leaderboard
local absolute_leaderboard = PEARL.LeaderboardService:GetLeaderboard(Leaderboard.TYPE.ABSOLUTE)
absolute_leaderboard:SetMinPlayers(MIN_ABS_RECORDS)
absolute_leaderboard:SetIndex(1)
absolute_leaderboard:SetCheckFn(function(userid)
    return PEARL.Reputation:GetOf(userid) >= MIN_REP_FOR_LEADERBOARDING
end)

--- @type Leaderboard
local monthly_leaderboard = PEARL.LeaderboardService:GetLeaderboard(Leaderboard.TYPE.MONTHLY)
monthly_leaderboard:SetMinPlayers(MIN_CURRENT_RECORDS)
monthly_leaderboard:SetIndex(2)
monthly_leaderboard:SetCheckFn(function(userid)
    return (PEARL.Reputation:GetFieldOf(userid, "monthgains") or 0) >= MIN_GAINS_FOR_LEADERBOARDING
end)

local leaderboards = PEARL.LeaderboardService:GetAllLeaderboards()

local message_retries = 0

local CreateNewUpdatingMessage

print(leaderboards.monthly:GetIndex())

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function OnMessageNotFound()
    if message_retries >= MAX_MESSAGE_RETRIES then
        return
    end

    PEARL.info("Saved message ID refers to an invalid message, creating a new one...")
    message_retries = message_retries + 1

    CreateNewUpdatingMessage()
end

local function UpdateLeaderboards()
    PEARL.debug("Updating the leaderboard...")

    local self = PEARL.DiscordLeaderBoarder

    PEARL.LeaderboardService:UpdateLeaderboardEmbeds()

    local update_request = self:DoUpdate()
    if not update_request then
        PEARL.error("Failed to update the leaderboard message!")
        return
    end

    if self:CanEditMessages() then
        update_request:SetStatusCodeHandle(
            PEARL.DiscordRestAPI.STATUS_CODES.NOT_FOUND, OnMessageNotFound
        )
    end
end

local function SaveChanges()
    -- Check if any of the leaderboards needs an update or needs to be saved.
    for _, leaderboard in pairs(leaderboards) do
        --table.dump(leaderboard)
        if leaderboard:HasAnyUnsavedChanges() then
            if leaderboard:HasEnoughPlayers() then
                UpdateLeaderboards()
                break
            end

            PEARL.LeaderboardService:Save()
        end
    end
end

local function CompeteDayLeader(rivalid)
    local leaderid = monthly_leaderboard:GetLeaderUserID()
    if leaderid == rivalid then
        return
    end

    local rivalgains = PEARL.Reputation:GetTodayGainsOf(rivalid)
    if not rivalgains or rivalgains < MIN_DAY_LEADER_GAINS then
        return
    end

    local leadergains = PEARL.Reputation:GetTodayGainsOf(leaderid)
    if leadergains < rivalgains then
        monthly_leaderboard:SetDayLeaderUserID(rivalid)
    end
end

local function OnClientBanned(userid)
    local update = false
    for _, leaderboard in pairs(leaderboards) do
        -- Do this for all leaderboards.
        if leaderboard:RemovePlayerByID(userid) ~= nil then
            update = true
        end
    end

    if update then
        UpdateLeaderboards()
    end
end

--- @type table<string, Task>
local buffer = {}
local buffer_task
local function OnBufferDone()
    -- Clear the buffer and handle the changes for the players inside it.
    for userid, old_rep in pairs(buffer) do
        buffer[userid] = nil

        local new_rep = PEARL.Reputation:GetOf(userid)
        if new_rep > old_rep then
            CompeteDayLeader(userid)
        end

        for _, leaderboard in pairs(leaderboards) do
            --table.dump(leaderboard)
            leaderboard:OnReputationChanged(userid)
        end
    end

    SaveChanges()

    buffer_task:cancel()
    buffer_task = nil
end

local function OnReputationChanged(userid, old, new)
    PEARL.debug("OnReputationDelta", userid, new, old)
    if not (old and new) or old == new or not PEARL.LeaderboardService:IsLeaderboardingAllowedFor(userid)  then
        return
    end

    if not buffer[userid] then
        buffer[userid] = old
    end

    if not buffer_task then
        buffer_task = PEARL.WallScheduler:ExecuteInTime(REP_BUFFER_TIME, OnBufferDone)
    end
end

local function AnnounceNewPOTM(userid, month, year)
    local monthname = PEARL.GetMonthFancyName(month)
    local monthfullname = STRINGS.PEARL.FULL_MONTH_NAME:format(monthname, year)

    local name = PEARL.DB:GetField(userid, "username")
    local netid = PEARL.DB:GetField(userid, "netid")
    local discordid = PEARL.DB:GetField(userid, "discordid")

    local mention
    if discordid then
        mention = MARKDOWN.mention(discordid, MARKDOWN.MENTION_TYPE.USER)
    end

    PEARL.DiscordLeaderBoarder:Announce(
    PEARL.EMOTES.DISCORD.TROPHY.." "..STRINGS.PEARL.UI.POTM_ANNOUNCEMENT:format(
        MARKDOWN.bold(monthfullname), mention or (netid and MARKDOWN.hlink(name, PEARL.CONSTS.STEAM_ACCOUNT_URL:format(
            netid
        ))) or MARKDOWN.bold(name)
    ))
end

function PEARL.UpdateLeaderboard()
    UpdateLeaderboards()
end

CreateNewUpdatingMessage = function()
    -- Make sure the newest embeds are assigned.
    PEARL.LeaderboardService:UpdateLeaderboardEmbeds()

    PEARL.DiscordLeaderBoarder:PostUpdatingMessage()
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnNewDay()
    PEARL.debug("OnNewDay")
    monthly_leaderboard:SetDayLeaderUserID(nil)
    SaveChanges()
end

function PEARL.OnNewMonth(stb)
    PEARL.debug("OnNewMonth")

    -- If the monthly leaderboard has enough players (it does display them),
    -- choosing the player of the month is automatically enabled.
    if stb and monthly_leaderboard:HasEnoughPlayers() then
        AnnounceNewPOTM(
            monthly_leaderboard:GetLeaderUserID(), stb.month, stb.year
        )
    end

    if PEARL.DiscordLeaderBoarder:CanEditMessages() then
        -- Since we are creating a new updating message, archive the old one.
        PEARL.LeaderboardService:ArchiveLeaderboard(Leaderboard.TYPE.ABSOLUTE)
    end

    -- Clear all the player data and start again.
    monthly_leaderboard:Reset()
    CreateNewUpdatingMessage()
end

local function OnTimestampUpdated()
    PEARL.debug("OnTimestampUpdated")

    -- If we are in updating mode and no updating message was created yet.
    if PEARL.DiscordLeaderBoarder:CanEditMessages() and not PEARL.DiscordLeaderBoarder:HasUpdatingMessage() then
        return CreateNewUpdatingMessage()
    end

    -- Everything is fine, just update
    return UpdateLeaderboards()
end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddSafeEventHandler("onreputationchanged", OnReputationChanged)
PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)

PEARL.EventProcessor:AddSafeEventHandler("proxy_server_start", SaveChanges)

PEARL.EventProcessor:AddSafeEventHandler("newday", OnNewDay)
PEARL.EventProcessor:AddSafeEventHandler("newmonth", PEARL.OnNewMonth)

PEARL.EventProcessor:AddSafeEventHandler("timeupdatedone", OnTimestampUpdated)
