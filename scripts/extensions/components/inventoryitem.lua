--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local PEARL = PEARL
local AllRecipes = AllRecipes

--- @class InventoryItem
local InventoryItem = require("components/inventoryitem")

--------------------------------
-- [[ Contants ]]
--------------------------------

local TOTAL_RARITY          = 1
local MAX_RARITY_PER_ITEM   = TOTAL_RARITY / 4

local DEFAULT_RARITY        = 1 / 300

local ITEM_RARITY       = {
    PER_RARITY_PERCENT  = TOTAL_RARITY,
    VERY_RARE           = TOTAL_RARITY / 2,
    RENEWABLE           = TOTAL_RARITY / 300,  -- max stacks of renewable material
    BUILT_SELF          = TOTAL_RARITY / 50,
    BUILT_OTHER         = TOTAL_RARITY / 20,   -- max built items by someone else
    PER_FOOD_POINT      = TOTAL_RARITY / 340,
    PER_FOOD_POINT_RAW  = TOTAL_RARITY / 360,
    BLUEPRINT           = TOTAL_RARITY / 3,
    BLUEPRINT_RARE      = TOTAL_RARITY / 2,
    GEM                 = TOTAL_RARITY / 5,
    PER_FUEL_POINT      = TOTAL_RARITY / 500,    -- Per fuel point
    SKIN_MULT           = 1.15,
    DEFAULT             = TOTAL_RARITY / 300,  -- max stacks of a non-renewable material
}

--------------------------------
-- [[ Getters ]]
--------------------------------

function InventoryItem:GetRarityPercent()
    return PEARL.PREFABS.RARE_ITEMS[self.inst.prefab] or 0
end

function InventoryItem:IsRare()
    return self:GetRarityPercent() > 0
end

function InventoryItem:IsVeryRare()
    return self:GetRarityPercent() >= 1
end

function InventoryItem:GetStackSize()
    return self.inst.components.stackable and self.inst.components.stackable:StackSize() or 1
end

function InventoryItem:GetTotalPredictedWeight(weights)
    local stacksize = self:GetStackSize()
    local prefab = self.inst.prefab
    local weight = weights[prefab] or DEFAULT_RARITY
    local rarity = stacksize * weight

    local recipe = AllRecipes[self.inst.prefab]
    if recipe ~= nil then
        for _, ingredient in ipairs(recipe.ingredients) do
            if PEARL.PREFABS.RARE_ITEMS[ingredient.type] and PEARL.PREFABS.RARE_ITEMS[ingredient.type] > 0 then
                rarity = rarity + (weights[ingredient.type] or DEFAULT_RARITY) * ingredient.amount
            end
        end
    end

    if not self.inst.components.stackable then
        -- If this item does not have durability (e. g. Walking Cane) we count it as
        -- if it had 100%.
        local finituse_percent = self.inst.components.finiteuses and self.inst.components.finiteuses:GetPercent() or 1

        local mult = self.skinname ~= nil and ITEM_RARITY.SKIN_MULT or 1
        rarity =  rarity * mult * finituse_percent
    end

    -- Player Food
    if self.inst.components.edible and self.inst.components.edible:FulfillsDiet(FOODGROUP.OMNI) then
        local food_val = self.inst.components.edible:GetFoodValue()
        if food_val > 0 then
            local mult = self.inst:HasTag("preparedfood") and ITEM_RARITY.PER_FOOD_POINT or ITEM_RARITY.PER_FOOD_POINT_RAW

            rarity = rarity + (food_val * mult)
        end
    end

    return rarity
end

-- function InventoryItem:GetTotalRarity()
--     local rarity = 0

--     local stacksize = self:GetStackSize()
--     local rarity_percent = self:GetRarityPercent() or 0

--     -- Renewable Resources (eg. grass, twigs)
--     if self.inst:HasTag("renewable") then
--         --print("RENEWABLE ("..self.inst.prefab.." x"..tostring(stacksize).."):")
--         return rarity + (ITEM_RARITY.RENEWABLE * stacksize)
--     end

--     if self.inst.prefab == "blueprint" then
--         if self.inst.is_rare then
--             return rarity + (ITEM_RARITY.BLUEPRINT_RARE * stacksize)
--         end

--         return rarity + (ITEM_RARITY.BLUEPRINT * stacksize)
--     end

--     if rarity_percent and rarity_percent > 0 then
--         -- Very rare items
--         if rarity_percent >= 1 then
--             return rarity + ITEM_RARITY.VERY_RARE * stacksize
--         end

--         return rarity + (ITEM_RARITY.PER_RARITY_PERCENT * rarity_percent) * (stacksize / 2)
--     end

    -- local recipe = AllRecipes[self.inst.prefab]
    -- if recipe ~= nil then
    --     for _, ingredient in ipairs(recipe.ingredients) do
    --         if PEARL.PREFABS.RARE_ITEMS[ingredient.type] and PEARL.PREFABS.RARE_ITEMS[ingredient.type] > 0 then
    --             rarity = rarity + (
    --                 MAX_RARITY_PER_ITEM * PEARL.PREFABS.RARE_ITEMS[ingredient.type]
    --             ) * ingredient.amount

    --             --print("RARE INGEREDIENT ("..ingredient.type.." x"..tostring(ingredient.amount)..")", rarity)
    --         end
    --     end
    -- end

--     -- Gems
--     if self.inst:HasTag("gem") then
--         --print("GEM ("..self.inst.prefab.." x"..tostring(stacksize).."):")
--         return rarity + (ITEM_RARITY.GEM * stacksize)
--     end

--     -- Tools/Weapons/Armor/Hats
--     --- @TODO: Think about a way how to store builders of items as well.
--     if not self.inst.components.stackable then -- self.inst:HasBuilder() then
--         -- If this item does not have durability (e. g. Walking Cane) we count it as
--         -- if it had 100%.
--         local finituse_percent = self.inst.components.finiteuses and self.inst.components.finiteuses:GetPercent() or 1

--         -- if self.inst:IsBuildBy(self.inst.userid) then
--         --     --print("TOOL OWN ("..self.inst.prefab.." x"..tostring(stacksize).." "..math.floor(finituse_percent * 100).."%):")
--         --     return rarity + (ITEM_RARITY.BUILT_SELF * finituse_percent)
--         -- end

--         local mult = self.skinname ~= nil and ITEM_RARITY.SKIN_MULT or 1
--         --print("TOOL OWN ("..self.inst.prefab.." x"..tostring(stacksize).." "..math.floor(finituse_percent * 100).."%):")
--         return rarity + (ITEM_RARITY.BUILT_OTHER * finituse_percent) * mult
--     end

--     if self.inst.components.fuel then
--         --print("FUEL ("..self.inst.prefab.." x"..tostring(stacksize).."):")
--         local fuel_val = self.inst.components.fuel.fuelvalue
--         return rarity + (ITEM_RARITY.PER_FUEL_POINT * (fuel_val / TUNING.SEG_TIME)) * stacksize
--     end

--     -- Player Food
--     if self.inst.components.edible and self.inst.components.edible:FulfillsDiet(FOODGROUP.OMNI) then
--         local food_val = self.inst.components.edible:GetFoodValue()
--         if food_val > 0 then
--             local mult = self.inst:HasTag("preparedfood") and ITEM_RARITY.PER_FOOD_POINT or ITEM_RARITY.PER_FOOD_POINT_RAW

--             --print("EDIBLE ("..self.inst.prefab.." x"..tostring(stacksize)..")")

--             return rarity + (food_val * mult) * stacksize
--         end
--     end

--     --print("DEFAULT ("..self.inst.prefab.." x"..tostring(stacksize).."):")
--     return rarity + (ITEM_RARITY.DEFAULT * stacksize)
-- end

function InventoryItem:GetDisplayNameWithCount()
    return STRINGS.PEARL.LOGS.ITEM:format(self:GetStackSize(), self.inst:GetDisplayName())
end

function InventoryItem:GetLastPlayerOwner()
    return self._last_player_owner
end

function InventoryItem:IsLastOwner(owner)
    return self._last_owner == owner
end

function InventoryItem:IsLastPlayerOwner(owner)
    return self._last_player_owner == owner
end

function InventoryItem:IsLastPicker(picker)
    return self._last_picker == picker
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function InventoryItem:SetLastPlayerOwner(owner)
    self._last_player_owner = owner
end

function InventoryItem:SetLastOwner(owner)
    self._last_owner = owner
end

function InventoryItem:SetLastPicker(picker)
    self._last_picker = picker
end

--------------------------------
-- [[ Function Pre Calls ]]
--------------------------------

PEARL.AddClassFunctionPreCall("ClearOwner", function(self)
    if self.owner and self.owner:HasTag("player") then
        self:SetLastPlayerOwner(self.owner)
    end

    self:SetLastOwner(self.owner)
end, InventoryItem)
