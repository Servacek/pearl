--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category BackEnd


--[[
    Module for keeping the server up-to-date. Uses Klei's API to get the latest
    release version. When the version is higher than the current one,
    it notifies the players and shutdowns all the shards. So there needs to be
    a third party program which then effectively updates and starts the server again.

    It looks like there is some Steam API for this but it seems to be still stuck in the
    last early access version of the game :/
--]]


local PEARL = PEARL
local APP_VERSION, json = APP_VERSION, json
local TheNet = TheNet
local tonumber, pcall = tonumber, pcall

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local VERSION_QUERY_TIMEOUT = 10
local TARGET_VERSION_PATTERN = ",\"(%d+)\"%],\"staging\":%[\"%d+\","

local INITIAL_DELAY = 10

-------------------------------------
-- [[ Variables ]]
-------------------------------------

local task
local current_version = tonumber(APP_VERSION) or 0
local target_version = 0

-------------------------------------
-- [[ Helpers ]]
-------------------------------------

local function get_target_version_from_string(query_result_str)
    if type(query_result_str) ~= "string" then
        return
    end

    return query_result_str:match(TARGET_VERSION_PATTERN)
end

local function get_target_version(query_result_str)
    local status, version_list = pcall(json.decode, query_result_str)

    if not status or not version_list then
        return PEARL.error("JSON failed to decode the version query result.")
    end

    local releases = version_list.release
    if releases then
        return releases[#releases]
    end
end

-------------------------------------
-- [[ Functions ]]
-------------------------------------

local function StopVersionCheckTask()
    if task ~= nil then
        PEARL.debug("Stopping version check task...")

        task:cancel()
        task = nil
    end
end

local function IsAutoUpdateEnabled()
    return (PEARL.CONFIG.VERSION_CHECKER.UPDATE_AFTER or 0) > 0
end

local function NotifyVersionMismatch()
    TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_FIRST_DIS)
end

local function StartServerUpdate()
    TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_START:format(target_version))

    -- Make sure the world is saved at this point.
    TheWorld:PushEvent("ms_save")

    PEARL.ModShutdown()

    PEARL.WallScheduler:ExecuteInTime(2, function()
        -- Keep this here so the default disconnect event wont have a chance to reach the server.
        PEARL.ServerNetwork:DisconnectAllClients(nil, true)

        PEARL.BroadcastRPCToConnectedShards(PEARL.RPC.BroadcastLua, "TheSim:Crash()")
        PEARL.WallScheduler:ExecuteInTime(1, function()
            PEARL.warn("Shutting down with an error status code to force the provider to restart us!")

            TheSim:Crash()
        end)
    end)
end

local function DoAutoUpdate()
    PEARL.debug("Version mismatch detected!")

    if TheNet:GetPlayerCount() > 0 then
        TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_FIRST:format(
            PEARL.CONFIG.VERSION_CHECKER.UPDATE_AFTER
        ))

        PEARL.WallScheduler:ExecuteInTime(PEARL.CONFIG.VERSION_CHECKER.UPDATE_AFTER * PEARL.CONSTS.FPS - 15, function()
            TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_SECOND)

            PEARL.WallScheduler:ExecuteInTime(16, function()
                StartServerUpdate()
            end)
        end)

        return
    else
        StartServerUpdate()
    end

    StopVersionCheckTask()
end

-- Returns true on success otherwise false
local function CheckAppVersion()
    PEARL.debug("CheckAppVersion", current_version, target_version)

    if current_version < target_version then
        PEARL.info("Running on an older version!")

        if IsAutoUpdateEnabled() then
            DoAutoUpdate()
            return false
        end

        NotifyVersionMismatch()

        if TheNet:GetPlayerCount() <= 0 then
            -- Announce the version mismatch just once.
            StopVersionCheckTask()
        end

        return false
    end

    PEARL.debug("Version up-to-date!")
    return true
end

local function OnVersionCheckQueryComplete(response)
    -- Try to use the optimized string based approach first, if that fails
    -- use the default json one or return zero.
    target_version = tonumber(get_target_version_from_string(response))
        or tonumber(get_target_version(response))
        or 0

    if target_version < 1 then
        return PEARL.error("Failed to retrive target version!")
    end

    CheckAppVersion()
end

local function DoVersionCheckTask()
    PEARL.debug("DoVersionCheck")
    if target_version == 0 or CheckAppVersion() then
        PEARL.HTTPClient:GET(
            PEARL.CONSTS.DST_BUILDS, OnVersionCheckQueryComplete, VERSION_QUERY_TIMEOUT
        ):SetIsRaw(true):Send()
    end
end


local function StartVersionCheckTask()
    PEARL.debug("Starting version check task...")

    local initialdelay = PEARL.ServerNetwork:GetConnectedClientsCount() > 0 and INITIAL_DELAY or 1
    task = PEARL.WallScheduler:ExecutePeriodic(
        -- In case of a restart, wait for all the players to load before displaying the message.
        (PEARL.CONFIG.VERSION_CHECKER.FREQUENCY * 60), DoVersionCheckTask, nil, initialdelay
    )
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

PEARL.AddSimPostInit(StartVersionCheckTask)
