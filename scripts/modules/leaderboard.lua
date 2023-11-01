--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local EMBEDS = PEARL.loadfile("utils/embeds")

--- @type PersistentMap
local PersistentMap = PEARL.loadfile("models/persistentmap")

--- @type Leaderboard
local Leaderboard = PEARL.loadfile("models/leaderboard")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local LEADERBOARD_FILE_PATH = "leaderboards"

local MIN_GAINS_FOR_LEADERBOARDING = 25

local MIN_ABS_RECORDS = 3
local MIN_CURRENT_RECORDS = 5

local MIN_DAY_LEADER_GAINS = 25

local MAX_MESSAGE_RETRIES = 1

local REP_BUFFER_TIME = 5

--------------------------------------
-- [[ Sorters ]]
--------------------------------------

local function CompRepFields(name, uid1, uid2)
    return PEARL.Reputation:GetRepFieldOf(uid1, name) > PEARL.Reputation:GetRepFieldOf(uid2, name)
end

local function CompByTotalRep(...)
    return CompRepFields("value", ...)
end

local function CompByMonthRepGains(...)
    return CompRepFields("monthgains", ...)
end

--------------------------------------
-- [[ Locals ]]
--------------------------------------

--- @type PersistentMap
local leaderboard_map = PersistentMap(LEADERBOARD_FILE_PATH)
leaderboard_map:SetOnLoad(function(leaderboard_data)
    local data = {}
    for name, value in pairs(leaderboard_data) do
        data[name] = table.contains(Leaderboard.TYPE, name) and Leaderboard(value) or value
    end

    return data
end)
leaderboard_map:SetOnSave(function(leaderboards)
    local data = {}
    for name, value in pairs(leaderboards) do
        data[name] = Leaderboard.is_instance(value) and value:OnSave() or value
    end

    return data
end)

leaderboard_map:Load()
--- @type table<string, any>
local lbs_data = leaderboard_map:GetData()

--- @type Leaderboard
local absolute_leaderboard = lbs_data[Leaderboard.TYPE.ABSOLUTE] or Leaderboard()
absolute_leaderboard:SetType(Leaderboard.TYPE.ABSOLUTE)
absolute_leaderboard:SetSortFn(CompByTotalRep)
--absolute_leaderboard:SetMinRecords(MIN_ABS_RECORDS)
absolute_leaderboard:SetIndex(1)
lbs_data[Leaderboard.TYPE.ABSOLUTE] = absolute_leaderboard

--- @type Leaderboard
local monthly_leaderboard  = lbs_data[Leaderboard.TYPE.MONTHLY] or Leaderboard()
monthly_leaderboard:SetType(Leaderboard.TYPE.MONTHLY)
monthly_leaderboard:SetSortFn(CompByMonthRepGains)
monthly_leaderboard:SetCheckFn(function(userid)
    local monthgains = PEARL.Reputation:GetRepFieldOf(userid, "monthgains")
    if monthgains and monthgains >= MIN_GAINS_FOR_LEADERBOARDING then
        return true
    end

    return false
end)
--monthly_leaderboard:SetMinRecords(MIN_CURRENT_RECORDS)
monthly_leaderboard:SetIndex(2)
lbs_data[Leaderboard.TYPE.MONTHLY] = monthly_leaderboard

if absolute_leaderboard.loaded or monthly_leaderboard.loaded then
    leaderboard_map:SetValue(absolute_leaderboard.type, absolute_leaderboard)
    leaderboard_map:SetValue(monthly_leaderboard.type, monthly_leaderboard)
    leaderboard_map:Save()
end

PEARL.DiscordLeaderBoarder:SetUpdateMessageID(lbs_data.messageid)

--- @type table<string, Leaderboard>
local leaderboards = {}
for _, lt in pairs(Leaderboard.TYPE) do
    local leaderboard = lbs_data[lt]
    if not Leaderboard.is_instance(leaderboard) then
        return error("Failed to load "..lt.." leaderboard!")
    end

    leaderboards[lt] = leaderboard
end

local message_retries = 0

local CreateNewUpdatingMessage, OnUpdatingMessagePosted

--------------------------------------
-- [[ Helpers ]]
--------------------------------------

local function SaveLeaderboards()
    PEARL.debug("Saving the leaderboards...")
    leaderboard_map:Save()
end

local function SaveMessageID(messageid)
    PEARL.debug("SaveMessageID", messageid)
    PEARL.DiscordLeaderBoarder:SetUpdateMessageID(messageid)

    lbs_data.messageid = messageid
    SaveLeaderboards()
end

local function IsLeaderboardingEnabledFor(userid)
    return PEARL.DB:IsRecordLoadedFor(userid) and
            not PEARL.ServerNetwork:IsClientBanned(userid) and
           (not PEARL.ServerNetwork:IsAdmin(userid) or PEARL.CONFIG.DEBUG_MODE)
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function UpdatingMessageExists()
    return lbs_data and type(lbs_data.messageid) == "string"
end

local function CanEditMessages()
    return PEARL.DiscordLeaderBoarder:GetMode() == PEARL.DiscordLeaderBoarder.MODE.UPDATE
end

local function UpdateLeaderboardEmbeds()
    for _, leaderboard in pairs(leaderboards) do
        PEARL.DiscordLeaderBoarder:SetEmbed(leaderboard:GetIndex(), leaderboard:GetEmbed())
    end
end

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

    UpdateLeaderboardEmbeds()

    local update_request = self:DoUpdate()
    if not update_request then
        PEARL.error("Failed to update the leaderboard message!")
        return
    end

    SaveLeaderboards()

    if self:GetMode() == self.MODE.UPDATE then
        update_request:SetStatusCodeHandle(PEARL.DiscordRestAPI.STATUS_CODES.NOT_FOUND, OnMessageNotFound)
    end
end

local function UpToDateCheck()
    -- Check if any of the leaderboards needs an update or needs to be saved.
    for _, leaderboard in pairs(leaderboards) do
        if leaderboard:HasAnyUnsavedChanges() then
            if leaderboard:HasEnoughPlayers() then
                UpdateLeaderboards()
                break
            end

            SaveLeaderboards()
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
            leaderboard:OnReputationChanged(userid)
        end
    end

    UpToDateCheck()

    buffer_task:cancel()
    buffer_task = nil
end

local function OnReputationChanged(userid, old, new)
    PEARL.debug("OnReputationDelta", userid, new, old)
    if not (old and new) or old == new or not IsLeaderboardingEnabledFor(userid)  then
        return
    end

    if not buffer[userid] then
        buffer[userid] = old
    end

    if not buffer_task then
        buffer_task = PEARL.WallScheduler:ExecuteInTime(REP_BUFFER_TIME, OnBufferDone)
    end
end

function PEARL.DisplayLeaderboard()
    table.dump(lbs_data)
end

function PEARL.UpdateLeaderboard()
    UpdateLeaderboards()
end

local function ArchiveLeaderboardEmbed(position)
    PEARL.debug("MarkLeaderboardArchived")
    UpdateLeaderboardEmbeds()

    -- Remove the absolute leaderboard embed from it so we can archive it.
    PEARL.DiscordLeaderBoarder:SetEmbed(position, EMBEDS.LeaderboardArchived())
    PEARL.DiscordLeaderBoarder:DoUpdate()
end

CreateNewUpdatingMessage = function()
    -- Make sure the newest embeds are assigned.
    UpdateLeaderboardEmbeds()

    PEARL.debug("CreateNewUpdatingMessage")
    return PEARL.DiscordLeaderBoarder:PostUpdatingMessage(CanEditMessages() and OnUpdatingMessagePosted or nil)
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnNewDay()
    PEARL.debug("OnNewDay")
    -- Just clear the leader here.
    -- Day gains should be cleared by the DB.
    if monthly_leaderboard.dayleader ~= nil then
        monthly_leaderboard.dayleader = nil
        UpdateLeaderboards()
    end
end

OnUpdatingMessagePosted = function(message)
    PEARL.debug("OnUpdatingMessagePosted", message)

    if type(message) ~= "table" or type(message.id) ~= "string" then
        return PEARL.error("Failed to post the initial updating message!")
    end

    -- Save the message id here as an internal configuration.
    -- Since this should be managed completely by the mod.
    SaveMessageID(message.id)
end

function PEARL.OnNewMonth(stb)
    PEARL.debug("OnNewMonth")

    -- If the monthly leaderboard has enough players (it does display them),
    -- choosing the player of the month is automatically enabled.
    if stb and monthly_leaderboard:HasEnoughPlayers() then
        local monthleaderid = monthly_leaderboard:GetLeaderUserID()
        local name = PEARL.DB:GetField(monthleaderid, "username")
        local monthname = PEARL.GetMonthFancyName(stb.month)
        local monthfullname = STRINGS.PEARL.FULL_MONTH_NAME:format(monthname, stb.year)

        --- @TODO:
        PEARL.DiscordLeaderBoarder:Announce("Best player of the month "..monthfullname.." is "..name.."! New month begins!")
    end

    -- Since we are creating a new updating message, archive the old one.
    if CanEditMessages() and UpdatingMessageExists() then
        ArchiveLeaderboardEmbed(absolute_leaderboard:GetIndex())
    end

    -- Clear all the player data and start again.
    monthly_leaderboard:Reset()
    CreateNewUpdatingMessage()
end

local function OnTimestampUpdated(changes)
    if changes then
        return
    end

    PEARL.debug("OnTimestampUpdated")

    -- If we are in updating mode and no updating message was created yet.
    if CanEditMessages() and not UpdatingMessageExists() then
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

PEARL.EventProcessor:AddSafeEventHandler("proxy_server_start", UpToDateCheck)

PEARL.EventProcessor:AddSafeEventHandler("newday", OnNewDay)
PEARL.EventProcessor:AddSafeEventHandler("newmonth", PEARL.OnNewMonth)

PEARL.EventProcessor:AddSafeEventHandler("timeupdatedone", OnTimestampUpdated)
