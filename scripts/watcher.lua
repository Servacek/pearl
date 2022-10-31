setfenv(1, _G.SUB.env)
local Whitelist = require('components/whitelist')

local SUB, ACTIONS = SUB, ACTIONS
local TheNet, TheShard = TheNet, TheShard
local string = string

----------------------------
-- [[ Private functions ]]
----------------------------

local function doextinguishfn(pos, doer)
    pos = pos or (doer and doer:GetPosition()) or nil
    if not pos then return end

    SUB.ExtinguishFiresNear(pos:Get())
    if doer and doer:IsValid() then
        TheNet:Announce(string.format(SUB.STRINGS.EXTINGUISH_NEAR,
            doer:GetDisplayName()
        ))

        doer:RemoveTag("arsonist")
    else
        TheNet:Announce(SUB.STRINGS.EXTINGUISH)
    end
end

-------------------------------

local Watcher = Class(function(self)
    -- Array of {count: int, ext_task: nil or Task}
    self.grief_attempts = {}
    self.whitelist = nil
    self.is_sim_ready = false

    if SUB.CONSTANTS.WHITELIST_ENABLED then--or SUB.CONSTANTS.LOG_SUSPICIOUS_INVENTORIES then
        self.whitelist = Whitelist()

        SUB.info("Watcher", "Loading whitelist...")
        self.whitelist:Load()
    end
end)

----------------------------
-- [[ Public Functions ]]
----------------------------

function Watcher:UpdateGriefAttemptsCounter()
    for _, data in pairs(self.grief_attempts) do
        data.count = data.count - 1

        if data.count <= 0 then
            data = nil
        end
    end
end

-- Returns true when the doer is kicked from the server
-- otherwise false
function Watcher:OnGriefAttempt(doer)
    -- Admins can't be penalized for their actions
    -- so we don't care about them...
    if not doer or doer.admin or not doer:IsValid() then return false end

    -- These attempt points will be removed
    -- on each time a "phasechanged" event is pushed
    if not self.grief_attempts[doer.userid] or not self.grief_attempts[doer.userid].count then
        self.grief_attempts[doer.userid] = { count = 1 }
    else
        self.grief_attempts[doer.userid].count = self.grief_attempts[doer.userid].count + 1
    end

    -- it's most likely a griefer so we want to kick this player out
    if self.grief_attempts[doer.userid].count >= SUB.CONSTANTS.MAX_FIRE_ATTEMPTS then
        SUB.debug(nil, "KICKING", doer.userid)

        doextinguishfn(doer:GetPosition(), doer)
        TheNet:Kick(doer.userid)
        self.grief_attempts[doer.userid] = nil

        return true
    end

    return false
end

function Watcher:OnSimPostInit()
    self.is_sim_ready = true

    if not TheNet:GetIsMasterSimulation() then return end
    if TheShard:IsSecondary() then return end

    SUB.CONSTANTS.WEB_API_TOKEN = _G.TheFrontEnd:GetAccountManager():HasAuthToken() and _G.TheFrontEnd:GetAccountManager():GetToken() or nil
    if not SUB.CONSTANTS.WEB_API_TOKEN then
        return error("[ERROR] Cluster token not found!")
    end
end

function Watcher:OnStartedFire(doer, inst)
    if doer ~= nil and inst ~= nil and inst.target ~= nil then
        local target = inst.target
        local entities = SUB.GetEntitiesNear(
            target, SUB.CONSTANTS.FIRE_RADIUS,
            SUB.CONSTANTS.FIRE_MUSTHAVE_TAGS,
            SUB.CONSTANTS.FIRE_CANTHAVE_TAGS,
            SUB.CONSTANTS.FIRE_ONEOF_TAGS
        )

        --table.foreach(entities, print)
        if not SUB.IsMonitored(target) and (entities == nil or #entities < 1) then
            return
        end

        if (SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
            SUB.Logger.OnIgniteEntity(doer, target, entities)
        end

        if SUB.CONSTANTS.FIRE_PROTECTION_ENABLED
        and (#entities > 2 and SUB.ArrayContainsEntityWithTag(entities, "structure")
        or #entities > 4) then
            if self:OnGriefAttempt(doer) then return end

            if not doer:HasTag("arsonist") then
                doer:AddTag("arsonist")

                if self.grief_attempts[doer.userid].task then return end

                self.grief_attempts[doer.userid].task = _G.TheWorld:DoTaskInTime(SUB.CONSTANTS.EXTINGUISH_AFTER,
                    function()
                        doextinguishfn(target:GetPosition(), doer)

                        if self.grief_attempts[doer.userid] then
                            self.grief_attempts[doer.userid].task = nil
                        end
                    end
                )
            end
        end
    end
end

function Watcher:CheckIsClientAllowedToJoin(userid)
    if userid == nil then return end

    local client = TheNet:GetClientTableForUser(userid)
    if client and client.admin then return end -- ignore admins

    -- If the user is not cached then we want to send a query to the server.
    if not SUB.BlacklistManager.GetCachedRootUserid(userid) then
        SUB.info("Watcher", "User not cached, sending Family Sharing check query...")
        SUB.BlacklistManager.SendFamilySharingCheckQueryFor(userid)
    end

    if not self.whitelist or SUB.BlacklistManager.IsUserBlacklisted(userid) then return end
    SUB.debug("Watcher", "Checking the whitelist.")
    if not self.whitelist:Contains(userid) then
        SUB.Logger.OnClientNotWhitelisted(userid)

        SUB.debug("Watcher", "Not whitelisted, kicking...")
        TheNet:Kick(userid)
    end
end

local PLAYER_TRUST_AGE = 25
function Watcher:CheckPlayersInventory(player)
    if not player or not player.userid then return end
    if not player.age or not TheWorld.state then return end

    if TheWorld.state.cycles < 31 or player.age >= PLAYER_TRUST_AGE then return end

    local client = TheNet:GetClientTableForUser(player.userid)
    if not client or client.admin then return end

    local sus_inv
    if player.components and player.components.inventory then
        sus_inv = player.components.inventory:FindItem(function(item)
            return item and SUB.PREFABS.MONITOR_PICKUP[item.prefab]
        end) ~= nil
    end
    -- TODO: support saved inventories

    if sus_inv then
        SUB.info("Watcher", "Suspicious inventory detected! Owner:", player.name or player.userid)

        local inventory, prefab, name = SUB.GetInventoryTabelFor(player.userid, player)
        local embed = SUB.InventoryToEmbed(inventory, prefab, player.name or name, player.userid)

        SUB.info("Watcher", "Logging inventory for player", player.name or name or player.userid)
        SUB.Webhook:SendEmbed(embed)
    end
end

-- function Watcher:CheckForSuspiciousInventory(player)
--     if player ~= nil then--and not player.admin and not self.whitelist:Contains(player.userid) then
--         print("CHECKING INVENTORY")
--         local inventory, prefab, name = SUB.GetInventoryTabelFor(player.userid, player)

--         print(#inventory)
--         if not SUB.InventoryContainsRareItem(inventory) then
--             return
--         end

--         print(inventory)
--         local embed = SUB.InventoryToEmbed(inventory, player.userid, prefab, name)
--         if embed then
--             local message = Message()
--             message:AddEmbed(embed)

--             SUB.Webhook:SendMessage(message)
--         end
--     end
-- end

function Watcher:IsSimulationReady()
    return self.is_sim_ready
end

-----------------------------

-- local _OnServerPauseDirty = _G.OnServerPauseDirty
-- _G.OnServerPauseDirty = function(...)
--     SUB.Logger.OnServerPausedDirty(...)

--     return _OnServerPauseDirty(...)
-- end


local _WorldRollbackFromSim = _G.WorldRollbackFromSim
_G.WorldRollbackFromSim = function(...)
    SUB.Logger:OnRollback(...)

    return _WorldRollbackFromSim(...)
end

local _WorldResetFromSim = _G.WorldResetFromSim
_G.WorldResetFromSim = function(...)
    SUB.Logger:OnRegenerateWorld()

    return _WorldResetFromSim(...)
end

local _SaveAndShutdown = _G.SaveAndShutdown
_G.SaveAndShutdown = function(...)
    SUB.Logger:OnSaveShutdown()

    return _SaveAndShutdown(...)
end

local _Shard_UpdateWorldState = _G.Shard_UpdateWorldState
_G.Shard_UpdateWorldState = function(...)
    SUB.Logger:OnShardStateUpdate(...)

    return _Shard_UpdateWorldState(...)
end

if SUB.CONSTANTS.USE_WALL_SCHEDULER and _G.SUB.WallScheduler then
    local _WallUpdate = _G.WallUpdate
    _G.WallUpdate  = function(...)
        _G.SUB.WallScheduler:OnWallUpdate()

        return _WallUpdate(...)
    end
end

-----------------------------

function Watcher:RegisterActionHandler(action, handler, ...)
    local _default_handler_fn = action.fn
    action.fn = function(act, ...)
        local success = _default_handler_fn(act, ...)
        if success and act ~= nil and handler ~= nil then
            SUB.SafeRun(handler,
                act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint(), ...
            )
        end

        return success
    end
end

function Watcher:RegisterActionHandlers()
    if (SUB.CONSTANTS.ANNOUNCE_DESTROY or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.HAMMER, SUB.Logger.OnActionHammer)
    end

    if (SUB.CONSTANTS.ANNOUNCE_DESTROY or SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.CASTSPELL, SUB.Logger.OnActionCastSpell)
    end

    if (SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.BUILD, SUB.Logger.OnActionBuild)
    end

    -- TODO
    -- if (SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
    --     self:RegisterActionHandler(ACTIONS.ATTACK, SUB.Logger.OnActionAttack)
    -- end

    if (SUB.ANNOUNCE_EATRARE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.FEED, SUB.Logger.OnActionFeed)
    end

    if (SUB.ANNOUNCE_EATRARE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.GIVE, SUB.Logger.OnActionFeed)
    end
end

function Watcher:RegisterWorldEvents(inst)
    if SUB.CONSTANTS.DISCORD_LOGS_ENABLED then
        inst:ListenForEvent("cycleschanged", SUB.Logger.OnCyclesChanged)
        -- inst:ListenForEvent("precipitationchanged", SUB.Logger.OnPrecipitationChanged)
        --inst:ListenForEvent("serverpauseddirty", SUB.Logger.OnServerPausedDirty)

        inst:ListenForEvent("ms_clientdisconnected", SUB.Logger.OnClientDisconnected)
        inst:ListenForEvent("ms_playerdespawnandmigrate", SUB.Logger.OnPlayerMigrating)
        if SUB.CONSTANTS.LOG_SUSPICIOUS_INVENTORIES then
            -- TODO: maybe there is a better event for this
            inst:ListenForEvent("ms_playerdespawn", function(world, player)
                self:CheckPlayersInventory(player)
            end)
        end

        inst:ListenForEvent("ms_clientauthenticationcomplete", function(world, data)
            if data == nil then return end
            if SUB.IsClientMigrating(data) then return end

            SUB.Logger.OnClientAuthenticationComplete(data)
            self:CheckIsClientAllowedToJoin(data.userid)
        end)
    end

    inst:ListenForEvent("phasechanged", function(world, phase)
        if SUB.CONSTANTS.FIRE_PROTECTION_ENABLED and SUB.CONSTANTS.MAX_FIRE_ATTEMPTS > 0 then
            self:UpdateGriefAttemptsCounter()
        end

        SUB.Logger.OnPhaseChanged(world, phase)
    end)

    if (SUB.CONSTANTS.ANNOUNCE_KILLBOSS
    or SUB.CONSTANTS.ANNOUNCE_KILLFOLOWER or SUB.CONSTANTS.ANNOUNCE_IGNITE) then
        inst:ListenForEvent("entity_death", function(_, data)
            SUB.SafeRun(SUB.Logger.OnEntityDeath, data)
        end)
    end
end

function Watcher:RegisterPlayerEvents(inst)
    if inst == nil then
        return
    end

    if (SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED
    or SUB.CONSTANTS.FIRE_PROTECTION_ENABLED) then
        inst:ListenForEvent("onstartedfire", function(...)
            SUB.SafeRun(self.OnStartedFire,
                self, ...
            )
        end)
    end

    if (SUB.CONSTANTS.ANNOUNCE_EATRARE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        inst:ListenForEvent("oneat", SUB.Logger.OnPlayerAteFood)
    end

    if inst.components and inst.components.builder then
        inst.components.builder.onBuild = SUB.Logger.OnBuild
    end
end

----------------------------
-- [[ Post Inits ]]
----------------------------

SUB.Watcher = Watcher()

AddPlayerPostInit(function(inst)
    if not _G.TheWorld.ismastersim then return end

    SUB.Watcher:RegisterPlayerEvents(inst)
end)

-- Here TheWorld is ready so we can register the events which rely on it
AddSimPostInit(function()
    if SUB.Webhook then
        SUB.Webhook:OnSimPostInit()
    end

    if SUB.Watcher then
        SUB.Watcher:OnSimPostInit()

        SUB.Watcher:RegisterWorldEvents(_G.TheWorld) -- This needs to be global!
        SUB.Watcher:RegisterActionHandlers()
    end

    if SUB.VersionChecker then
        SUB.VersionChecker:Start()
    end

    SUB.EMOTES = GetEmotesWordPredictionDictionary().words
end)

local function OnSaveBuilder(inst, data)
    if not inst or not data then return end

    if inst.builder then
        data.builder = inst.builder
    end
end

local function OnLoadBuilder(inst, data)
    if not inst or not data then return end

    if data.builder then
        inst.builder = data.builder
    end
end

AddPrefabPostInitAny(function(inst)
    if SUB.CONSTANTS.ANNOUNCE_BURNTUP and TheShard:IsMaster()
    and inst and inst:IsValid() and inst:HasTag("structure")
    and not inst:HasTag("burnt") and inst.components.burnable then
        inst:ListenForEvent("burntup", SUB.Logger.OnStructureBurntUp)
    end

    if inst.components and inst.components.workable then
        local _OnSave = inst.OnSave
        local _OnLoad = inst.OnLoad

        inst.OnSave = function(...)
            if _OnSave then
                _OnSave(...)
            end

            OnSaveBuilder(...)
        end

        inst.OnLoad = function(...)
            if _OnLoad then
                _OnLoad(...)
            end

            OnLoadBuilder(...)
        end
    end
end)

-- TODO
-- if SUB.CONSTANTS.ANNOUNCE_PICKUP then
--     for prefab, _ in pairs(SUB.PREFABS.MONITOR_PICKUP) do
--         AddPrefabPostInit(prefab, function(inst)
--             if inst and inst.components and inst.components.inventoryitem then
--                 inst:ListenForEvent("onputininventory", SUB.Logger.OnPutInInventory)
--                 -- inst:ListenForEvent("onownerputininventory", SUB.Logger.OnPutInInventory)

--                 -- inst:PushEvent("ondropped", function(item, owner)
--                 --     if item.last_owner then
--                 --         item.lastowner = nil
--                 --     end
--                 -- end)

--                 inst.components.inventoryitem:SetOnActiveItemFn(function(inst, ...)
--                     inst.components.inventoryitem:SetOwner(inst.lastowner)
--                 end)
--             end
--         end)
--     end
-- end