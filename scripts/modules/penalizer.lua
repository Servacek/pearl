--- @TODO for v2.1
--[[ TODO:
    - Create some flexible penalization system.
    - Reduce duplication creating some api for adding new
      action handlers.

    - Add announcement about deploying hostile entities near spawn.
    - Add announcement about spawning a new player for the first time.
--]]

local PEARL = PEARL
local Class = Class
local TheNet = TheNet
local table = table

---------------------------

local Penalizer = Class()

---------------------------

function Penalizer:SendWarning(doer)
    if not doer or not doer.userid then return end

    if doer.components.griefer then
        doer.components.griefer:DoWarning()

        PEARL.Logger:LogString(
            STRINGS.PEARL.LOGS.WARNED:format(doer:GetDisplayName())
        )
    end
end

function Penalizer:DoGracefullBan(doer)
    if doer.components and doer.components.griefer then
        PEARL.Scheduler:ExecuteInTime(2, function()
            doer.components.griefer:PrepareForBan()
        end)
    end

    PEARL.Scheduler:ExecuteInTime(5, function()
        PEARL.info("Banning player", doer:GetDisplayName(), "for being a griefer.")
        TheNet:BanForTime(doer.userid, PEARL.CONSTS.GRIEFER_BAN_TIME)
    end)
end

---------------------------
-- [[ Handlers ]]
---------------------------

function Penalizer:AddEventHandler(event, source, data, handlerfn)
    source:ListenForEvent(event, function(...)
        local success, response, penalty, silent = PEARL.SafeRun(handlerfn,
            data, ...
        )
        if not success then return end

        -- Log the response of the handler
        if response then
            PEARL.Logger:LogString(response, data.icon)

            if not silent and not data.silent and penalty then
                PEARL.Announce(response, data.icon)
            end
        end

        -- Apply the penalty
        if penalty and source and source.components.griefer then
            source.components.griefer:DoDelta(penalty)
            self:Check(source)
        end

        -- In pre-action mode return the result of the handler
        -- so we can for example stop the action from executing.
        -- if pre and handler_result ~= nil then
        --     return handler_result
        -- end
    end)
end

-- TODO: Create some system in this mess...
function Penalizer:HandleAction(act, id, data, handlerfn, ...)
    local entities

    if data.player_act ~= false and (act.doer and not act.doer:HasTag("player")) then
        return
    end

    if data.radius and data.radius > 0 then
        if act.target then
            entities = act.target:GetEntitiesNear(data.radius, nil,
                PEARL.CONSTS.ENT_CANT_HAVE_TAGS, PEARL.CONSTS.ENT_ONEOF_TAGS
            )
        else
            local pos = act:GetActionPoint()
            entities = TheSim:FindEntities(pos.x, pos.y, pos.z,
                data.radius, nil, PEARL.CONSTS.ENT_CANT_HAVE_TAGS,
                PEARL.CONSTS.ENT_ONEOF_TAGS
            )
        end
    end

    local success, response, penalty, silent = PEARL.SafeRun(handlerfn,
        data, act.doer, act.target, (act.invobject or act.recipe), entities, ...
    )

    if not success then return end

    -- Log the response of the handler
    if response then
        PEARL.Logger:LogString(response, data.icon)

        print(PEARL.CONFIG.ANNS[id], id, silent, penalty)
        if not silent and PEARL.CONFIG.ANNS[id] and penalty then
            PEARL.Announce(response, data.icon)
        end
    end

    -- Apply the penalty
    print(act.doer)
    if penalty and act.doer and act.doer.components.griefer then
        act.doer.components.griefer:DoDelta(penalty)
        self:Check(act.doer)
    end

    -- In pre-action mode return the result of the handler
    -- so we can for example stop the action from executing.
    -- if pre and handler_result ~= nil then
    --     return handler_result
    -- end
end

function Penalizer:RegisterActionHandler(action, data, handlerfn)
    local _default_handler_fn = action.fn
    action.fn = function(act, ...)
        local success = _default_handler_fn(act, ...)
        if success and act ~= nil and handlerfn then
            self:HandleAction(act, action.id, data, handlerfn, ...)
        end

        return success
    end
end

-- function Penalizer:HandleGrieferAction(act, doer, ...)
--     if act.handlerfn_args then
--         act.handlerfn(act.handlerfn_args, act, doer, ...)
--     else
--         act.handlerfn(act, doer, ...)
--     end
--     self:Check(doer)
-- end

-- function Penalizer:SetHandlerForGrieferAction(act, handlerfn, ...)
--     act.handlerfn = handlerfn
--     act.handlerfn_args = ...
-- end

-- function Penalizer:SetPointsCaclFnForGrieferAction(act, pointsfn, ...)
--     act.pointsfn = pointsfn
--     act.pointsfn_args = ...
-- end

function Penalizer:OnGriefnessChange(doer)
    if not doer then return end
    if not doer.components or not doer.components.griefer then return end

    -- DEBUG
    -- We can't kick admins, so they are skipped
    --if SUB.IsAdminUserid(doer.userid) then return end

    PEARL.debug("Penalizer", "OnGriefnessChange")
    if doer.components.griefer:ShouldBeBanned() then
        self:DoGracefullBan(doer)
    elseif doer.components.griefer:ShouldBeWarned() then
        self:SendWarning(doer)
    end
end

---------------------------

-- TODO: All burnable structures should have a propagator component
-- which stores a propagaterange value. Replace the FIRE_RADIUS
-- constant with this value, to add more flexibility.
-- Penalizer:RegisterActionHandler(ACTIONS.LIGHT, {
--     penalty = 2.75,
--     penalty_per_ent = 1,
--     icon = SUB.EMOTES.GAME.TORCH,
--     radius = SUB.CONSTS.FIRE_RADIUS,
-- }, function(data, doer, target, invobject, entities)
--     if not (doer and target and type(entities) == "table") then
--         return
--     end

--     -- Calculate the points
--     local at_base = SUB.IsBase(entities)
--     local penalty = (#entities * data.penalty_per_ent) + (
--         (target:IsBaseStructure() or target:IsResourcePlant())
--         and data.penalty or data.penalty_per_ent
--     ) * (at_base and BASE_PENALTY_MULT or 1)

--     local message
--     if #entities > 0 then
--         message = SUB.STRINGS.IGNITE_NEAR:format(
--             doer:GetDisplayName(), target:GetDisplayName(), SUB.FormatSortedPrefabs(entities, target)
--         )
--     else
--         message = SUB.STRINGS.IGNITE:format(
--             doer:GetDisplayName(), target:GetDisplayName()
--         )
--     end

--     -- If the action was done near base or the farms
--     -- We want to schedule an extinguish task
--     -- so the fires will not destroy the base.
--     if at_base or #entities >= 6 then
--         doer.components.griefer:StartExtTask(target:GetPosition())
--     end

--     SUB.debug("Penalty for action:", penalty)
--     return message, penalty, not (target:IsBaseStructure() or at_base or #entities > 5)
-- end)

-- Penalizer:RegisterActionHandler(ACTIONS.HAMMER, {
--     penalty = 2,
--     icon = SUB.EMOTES.GAME.HAMMER,
-- }, function(data, doer, target)
--     if not doer or not target then
--         return
--     end

--     return SUB.STRINGS.DESTROY:format(
--         doer:GetDisplayName(), target:GetDisplayName()
--     )
-- end)

-- Penalizer:RegisterActionHandler(ACTIONS.EAT, {
--     icon = SUB.EMOTES.GAME.FAKE_TEETH,
-- }, function(data, doer, target)
--     if not doer or not target then
--         return
--     end

--     return SUB.STRINGS.EAT:format(
--         doer:GetDisplayName(), target:GetDisplayName()
--     ), SUB.PREFABS.FOOD[target.prefab]
-- end)

-- Penalizer:RegisterActionHandler(ACTIONS.DEPLOY, {
--     penalty = 9,
--     icon = SUB.EMOTES.GAME.EYEBALL,
-- }, function(data, doer, target)
--     if not doer or not target or not doer:HasTag("player") then return end
--     if not target:HasOneOfTags(SUB.CONSTS.DANGER_ONOF_TAGS) then return end

--     local x, y, z = target.Transform:GetWorldPosition()
--     if TheSim:CountEntities(
--         x, y, z, PORTAL_ZONE_RADIUS, nil, nil, {"multiplayer_portal"}
--     ) > 0 then
--         return SUB.STRINGS.DEPLOY_NEAR:format(
--             doer:GetDisplayName(), target:GetDisplayName()
--         )
--     end
-- end)
-- Penalizer:SetHandlerForGrieferAction(SUB.GRIEFER_ACTIONS.BUILD_NEAR,
--     function(act, doer, target, entities)
--         -- TODO
--     end
-- )

-- Penalizer:SetHandlerForGrieferAction(SUB.GRIEFER_ACTIONS.DEPLOY_NEAR,
--     function(act, doer, target)
--         -- TODO
--     end
-- )

-------------------------------

PEARL.Penalizer = Penalizer()
