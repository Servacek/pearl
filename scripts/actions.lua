-- TODO: v2.1
-- Convert low level ACTIONS to events
-- used for actions that do not push their own event

-- Note: For better compatibility with other mods and updates
-- we should prefix our exclusive event names with 'sub_'

-- Note: Also at some point we can use event "performaction", { action = bufferedaction }


local PEARL = PEARL

-----------------------------------------

local function RegisterActionHandler(action, handler, ...)
    local _default_handler_fn = action.fn
    action.fn = function(act, ...)
        local success = _default_handler_fn(act, ...)

        if success and act ~= nil and handler ~= nil then
            PEARL.SafeRun(handler,
                act.doer, act.target, (act.invobject or act.recipe), act:GetActionPoint(), ...
            )
        end

        return success
    end
end

-----------------------------------------

local function onextinguish(doer, target)
    PEARL.debug("EXTINGUISH!")
    if doer and target then
        doer:PushEvent("sub_extinguish", target)
    end
end

local function onlight(doer, target)
    if not (doer and doer:HasTag("player") and target) then
        return
    end

    local near = target:GetPropagableEntities(
        PEARL.CONSTS.ENT_MUST_HAVE_TAGS, PEARL.CONSTS.ENT_CANTHAVE_TAGS, PEARL.CONSTS.ENT_ONEOF_TAGS
    )
    doer:PushEvent("sub_onstartedfire", {target = target, near = near})
end

-----------------------------------------

RegisterActionHandler(ACTIONS.EXTINGUISH, onextinguish)

RegisterActionHandler(ACTIONS.POUR_WATER, onextinguish)

RegisterActionHandler(ACTIONS.LIGHT, onlight)
