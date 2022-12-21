local PEARL = PEARL

local EventHandlers = {}

local function structcheckfn(k, v)
    return v and v:IsBaseStructure()
end

----------------------------------------

function EventHandlers.playeronfinishedwork(doer, data, act)
    if not (doer and data and data.target) then
        return
    end

    local str
    local announce
    local penalty = act.penalty
    if data.target:HasBuilder() then
        str = STRINGS.PEARL.LOGS.OWNER:format(
            STRINGS.PEARL.ACTIONS.HAMMER:format(
                doer:GetDisplayName(), data.target:GetDisplayName()
            ),
            data.target:GetBuilderName()
        )

        if not data.target:IsBuildBy(doer.userid) then
            announce = true
            penalty = penalty * act.base_mult
        end
    else
        str = STRINGS.PEARL.ACTIONS.HAMMER:format(
            doer:GetDisplayName(), data.target:GetDisplayName()
        )
    end

    PEARL.debug("ONFINISHED WORK", penalty, str, announce)
    return penalty, str, announce
end

function EventHandlers.playeronignite(doer, data, act)
    if not (doer and data and data.target) then
        return
    end

    local str
    local at_base = PEARL.IsBase(data.near)
    local penalty = ((data.target:IsBaseStructure() or data.target:IsResourcePlant())
        and act.penalty or act.penalty_per_ent
    ) + (data.near and #data.near or 0 * act.penalty_per_ent)

    if at_base then
        penalty = penalty * (act.base_mult or 1)
    end

    --- @TODO: Ignore target
    local near_str = PEARL.BuildFancyStringForEntities(data.near, data.target)
    if near_str then
        str = subfmt(STRINGS.PEARL.ACTIONS.IGNITE.NEAR, {
            doer = doer:GetDisplayName(),
            target = data.target:ToStringSupportStacks(),
            near = near_str,
        })
    else
        str = subfmt(STRINGS.PEARL.ACTIONS.IGNITE.GENERIC, {
            doer = doer:GetDisplayName(),
            target = data.target:ToStringSupportStacks()
        })
    end

    PEARL.debug("ONLIGHT", penalty, str, data.target:IsBaseStructure() or at_base or #data.near > 5)
    return penalty, str, data.target:IsBaseStructure() or at_base or #data.near > 5
end

return EventHandlers
