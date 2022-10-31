require("class")


setfenv(1, _G.SUB.env)

local APP_VERSION, AllPlayers, json = APP_VERSION, AllPlayers, json
local TheSim, TheNet, TheShard = TheSim, TheNet, TheShard
local SUB, Scheduler, Webhook, ICONS = SUB, SUB.Scheduler, SUB.Webhook, SUB.ICONS
local SendModRPCToShard, GetShardModRPC = SendModRPCToShard, GetShardModRPC


local function get_target_version(query_result_str)
    local status, version_list = pcall(function()
        return json.decode(query_result_str)
    end)

    if not status or not version_list then
        return SUB.Error("VersionChecker", "JSON failed to decode the version query result.")
    end

    local releases = version_list.release
    if releases and #releases > 0 then
        return releases[#releases]
    end
end

local function notify(message)
    if TheShard:IsMaster() then
        TheNet:SystemMessage(message)
        Webhook:SendAnnouncement(message, ICONS.LOGS["announcement"], true)
    end
end

local function broadcast_shutdown_to_shards(...)
    SendModRPCToShard(GetShardModRPC(SUB.CONSTANTS.RPC, SUB.CONSTANTS.SHUTDOWN_RPC_NAME),
        nil, ...
    )
end

------------------------------------------

local VersionChecker = Class(function(self)
    self.app_version = tonumber(APP_VERSION)-- - 20
    self.target_version = nil
    self.version_mismatch = false
    self.task = nil
end)

function VersionChecker:Start()
    if TheShard:IsSecondary() then return end

    SUB.debug("VersionChecker", "Starting...")
    self.task = Scheduler:ExecutePeriodic(
        (SUB.CONSTANTS.UPDATE_CHECK_FREQUENCY * 60), self.DoTask, nil, nil, 22, self
    )
end

function VersionChecker:Stop()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

function VersionChecker:SetTargetVersion(target_version)
    self.target_version = tonumber(target_version)

    if self.target_version > self.app_version then
        self.version_mismatch = true
    end
end

------------------------------------------

function VersionChecker:OnVersionMismatch()
    if #AllPlayers > 0 then
        if not (SUB.CONSTANTS.TIME_UNTIL_SERVER_UPDATE > 0) then
            return notify(SUB.STRINGS.AUTO_UPDATE_FIRST_DIS)
        end

        notify(string.format(
            SUB.STRINGS.AUTO_UPDATE_FIRST, SUB.CONSTANTS.TIME_UNTIL_SERVER_UPDATE
        ))
        Scheduler:ExecuteInTime(SUB.CONSTANTS.TIME_UNTIL_SERVER_UPDATE * 60 - 15, function()
            notify(SUB.STRINGS.AUTO_UPDATE_SECOND)

            Scheduler:ExecuteInTime(16, function()
                notify(string.format(
                    SUB.STRINGS.AUTO_UPDATE_START, self.target_version
                ))

                broadcast_shutdown_to_shards()
                _G.c_shutdown()
            end)
        end)
    else
        Webhook:SendAnnouncement(string.format(
            SUB.STRINGS.AUTO_UPDATE_START, self.target_version
        ), ICONS.LOGS["announcement"], true)

        -- First we want to shutdown the caves
        broadcast_shutdown_to_shards()
        _G.c_shutdown()
    end

    self:Stop()
end

function VersionChecker:OnVersionCheckQueryComplete(result, isSuccessful, resultCode)
    if isSuccessful and result and string.len(result) > 1 and resultCode == 200 then
        self:SetTargetVersion(get_target_version(result))

        if self.version_mismatch then
            self:OnVersionMismatch()
        end
    else
        SUB.error("VersionChecker", "Wasn't able to fetch the most current build version! Query Failed.")
    end
end

-----------------------------------

function VersionChecker:DoTask()
    if TheShard:IsSecondary() then
        return
    end

    if self.version_mismatch then
        return self:OnVersionMismatch()
    end

    TheSim:QueryServer(SUB.CONSTANTS.DST_BUILDS, function(...)
        self:OnVersionCheckQueryComplete(...)
    end, "GET")
end

-----------------------------------

SUB.VersionChecker = VersionChecker()