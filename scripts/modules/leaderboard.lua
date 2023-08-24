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

--------------------------------------
-- [[ Sorters ]]
--------------------------------------

local function CompRepFields(name, uid1, uid2)
    return PEARL.PlayerDB:GetSubField(
        uid1, "reputation", name
    ) > PEARL.PlayerDB:GetSubField(uid2, "reputation", name)
end

local function CompByTotalRep(...)
    return CompRepFields("value", ...)
end

local function CompByMonthRepGains(...)
    return CompRepFields("monthgains", ...)
end

local function IsAllowedInLD(userid, ld_type)

end

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local LEADERBOARD_FILE_PATH = "leaderboard"

local LEADERBOARD_MAX_LEN = PEARL.CONSTS.LEADERBOARD_MAX_LEN

local MIN_REP_FOR_LEADERBOARDING = 200
local MIN_GAINS_FOR_LEADERBOARDING = 25

local MIN_DAY_LEADER_GAINS = 25

local LD_TYPES = {
    ABSOLUTE    = "absolute",
    CURRENT     = "current",
}

local LD_CONFIG = {
    [LD_TYPES.ABSOLUTE] = {
        -- The number of players need for the leaderboard to show.
        min_records = LEADERBOARD_MAX_LEN,
        comp = CompByTotalRep,
        embed_pos = 1,
    },

    [LD_TYPES.CURRENT] = {
        min_records = 3,
        comp = CompByMonthRepGains,
        embed_pos = 2,

        --- @TODO:
        check = function(userid)
            local monthgains = PEARL.Reputation:GetRepFieldOf(userid, "monthgains")
            if monthgains and monthgains >= MIN_GAINS_FOR_LEADERBOARDING then
                return true
            end

            return false
        end
    }
}

local MAX_MESSAGE_RETRIES = 1

--------------------------------------
-- [[ Local Variables ]]
--------------------------------------

--- @type table<string, any>
local _leaderboards

local message_retries = 0

local CreateNewUpdatingMessage

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function GetPosFor(userid, ld_type)
    local leaderboard = _leaderboards[ld_type]
    for i = 1, LEADERBOARD_MAX_LEN, 1 do
        if leaderboard.players[i] == userid then
            return i
        end
    end
end

local function IsLeaderboardingAllowedFor(userid)
    if not PEARL.PlayerDB:IsDataCollectionEnabledFor(userid) then
        return false
    end

    local reputation = PEARL.Reputation:GetOf(userid) or 0
    if reputation < MIN_REP_FOR_LEADERBOARDING then
        return false
    end

    return not PEARL.ServerNetwork:IsClientBanned(userid) and
           not PEARL.ServerNetwork:IsAdmin(userid)
end

local function HasLeaderboardEnoughData(ld_type)
    return #_leaderboards[ld_type].players >= LD_CONFIG[ld_type].min_records
end

local function UpdateLeaderboard(ld_type)
    local current = ld_type == LD_TYPES.CURRENT
    local notenoughdata = not HasLeaderboardEnoughData(ld_type)
    local embed_abs = EMBEDS.Leaderboard(_leaderboards[ld_type], current, notenoughdata)
    return PEARL.DiscordLeaderBoarder:SetEmbed(LD_CONFIG[ld_type].embed_pos, embed_abs)
end

local function AddToLDAt(i, userid, ld_type)
    PEARL.debug("AddToLDAt", i, userid, ld_type, GetPosFor(userid, ld_type))
    if GetPosFor(userid, ld_type) ~= nil then
        return print("ALREADY!") -- Player already in the leaderboard
    end

    _leaderboards[ld_type].players[i] = userid

    -- We are counting the total number of records the leaderboard was built from.
    if type(_leaderboards[ld_type].recordcount) == "number" then
        _leaderboards[ld_type].recordcount = _leaderboards[ld_type].recordcount + 1
    end

    return userid
end

local function RemoveFromLD(i, ld_type)
    PEARL.debug("RemoveFromLD", i, ld_type)
    local userid = table.remove(_leaderboards[ld_type].players, i)
    if userid ~= nil then
        PEARL.info("User", userid, "removed from", ld_type, "leaderboard...")
    end

    return userid
end

local function RemoveFromLDByUserid(userid, ld_type)
    return RemoveFromLD(GetPosFor(userid, ld_type), ld_type)
end

local function RemoveFromAllLDs(userid)
    for _, ld_type in pairs(LD_TYPES) do
        RemoveFromLDByUserid(userid, ld_type)
    end
end

local function ResetLeaderboard(ld_type)
    PEARL.debug("ResetLeaderboard", ld_type)

    for i = #_leaderboards[ld_type].players, 1, -1 do
        RemoveFromLD(i, ld_type)
    end

    if type(_leaderboards[ld_type]) == "number" then
        _leaderboards[ld_type].recordcount = 0
    end
end

local function UpdateLeaderboardEmbeds()
    for _, ld_type in pairs(LD_TYPES) do
        UpdateLeaderboard(ld_type)
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

local function OnSave()
    PEARL.debug("Saving the leaderboard...")

    if type(_leaderboards) ~= "table" then
        return PEARL.error("Leaderboard not loaded!")
    end

    return PEARL.PlayerDB:SaveToDatabaseFile(LEADERBOARD_FILE_PATH, _leaderboards, true, PEARL.CONFIG.LEADERBOARD.ENCODE_DATA)
end

local function OnUpdate()
    PEARL.debug("OnUpdate")

    OnSave()

    local self = PEARL.DiscordLeaderBoarder

    UpdateLeaderboardEmbeds()

    local update_request = self:DoUpdate()
    if not update_request then
        PEARL.error("Failed to update the leaderboard message!")
        return
    end

    update_request:SetStatusCodeHandle(PEARL.DiscordRestAPI.STATUS_CODES.NOT_FOUND, OnMessageNotFound)
end

local function HandleLDRepChanged(userid, ld_type)
    local leaders = _leaderboards[ld_type].players
    local init_pos = GetPosFor(userid, ld_type)

    local comp = LD_CONFIG[ld_type].comp or CompByTotalRep
    local last_index = math.min(#leaders + 1, LEADERBOARD_MAX_LEN)
    local last_userid = leaders[last_index]
    if not init_pos and (not last_userid or comp(userid, last_userid)) then
        AddToLDAt(last_index, userid, ld_type)
    end

    table.sort(leaders, comp)

    -- If our position in the leaderboard has changed, make it visible.
    return GetPosFor(userid, ld_type) ~= init_pos
end

local function CompeteDayLeader(rivalid)
    local leaderboard = _leaderboards[LD_TYPES.CURRENT]
    if leaderboard.dayleader == rivalid then
        return false
    end

    local rivalgains = PEARL.Reputation:GetTodayGainsOf(rivalid)
    if not rivalgains or rivalgains < MIN_DAY_LEADER_GAINS then
        return false
    end

    local leadergains = PEARL.Reputation:GetTodayGainsOf(leaderboard.dayleader)
    if not leaderboard.dayleader or leadergains < rivalgains then
        leaderboard.dayleader = rivalid

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

    for _, ld_type in pairs(LD_TYPES) do
        if HandleLDRepChanged(userid, ld_type) then
            if HasLeaderboardEnoughData(ld_type) then
                update = true
            else
                save = true
            end
        end
    end

    if update then
        OnUpdate()
    elseif save then
        OnSave()
    end
end

local function OnClientBanned(userid)
    local update = false
    for _, ld_type in pairs(LD_TYPES) do
        if RemoveFromLDByUserid(userid, ld_type) ~= nil then
            update = true
        end
    end

    if update then
        OnUpdate()
    end
end

local function OnReputationDelta(userid, delta)
    -- Admins should not appear in the leadeboard
    if not delta or delta == 0 then
        return
    end

    if not IsLeaderboardingAllowedFor(userid) then
        return RemoveFromAllLDs(userid)
    end

    OnReputationChangedFor(userid, delta)
end

local function OnLoad()
    PEARL.info("Loading the leaderboard...")

    if type(_leaderboards) == "table" then
        return PEARL.error("Leadeboard already loaded!")
    end

    _leaderboards = PEARL.PlayerDB:LoadDatabaseFile(LEADERBOARD_FILE_PATH, true) or {}
    if type(_leaderboards) ~= "table" then
        _leaderboards = {}
    end

    for _, ld_type in pairs(LD_TYPES) do
        if type(_leaderboards[ld_type]) ~= "table" then
            _leaderboards[ld_type] = {
                players = {},
                timecreated = os.time()
            }
        end

        if type(_leaderboards[ld_type].players) ~= "table" then
            _leaderboards[ld_type].players = {}
        end

        if ld_type == LD_TYPES.CURRENT and not _leaderboards[ld_type].recordcount then
            _leaderboards[ld_type].recordcount = 0
        end

        -- Re-check if all players loaded are allowed to be leaderboarded.
        for i = #_leaderboards[ld_type].players, 1, -1 do
            if not IsLeaderboardingAllowedFor(_leaderboards[ld_type].players[i]) then
                RemoveFromLD(i, ld_type)
            end
        end
    end
end

local function OnNewDay()
    -- Just clear the leader here.
    -- Day gains should be cleared by the DB.
    local leaderboard = _leaderboards[LD_TYPES.CURRENT]
    if leaderboard.dayleader ~= nil then
        leaderboard.dayleader = nil
        OnUpdate()
    end
end

local function SaveMessageID(message_id)
    PEARL.DiscordLeaderBoarder:SetUpdateMessageID(message_id)

    _leaderboards.message_id = message_id
    OnSave()
end

CreateNewUpdatingMessage = function()
    PEARL.debug("CreateNewUpdatingMessage")
    local self = PEARL.DiscordLeaderBoarder

    self:PostUpdatingMessage(function(message)

        if type(message.id) ~= "string" then
            return PEARL.error("Failed to post the initial updating message!")
        end

        -- Save the message id here as an internal configuration.
        -- Since this should be managed completely by the mod.
        SaveMessageID(message.id)
        PEARL.DiscordLeaderBoarder:SetUpdateMessageID(message.id)
    end)
end

function PEARL.OnNewMonth(stb)
    PEARL.debug("OnUpdate")

    local leaderboard = _leaderboards[LD_TYPES.CURRENT]

    local self = PEARL.DiscordLeaderBoarder

    if stb and HasLeaderboardEnoughData(LD_TYPES.CURRENT) then
        local name = PEARL.PlayerDB:GetField(leaderboard.players[1], "username")
        local monthname = PEARL.GetMonthFancyName(stb.month)
        local monthfullname = STRINGS.PEARL.FULL_MONTH_NAME:format(monthname, stb.year)

        self:Announce("Best player of the month "..monthfullname.." is "..name.."! New month begins!")
    end

    if _leaderboards.message_id then
        PEARL.debug("ARCHIVING...")
        UpdateLeaderboardEmbeds()

        local config = LD_CONFIG[LD_TYPES.ABSOLUTE]
        -- Remove the absolute leaderboard embed from it so we can archive it.
        self:SetEmbed(config.embed_pos, EMBEDS.LeaderboardArchived())

        -- Do not force in case some other update request is queued.
        -- We have to copy the embeds for the request to use.
        self:DoUpdate()
    end

    ResetLeaderboard(LD_TYPES.CURRENT)
    UpdateLeaderboardEmbeds()
    CreateNewUpdatingMessage()
end

function PEARL.DisplayLeaderboard()
    table.dump(_leaderboards)
end

function PEARL.UpdateLeaderboard()
    OnUpdate()
end

--------------------------------
-- [[ Post Inits ]]
--------------------------------

local function OnTimestampUpdated(changes)
    if changes then
        return
    end

    if type(_leaderboards.message_id) ~= "string" then
        return CreateNewUpdatingMessage()
    end

    -- Everything is fine, just update
    return OnUpdate()
end

PEARL.AddGamePostInit(function()
    local self = PEARL.DiscordLeaderBoarder

    OnLoad()
    self:SetUpdateMessageID(_leaderboards.message_id)
end)

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddEventHandler("onreputationdelta", OnReputationDelta)
PEARL.EventProcessor:AddEventHandler("clientbanned", OnClientBanned)

PEARL.EventProcessor:AddSafeEventHandler("newday", OnNewDay)
PEARL.EventProcessor:AddSafeEventHandler("newmonth", PEARL.OnNewMonth)

PEARL.EventProcessor:AddSafeEventHandler("timeupdatedone", OnTimestampUpdated)
