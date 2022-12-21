--[[
    Big TODOS for v2.1:
        - Implement penalization and reputation systems.
        - Implement protector.lua
        ...
--]]

local EventHandlers = require("eventhandlers")

local PEARL, ACTIONS = PEARL, ACTIONS
local TheNet = TheNet

----------------------------
-- [[ Private functions ]]
----------------------------

local onburntup
onburntup = function(target)
    PEARL.DiscordLogger.OnStructureBurntUp(target)

    target:RemoveEventCallback("burntup", onburntup)
end

local function onactivated(target, data)
    PEARL.debug("ON ACTIVATED", target, data)
    if not (data and data.doer) then
        return
    end

    PEARL.DiscordLogger.OnActivated(data.doer, target)
end

local function onbuildstructure(doer, data)
    PEARL.debug("ON BUILD STRUCTURE")
    if not (doer and data and data.item and doer:HasTag("player")) then return end
    if not PEARL.PREFABS.FIRE_SOURCES[data.item.prefab] then return end

    local entities = data.item:GetEntitiesNear(
        PEARL.CONSTS.FIRE_RADIUS,
        PEARL.CONSTS.FIRE_MUSTHAVE_TAGS,
        PEARL.CONSTS.ENT_CANTHAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS
    )
    if #entities > 0 then
        if PEARL.CONFIG.ANNS.IGNITE then
            PEARL.DiscordLogger.OnBuildStructure(doer, data.item, entities)
        end

        if PEARL.CONFIG.GRIEF_PROTECTION then
            PEARL.Penalizer:OnBuildStructure(doer, data.item, entities)
        end
    end
end

----------------------------
-- [[ Class Declaration ]]
----------------------------

local Watcher = {}

----------------------------
-- [[ Public Functions ]]
----------------------------

--- @deprecated
-- function Watcher:CheckIsClientAllowedToJoin(userid)
--     if userid == nil then return end

--     --if SUB.IsAdminUserid(userid) then return end

--     -- If the user is not cached then we want to send a query to the server.
--     if not PEARL.Blacklist.GetCachedRootUserid(userid) then
--         PEARL.info("Watcher", "User not cached, sending Family Sharing check query...")
--         PEARL.Blacklist.SendFamilySharingCheckQueryFor(userid)
--     end

--     if not self.SUB.Whitelist or PEARL.Blacklist.IsUserBlacklisted(userid) then return end
--     PEARL.debug("Watcher", "Checking the whitelist.")
--     if self.SUB.Whitelist:Contains(userid) then
--         return
--     end

--     PEARL.Logger.OnClientNotWhitelisted(userid)
--     PEARL.debug("Watcher", "Not whitelisted, not allowing the connection...")

--     -- If we have frontend enabled, disconnect the user
--     -- gracefully with a nice custom popup.
--     if PEARL.IsFrontEndEnabled() then
--         SUF.SendRPCToClient(SUF.RPCS.Disconnect, userid, "ID_DST_USER_NOT_ALLOWED")
--     else -- Otherwise just kick
--         TheNet:Kick(userid)
--     end
-- end

--- @deprecated
-- function Watcher:CheckPlayersInventory(player)
--     if not player or not player.userid then return end
--     if not player.components or not TheWorld.state then return end

--     if TheWorld.state.cycles < 31
--     or player.components.age and player.components.age:IsTrustworthy() then return end

--     if PEARL.IsAdminUserid(player.userid) then
--         return
--     end

--     local sus_inv
--     if player.components.inventory then
--         sus_inv = player.components.inventory:FindItem(function(item)
--             return item and PEARL.PREFABS.RARE_ITEMS[item.prefab]
--         end) ~= nil
--     end
--     -- TODO: support saved inventories

--     if sus_inv then
--         PEARL.info("Watcher", "Suspicious inventory detected! Owner:", player.name or player.userid)

--         local inventory, prefab, name = PEARL.GetInventoryTabelFor(player.userid, player)
--         local embed = PEARL.InventoryToEmbed(inventory, prefab, player.name or name, player.userid)

--         PEARL.info("Watcher", "Logging inventory for player", player.name or name or player.userid)
--         PEARL.Logger:LogEmbed(embed)
--     end
-- end

----------------------------
-- [[ Registers ]]
----------------------------

--- @TODO v2.1
-- function Watcher:WatchPlayerFor(player, event, conf, icon, act, handlerfn)
--     -- Check for required arguments
--     if not (player and event and handlerfn) then
--         return
--     end

--     player:SafeListenForEvent(event, function(doer, data, ...)
--         local penalty, str, announce = handlerfn(doer, data, act, ...)

--         -- Debug
--         if type(penalty) == "number" and penalty > 0 and doer.components and doer.components.griefer then
--             doer.components.griefer:DoDelta(penalty)
--         end

--         if type(str) == "string" and #str > 0 then
--             PEARL.debug("CONF", conf, "ANNOUNCE", announce)
--             if conf and announce then
--                 PEARL.Announce(str, icon)
--             end

--             if PEARL.CONFIG.DISCORD.ENABLED then
--                 PEARL.Logger:LogString(str, icon)
--             end
--         end
--     end)
-- end

-- TODO: Move this to actions.lua
-- function Watcher:RegisterActionHandler(action, handler, pre, ...)
--     local _default_handler_fn = action.fn
--     action.fn = function(act, ...)
--         local success
--         if not pre then
--             success = _default_handler_fn(act, ...)
--         end

--         if (pre or success) and act ~= nil and handler ~= nil then
--             print(action)
--             local handler_result = SUB.SafeRun(handler,
--                 act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint(), ...
--             )

--             if pre and handler_result ~= nil then
--                 return handler_result
--             end
--         end

--         return pre and _default_handler_fn(act, ...) or success
--     end
-- end

-- BIG TODO
-- function Watcher:RegisterActionHandlers()
--     -- TODO: Add to the penalizer
--     if (SUB.CONSTS.ANNS.DESTROY or SUB.CONSTS.ANNS.IGNITE or SUB.CONSTS.DISCORD.ENABLED) then
--         self:RegisterActionHandler(ACTIONS.CASTSPELL, SUB.Logger.OnActionCastSpell)
--     end

--     if (SUB.CONSTS.ANNS.IGNITE or SUB.CONSTS.DISCORD.ENABLED) then
--         self:RegisterActionHandler(ACTIONS.BUILD, SUB.Logger.OnActionBuild)
--     end

--     -- TODO
--     -- if (SUB.CONSTS.ANNS.IGNITE or SUB.CONSTS.DISCORD.ENABLED) then
--     --     self:RegisterActionHandler(ACTIONS.ATTACK, SUB.Logger.OnActionAttack)
--     -- end

--     -- TODO: Add to the penalizer
--     if (SUB.CONSTS.ANNS.EATRARE or SUB.CONSTS.DISCORD.ENABLED) then
--         self:RegisterActionHandler(ACTIONS.FEED, SUB.Logger.OnActionFeed)
--     end

--     -- TODO: Add to the penalizer
--     if (SUB.CONSTS.ANNS.EATRARE or SUB.CONSTS.DISCORD.ENABLED) then
--         self:RegisterActionHandler(ACTIONS.GIVE, SUB.Logger.OnActionFeed)
--     end

--     if (SUB.CONSTS.ANNS.EATRARE or SUB.CONSTS.DISCORD.ENABLED) then
--         self:RegisterActionHandler(ACTIONS.EAT, function(doer, target, invobject)
--             if not invobject or not doer or not doer:HasTag("player") then
--                 return
--             end

--             -- If the food is on the rare list
--             if SUB.PREFABS.FOOD[invobject.prefab] then
--                 SUB.Logger.OnRareFoodAten(doer, invobject)
--                 SUB.Penalizer:HandleGrieferAction(
--                     SUB.GRIEFER_ACTIONS.EAT_RARE, doer, invobject
--                 )
--             end
--         end)
--     end

--     if (SUB.CONSTS.ANNS.DESTROY or SUB.CONSTS.DISCORD.ENABLED) then
--         -- This is an pre action handler
--         -- since we want to do some checks here.
--         self:RegisterActionHandler(ACTIONS.HAMMER, function(doer, target)
--             if not doer or not target or not doer:HasTag("player") then return end

--             if target.components and target.components.workable
--             and target.components.workable.workleft
--             and target.components.workable.workleft <= 0 then
--                 SUB.Logger.OnHammerStruct(doer, target)

--                 if target:HasBuilder() and not target:IsBuildBy(doer.userid) then
--                     SUB.Penalizer:HandleGrieferAction(
--                         SUB.GRIEFER_ACTIONS.HAMMER_OTHER, doer, target
--                     )
--                 end
--             end
--         end)
--     end

--     if (SUB.CONSTS.ANNS.TURNOFF or SUB.CONSTS.DISCORD.ENABLED) then
--         self:RegisterActionHandler(ACTIONS.TURNOFF, function(doer, target)
--             if not doer or not target or not doer:HasTag("player") then return end

--             if target:HasTag("hasemergencymode") then
--                 SUB.Logger.OnTurnOffEmergencyStruct(doer, target)
--             end
--         end)
--     end

--     -- if (SUB.CONSTS.ANNS.IGNITE or SUB.CONSTS.DISCORD.ENABLED or SUB.CONSTS.GRIEF_PROTECTION) then
--     --     self:RegisterActionHandler(ACTIONS.LIGHT, function(doer, target)
--     --         if not doer or not target or not doer:HasTag("player") then return end

--     --         local entities = target:GetEntitiesNear(
--     --             SUB.CONSTS.FIRE_RADIUS,
--     --             nil,
--     --             SUB.CONSTS.ENT_CANTHAVE_TAGS,
--     --             SUB.CONSTS.ENT_ONEOF_TAGS
--     --         )

--     --         if (SUB.CONSTS.ANNS.IGNITE or SUB.CONSTS.DISCORD.ENABLED) then
--     --             SUB.Logger.OnIgniteEntity(doer, target, entities)
--     --         end

--     --         if SUB.CONSTS.GRIEF_PROTECTION then
--     --             SUB.Penalizer:HandleGrieferAction(
--     --                 SUB.GRIEFER_ACTIONS.LIGHT_NEAR, doer, target, entities
--     --             )
--     --         end
--     --     end)
--     -- end

--     -- Decrease grief points when extinguishing fires
--     if (SUB.CONSTS.GRIEF_PROTECTION) then
--         self:RegisterActionHandler(ACTIONS.MANUALEXTINGUISH, function(doer)
--             print("EXT")
--             if not doer or not doer:HasTag("player") then return end

--             if doer.components and doer.components.griefer then
--                 doer.components.griefer:OnExtinguishedFires()
--             end
--         end)
--     end

--     -- TODO: debug
--     PORTAL_ZONE_RADIUS = 16
--     if (SUB.CONSTS.ANNS.DANGER_AT_PORTAL or SUB.CONSTS.DISCORD.ENABLED or SUB.CONSTS.GRIEF_PROTECTION) then
--         self:RegisterActionHandler(ACTIONS.DEPLOY, function(doer, target)
--             if not doer or not target or not doer:HasTag("player") then return end
--             if not target:HasOneOfTags(SUB.CONSTS.DANGER_ONOF_TAGS) then return end

--             local x, y, z = target.Transform:GetWorldPosition()
--             if TheSim:CountEntities(
--                 x, y, z, PORTAL_ZONE_RADIUS, nil, nil, {"multiplayer_portal"}
--             ) > 0 then
--                 SUB.Logger.OnDangerAtPortal(doer, target)
--                 SUB.Penalizer:OnDangerAtPortal(doer, target)
--             end
--         end)
--     end
-- end

-- function Watcher:RegisterPlayerEvents(inst)
--     if inst == nil then
--         return
--     end

--     -- if (SUB.CONSTS.ANNS.IGNITE or SUB.CONSTS.DISCORD.ENABLED
--     -- or SUB.CONSTS.GRIEF_PROTECTION) then
--     --     inst:ListenForEvent("onstartedfire", function(...)
--     --         SUB.SafeRun(self.OnStartedFire,
--     --             self, ...
--     --         )
--     --     end)
--     -- end

--     if (SUB.CONSTS.ANNS.EATRARE or SUB.CONSTS.DISCORD.ENABLED) then
--         inst:ListenForEvent("oneat", SUB.Logger.OnPlayerAteFood)
--     end
-- end

----------------------------

PEARL.Watcher = Watcher

-----------------------------
-- [[ Post Inits ]]
-----------------------------

if PEARL.CONFIG.ANNS.BURNTUP or PEARL.CONFIG.DISCORD.ENABLED then
    AddComponentPostInit("burnable", function(self, inst)
        if not (self and inst and inst:IsValid() and inst:HasTag("structure") and TheNet:GetIsMasterSimulation()) then
            return
        end

        -- Announce when a structure burnts up
        inst:ListenForEvent("burntup", onburntup)
    end)
end

if PEARL.CONFIG.DISCORD.ENABLED then
    for k, _ in pairs(PEARL.PREFABS.ACTIVATABLE) do
        if k then
            AddPrefabPostInit(k, function(inst)
                inst:ListenForEvent("onactivated", onactivated)
            end)
        end
    end
end

--- @TODO v2.1
-- Note: try to use events instead of ACTIONS
-- AddPlayerPostInit(function(inst)
--     if not TheWorld.ismastersim then
--         return
--     end

    -- if PEARL.CONFIG.GRIEF_PROTECTION and PEARL.Penalizer then
    --     inst:AddComponent("griefness")
    -- end
    -- inst:ListenForEvent("buildstructure", onbuildstructure)

    -- By default the penalty should be 1. However, if the target is a base structure
    -- and the doer is not the builder of it, then BASE_MULT should be applied.
    -- Watcher:WatchPlayerFor(
    --     inst, "finishedwork",
    --     PEARL.CONFIG.ANNS.HAMMER, PEARL.EMOTES.GAME.HAMMER,
    --     PEARL.CONSTS.GRIEF_ACTS.HAMMER, EventHandlers.playeronfinishedwork
    -- )

    -- Watcher:WatchPlayerFor(
    --     inst, "sub_onstartedfire",
    --     PEARL.CONFIG.ANNS.LIGHT, PEARL.EMOTES.GAME.TORCH,
    --     PEARL.CONSTS.GRIEF_ACTS.LIGHT, EventHandlers.playeronignite
    -- )
-- end)
