--[[
    Makes player icons globaly visible for all players.
--]]

local PEARL = PEARL

--------------------------------
-- [[ Constants ]]
--------------------------------

local REQUIRED_AGE = 20
local REQUIRED_AGE_PERCENT = 0.3

--------------------------------
-- [[ Implementation ]]
--------------------------------

AddPlayerPostInit(function(inst)
    if not inst or not inst.components or not inst.components.maprevealable then
        return
    end

    -- Cleaning up is handled by the component itself
    inst.components.maprevealable:AddRevealSource(inst, "compatriot")
end)

PEARL.AddGlobalFunctionPreCall("NotifyPlayerProgress", function(name, value, player)
    if name ~= "days" or not player or player:HasTag("compatriot") or not player.components.age then
        return
    end

    local age_percent = player.components.age:GetPercent()
    if value >= REQUIRED_AGE or age_percent >= REQUIRED_AGE_PERCENT then
        player:AddTag("compatriot")
    end
end)
