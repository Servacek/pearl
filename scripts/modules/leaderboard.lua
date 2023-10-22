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

local MIN_DAY_LEADER_GAINS = 25

local MAX_MESSAGE_RETRIES = 1

--------------------------------------
-- [[ Locals ]]
--------------------------------------

--- @type PersistentMap
local leaderboard_map = PersistentMap(LEADERBOARD_FILE_PATH)
leaderboard_map:SetOnLoad(function(leaderboard_data)
    local data = {}
    for name, value in pairs(leaderboard_data) do
        if table.contains(Leaderboard.TYPE, name) then
            data[name] = Leaderboard(value)
        else
            data[name] = value
        end
    end

    return data
end)
leaderboard_map:SetOnSave(function(leaderboards)
    local data = {}
    for name, value in pairs(leaderboards) do
        if Leaderboard.is_instance(value) then
            data[name] = value:GetData()
        else
            data[name] = value
        end
    end

    return data
end)

leaderboard_map:Load()
--- @type table<string, any>
local lbs_data = leaderboard_map:GetData()

-- If nothing was able to load create new data.
if not lbs_data or table.empty(lbs_data) then
    for _, ld_type in pairs(Leaderboard.TYPE) do
        local leaderboard = Leaderboard()
        leaderboard:SetType(ld_type)
        leaderboard_map:SetValue(ld_type, leaderboard)
    end

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

--- @type Leaderboard
local absolute_leaderboard = lbs_data[Leaderboard.TYPE.ABSOLUTE]
--- @type Leaderboard
local monthly_leaderboard  = lbs_data[Leaderboard.TYPE.MONTHLY]

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

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function UpdatingMessageExists()
    return lbs_data and type(lbs_data.messageid) == "string"
end

local function CanEditMessages()
    return PEARL.DiscordLeaderBoarder:GetMode() == PEARL.DiscordLeaderBoarder.MODE.UPDATE
end

local function RemoveFromAllLeaderboards(userid)
    for _, leaderboard in pairs(leaderboards) do
        leaderboard:RemovePlayerByID(userid)
    end
end

local function UpdateLeaderboardEmbeds()
    for _, leaderboard in pairs(leaderboards) do
        PEARL.DiscordLeaderBoarder:SetEmbed(leaderboard:GetEmbedPosition(), leaderboard:GetEmbed())
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

    lbs_data.last_update = os.time()
    lbs_data.changes = false

    SaveLeaderboards()

    if self:GetMode() == self.MODE.UPDATE then
        update_request:SetStatusCodeHandle(PEARL.DiscordRestAPI.STATUS_CODES.NOT_FOUND, OnMessageNotFound)
    end
end

local function CompeteDayLeader(rivalid)
    if monthly_leaderboard.dayleader == rivalid then
        return false
    end

    local rivalgains = PEARL.Reputation:GetTodayGainsOf(rivalid)
    if not rivalgains or rivalgains < MIN_DAY_LEADER_GAINS then
        return false
    end

    local leadergains = PEARL.Reputation:GetTodayGainsOf(monthly_leaderboard.dayleader)
    if not monthly_leaderboard.dayleader or leadergains < rivalgains then
        monthly_leaderboard.dayleader = rivalid

        return true
    end
end

local function OnReputationChangedFor(userid, delta)
    PEARL.debug("OnReputationChangedFor")

    local update, save = false, false

    if delta > 0 then
        if CompeteDayLeader(userid) then
            -- The day leader was changed, update the leadeboard.
            update = true
        end
    end

    for _, leaderboard in pairs(leaderboards) do
        if leaderboard:OnReputationChanged(userid) then
            if leaderboard:HasEnoughData() then
                update = true
            else
                save = true
            end
        end
    end

    if update then
        UpdateLeaderboards()
    elseif save then
        SaveLeaderboards()
    end
end

local function OnClientBanned(userid)
    local update = false
    for _, lt in pairs(Leaderboard.TYPE) do
        if lbs_data[lt]:RemovePlayerByID(userid) ~= nil then
            update = true
        end
    end

    if update then
        UpdateLeaderboards()
    end
end

local function OnReputationDelta(userid, delta)
    if not delta or delta == 0 then
        return
    end

    -- Admins should not appear on the leadeboard
    if not Leaderboard.CanAddPlayer(userid) then
        return RemoveFromAllLeaderboards(userid)
    end

    OnReputationChangedFor(userid, delta)
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

    if stb and monthly_leaderboard:HasEnoughData() then
        local monthleaderid = monthly_leaderboard:GetLeaderUserID()
        local name = PEARL.PlayerDB:GetField(monthleaderid, "username")
        local monthname = PEARL.GetMonthFancyName(stb.month)
        local monthfullname = STRINGS.PEARL.FULL_MONTH_NAME:format(monthname, stb.year)

        --- @TODO:
        PEARL.DiscordLeaderBoarder:Announce("Best player of the month "..monthfullname.." is "..name.."! New month begins!")
    end

    -- Since we are creating a new updating message, archive the old one.
    if CanEditMessages() and UpdatingMessageExists() then
        local config = absolute_leaderboard:GetConfig()
        ArchiveLeaderboardEmbed(config.embed_pos)
    end

    monthly_leaderboard:ResetData()
    UpdateLeaderboardEmbeds()
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

PEARL.EventProcessor:AddEventHandler("onreputationdelta", OnReputationDelta)
PEARL.EventProcessor:AddEventHandler("clientbanned", OnClientBanned)

PEARL.EventProcessor:AddSafeEventHandler("newday", OnNewDay)
PEARL.EventProcessor:AddSafeEventHandler("newmonth", PEARL.OnNewMonth)

PEARL.EventProcessor:AddSafeEventHandler("timeupdatedone", OnTimestampUpdated)
