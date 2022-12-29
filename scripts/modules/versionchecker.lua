--[[
    Module for keeping the server up-to-date. Uses Klei's API to get the latest
    release version. When the version is higher than the current one,
    it notifies the players and shutdowns all the shards. So there needs to be
    a third party program which then effectively updates and starts the server again.
--]]

local PEARL = PEARL
local APP_VERSION, json, LoadingStates = APP_VERSION, json, LoadingStates
local TheNet = TheNet
local tonumber, tostring, pcall = tonumber, tostring, pcall

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local VERSION_QUERY_TIMEOUT = 10
local TARGET_VERSION_PATTERN = ",\"(%d+)\"%],\"staging\":%[\"%d+\","

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

        task:Cancel()
        task = nil
    end
end

local function IsAutoUpdateEnabled()
    return (PEARL.CONFIG.UPDATE_SERVER_AFTER or 0) > 0
end

local function NotifyVersionMismatch()
    TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_FIRST_DIS)
end

local function StartServerUpdate()
    TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_START:format(target_version))

    PEARL.Scheduler:ExecuteInTime(2, function()
        -- Show the loading screen to all all players,
        -- so we can shutdown gracefully...
        --- @TODO debug a bit more since it seems to not work properly
        TheNet:NotifyLoadingState(LoadingStates.Loading)

        PEARL.SafeShutdownAllShards()
    end)
end

local function DoAutoUpdate()
    PEARL.debug("Version mismatch detected!")

    if TheNet:GetPlayerCount() > 0 then
        TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_FIRST:format(
            PEARL.CONFIG.UPDATE_SERVER_AFTER
        ))

        PEARL.Scheduler:ExecuteInTime(PEARL.CONFIG.UPDATE_SERVER_AFTER * 60 - 15, function()
            TheNet:SystemMessage(STRINGS.PEARL.LOGS.AUTO_UPDATE_SECOND)

            PEARL.Scheduler:ExecuteInTime(16, function()
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
    if current_version < target_version then
        if IsAutoUpdateEnabled() then
            DoAutoUpdate()
            return false
        end

        NotifyVersionMismatch()

        if TheNet:GetPlayerCount() <= 0 then
            -- No new players should be able to join at this point.
            StopVersionCheckTask()
        end

        return false
    end

    return true
end

local function OnVersionCheckQueryComplete(result, isSuccessful, resultCode)
    if not (isSuccessful and result and #result > 1) then
        return PEARL.error(
            "Wasn't able to fetch the most current build version! Query failed with reason:", result
        )
    end

    -- Try to use the optimized string based approach first, if that fails
    -- use the default json one or return zero.
    target_version = tonumber(get_target_version_from_string(result))
        or tonumber(get_target_version(result))
        or 0

    CheckAppVersion()
end

local function DoVersionCheckTask()
    if CheckAppVersion() then
        PEARL.RestClient:GET(
            PEARL.CONSTS.DST_BUILDS, OnVersionCheckQueryComplete, VERSION_QUERY_TIMEOUT
        ):Send()
    end
end


local function StartVersionCheckTask()
    PEARL.debug("Starting version check task...")
    task = PEARL.Scheduler:ExecutePeriodic(
        (PEARL.CONFIG.VERSION_CHECK_FREQUENCY * 60), DoVersionCheckTask, nil, 0.2 -- for debugging
    )
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

AddGamePostInit(StartVersionCheckTask)
