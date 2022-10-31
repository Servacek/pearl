require('class')

setfenv(1, _G.SUB.env)
local Whitelist = require('components/whitelist')
local SUB, ACTIONS = SUB, ACTIONS
local TheNet, TheShard = TheNet, TheShard
local string = string

----------------------------
-- [[ Private functions ]]
----------------------------

local function doextinguishfn(world, pos, doer)
    if pos == nil then
        return
    end
    SUB.ExtinguishFiresNear(pos:Get())

    if doer ~= nil then
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
    self.grief_attempts = {}
    self.whitelist = nil
    self.is_sim_ready = false

    if SUB.CONSTANTS.WHITELIST_ENABLED then
        self.whitelist = Whitelist()

        SUB.info("Watcher", "Loading whitelist...")
        self.whitelist:Load()
    end
end)

----------------------------
-- [[ Public Functions ]]
----------------------------

function Watcher:UpdateGriefAttemptsCounter()
    for doer_userid, count in pairs(self.grief_attempts) do
        self.grief_attempts[doer_userid] = count - 1

        if self.grief_attempts[doer_userid] <= 0 then
            self.grief_attempts[doer_userid] = nil
        end
    end
end

function Watcher:OnGriefAttempt(doer)
    -- Admins can't be penalized for their actions
    -- so we don't care about them...
    if doer.admin then return end

    -- These attempt points will be removed
    -- on each time a "phasechanged" event is pushed
    if self.grief_attempts[doer.userid] == nil then
        self.grief_attempts[doer.userid] = 1
    else
        self.grief_attempts[doer.userid] = self.grief_attempts[doer.userid] + 1
    end

    -- it's most likely a griefer so we want to kick this player out
    if self.grief_attempts[doer.userid] >= SUB.CONSTANTS.MAX_FIRE_ATTEMPTS then
        SUB.debug(nil, "KICKING", doer.userid)
        TheNet:Kick(doer.userid)
        self.grief_attempts[doer.userid] = nil
    end
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

-- TODO: debug
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
        if not SUB.IsMonitored(target) and entities ~= nil and #entities <= 1 then
            return
        end

        if (SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
            SUB.Logger.OnIgniteEntity(doer, target, entities)
        end

        if SUB.CONSTANTS.FIRE_PROTECTION_ENABLED
        and (#entities > 3 and SUB.ArrayContainsEntityWithTag(entities, "structure")
        or #entities > 5) then
            if not doer:HasTag("arsonist") then
                doer:AddTag("arsonist")

                TheWorld:DoTaskInTime(SUB.CONSTANTS.EXTINGUISH_AFTER,
                    doextinguishfn, target:GetPosition(), doer
                )
            end

            self:OnGriefAttempt(doer)
        end
    end
end

function Watcher:CheckIsClientAllowedToJoin(userid)
    if userid == nil then return end

    local client = TheNet:GetClientTableForUser(userid)
    if client and client.admin then return end -- ignore admins

    SUB.debug("Watcher", "Checking if the account is an alt with banned root.")
    SUB.BlacklistManager.SendFamilySharingCheckQueryFor(userid)

    if not self.whitelist or SUB.BlacklistManager.IsUserBlacklisted(userid) then return end
    SUB.debug("Watcher", "Checking the whitelist.")
    if not self.whitelist:Contains(userid) then
        SUB.Logger.OnClientNotWhitelisted(userid)

        SUB.debug("Watcher", "Not whitelisted, kicking...")
        TheNet:Kick(userid)
    end
end

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

function Watcher:RegisterActionHandler(action, handler)
    local _action = action.fn
    action.fn = function(act, ...)
        if act ~= nil and handler ~= nil then
            handler(act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint())
        end

        return _action(act, ...)
    end
end

function Watcher:RegisterActionHandlers()
    if (SUB.CONSTANTS.ANNOUNCE_DESTROY or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.HAMMER, SUB.Logger.OnActionHammer)
    end

    if (SUB.CONSTANTS.ANNOUNCE_DESTROY or SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.CASTSPELL, SUB.Logger.OnActionCastSpell)
    end

    -- TODO
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

    -- TODO
    if (SUB.ANNOUNCE_EATRARE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED) then
        self:RegisterActionHandler(ACTIONS.GIVE, SUB.Logger.OnActionFeed)
    end
end

function Watcher:RegisterWorldEvents(inst)
    --local target_time = os.time() + SUB.CONSTANTS.UPDATE_CHECK_FREQUENCY

    if SUB.CONSTANTS.DISCORD_LOGS_ENABLED then
        inst:ListenForEvent("cycleschanged", SUB.Logger.OnCyclesChanged)
        inst:ListenForEvent("precipitationchanged", SUB.Logger.OnPrecipitationChanged)
        --inst:ListenForEvent("serverpauseddirty", SUB.Logger.OnServerPausedDirty)

        inst:ListenForEvent("ms_clientdisconnected", SUB.Logger.OnClientDisconnected)
        inst:ListenForEvent("ms_playerdespawnandmigrate", SUB.Logger.OnPlayerMigrating)

        inst:ListenForEvent("ms_clientauthenticationcomplete", function(world, data)
            if data == nil then return end

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
        inst:ListenForEvent("entity_death", SUB.Logger.OnEntityDeath)
    end
end

function Watcher:RegisterPlayerEvents(inst)
    if inst == nil then
        return
    end

    if (SUB.CONSTANTS.ANNOUNCE_IGNITE or SUB.CONSTANTS.DISCORD_LOGS_ENABLED
    or SUB.CONSTANTS.FIRE_PROTECTION_ENABLED) then
        inst:ListenForEvent("onstartedfire", function(...)
            self:OnStartedFire(...)
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

AddSimPostInit(function()
    SUB.Watcher:OnSimPostInit()
    SUB.Webhook:OnSimPostInit()

    SUB.Watcher:RegisterWorldEvents(_G.TheWorld) -- This needs to be global!
    SUB.Watcher:RegisterActionHandlers()

    SUB.VersionChecker:Start()
end)

-- AddPrefabPostInit("world", function()
--     if not TheNet:GetIsMasterSimulation() then return end
--     if TheShard:IsSecondary() then return end

--     SUB.CONSTANTS.WEB_API_TOKEN = _G.TheFrontEnd:GetAccountManager():HasAuthToken() and _G.TheFrontEnd:GetAccountManager():GetToken() or nil
--     if not SUB.CONSTANTS.WEB_API_TOKEN then
--         return error("[ERROR] Cluster token not found!")
--     end
-- end)

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

if SUB.CONSTANTS.ANNOUNCE_BURNTUP then
    AddPrefabPostInitAny(function(inst)
        if TheShard:IsMaster() and inst and inst:IsValid() and inst:HasTag("structure")
        and not inst:HasTag("burnt") and inst.components.burnable then
            inst:ListenForEvent("burntup", SUB.Logger.OnStructureBurntUp)
        end
    end)
end