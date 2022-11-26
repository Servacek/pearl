
local PEARL = PEARL
local AllRecipes = AllRecipes

local InventoryItem = require("components/inventoryitem")

--------------------------------
-- [[ Contants ]]
--------------------------------

local ITEM_RARITY_MAX   = 3

local ITEM_RARITY       = {
    RENEWABLE           = ITEM_RARITY_MAX / 320,  -- max stacks of renewable material
    BUILT_SELF          = ITEM_RARITY_MAX / 75,
    BUILT_OTHER         = ITEM_RARITY_MAX / 30,   -- max built items by someone else
    PER_FOOD_POINT      = (ITEM_RARITY_MAX / 25) / 45,
    PER_FOOD_POINT_RAW  = (ITEM_RARITY_MAX / 75) / 45,
    GEM                 = ITEM_RARITY_MAX / 9,
    FUEL                = ITEM_RARITY_MAX / 200,
    SKIN_MULT           = 1.25,
    DEFAULT             = ITEM_RARITY_MAX / 240,  -- max stacks of a non-renewable material
}

--------------------------------
-- [[ Member Functions ]]
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

function InventoryItem:GetTotalRarity()
    local rarity = 0

    local stacksize = self:GetStackSize()

    -- Renewable Resources (eg. grass, twigs)
    if self.inst:HasTag("renewable") then
        print("RENEWABLE ("..self.inst.prefab.." x"..tostring(stacksize).."):")
        return rarity + (ITEM_RARITY.RENEWABLE * stacksize)
    end

    local recipe = AllRecipes[self.inst.prefab]
    if recipe ~= nil then
        for _, ingredient in ipairs(recipe.ingredients) do
            if PEARL.PREFABS.RARE_ITEMS[ingredient.type] and PEARL.PREFABS.RARE_ITEMS[ingredient.type] > 0 then
                rarity = rarity + (
                    ITEM_RARITY_MAX * PEARL.PREFABS.RARE_ITEMS[ingredient.type]
                ) * ingredient.amount

                print("RARE INGEREDIENT ("..ingredient.type.." x"..tostring(ingredient.amount)..")", rarity)
            end
        end
    elseif self:IsVeryRare() then
        print("VERY RARE ("..self.inst.prefab.." x"..tostring(stacksize).."):")

        -- Full rarity for very rare items
        return ITEM_RARITY_MAX
    end

    --local stacksize = self:GetStackSize()

    -- Gems
    if self.inst:HasTag("gem") then
        print("GEM ("..self.inst.prefab.." x"..tostring(stacksize).."):")
        return rarity + (ITEM_RARITY.GEM * stacksize)
    end

    -- Tools/Weapons/Armor/Hats
    if not self.inst.components.stackable then--and self.inst:HasBuilder() then
        -- If this item does not have durability (e. g. Walking Cane) we count it as
        -- if it had 100%.
        local finituse_percent = self.inst.components.finiteuses and self.inst.components.finiteuses:GetPercent() or 1

        if self.inst:IsBuildBy(self.inst.userid) then
            print("TOOL OWN ("..self.inst.prefab.." x"..tostring(stacksize).." "..math.floor(finituse_percent * 100).."%):")
            return rarity + (ITEM_RARITY.BUILT_SELF * finituse_percent)
        end

        local mult = self.skinname ~= nil and ITEM_RARITY.SKIN_MULT or 1
        print("TOOL OWN ("..self.inst.prefab.." x"..tostring(stacksize).." "..math.floor(finituse_percent * 100).."%):")
        return rarity + (ITEM_RARITY.BUILT_OTHER * finituse_percent) * mult
    end

    if self.inst.components.fuel then
        print("FUEL ("..self.inst.prefab.." x"..tostring(stacksize).."):")
        local fuel_val = self.inst.components.fuel.fuelvalue
        return rarity + (ITEM_RARITY.FUEL * (fuel_val / TUNING.SEG_TIME)) * stacksize
    end

    -- Player Food
    if self.inst.components.edible and self.inst.components.edible:FulfillsDiet(FOODGROUP.OMNI) then
        local food_val = self.inst.components.edible:GetFoodValue()
        if food_val > 0 then
            local mult = self.inst:HasTag("preparedfood") and ITEM_RARITY.PER_FOOD_POINT or ITEM_RARITY.PER_FOOD_POINT_RAW

            print("EDIBLE ("..self.inst.prefab.." x"..tostring(stacksize)..")")

            return rarity + (food_val * mult) * stacksize
        end
    end

    print("DEFAULT ("..self.inst.prefab.." x"..tostring(stacksize).."):")
    return rarity + (ITEM_RARITY.DEFAULT * stacksize)
end

function InventoryItem:GetDisplayNameWithCount()
    return STRINGS.PEARL.LOGS.ITEM:format(self:GetStackSize(), self.inst:GetDisplayName())
end

--------------------------------
-- [[ Function Post Inits ]]
--------------------------------

-- PEARL.AddClassFunctionPreCall("OnPutInInventory", function(self, new_owner)
--     PEARL.debug(string.format("OnPutInInventory[%s]<HolderOld: %s | HolderNew: %s>",
--         inst.prefab, tostring(self.prev_owner), tostring(new_owner)
--     ))
-- end, InventoryItem)

PEARL.AddClassFunctionPreCall("ClearOwner", function(self)
    -- Make sure we only store players as previous owners.
    if not self.owner then
        return
    end

    if self.owner:HasTag("player") then
        self.pholder = self.owner
    else
        self.pcontainer = self.owner
    end
end, InventoryItem)

--------------------------------
-- [[ Function Post Calls ]]
-------------------------------

-- PEARL.AddClassFunctionPreCall("OnPutInInventory", function(self)
--     PEARL.debug(string.format("OnPutInInventory[%s]<Holder: %s>",
--         self.inst.prefab, tostring(self.owner)
--     ))
-- end, InventoryItem)
