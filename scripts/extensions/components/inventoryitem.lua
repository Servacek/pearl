
local PEARL = PEARL
local AllRecipes = AllRecipes

--- @class InventoryItem
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
    if self:GetRarityPercent() > 0 then
        return true
    end

    if self.inst.components.container then
        if self.inst.components.container:FindItem(function(item)
            item.components.inventoryitem:IsRare()
        end) then
            return true
        end
    end

    return false
end

--- @TODO add container support
function InventoryItem:IsVeryRare()
    if self:GetRarityPercent() >= 1 then
        return true
    end

    if self.inst.components.container then
        if self.inst.components.container:FindItem(function(item)
            item.components.inventoryitem:IsVeryRare()
        end) then
            return true
        end
    end

    return false
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

-------- Owner History

function InventoryItem:GetLastPlayerOwner()
    return self._last_player_owner
end

function InventoryItem:IsLastOwner(owner)
    return self._last_owner == owner
end

function InventoryItem:IsLastPlayerOwner(owner)
    return self._last_player_owner == owner
end

function InventoryItem:SetLastPlayerOwner(owner)
    self._last_player_owner = owner
end

function InventoryItem:SetLastOwner(owner)
    --- @deprecated
    -- This is also a possible solution but it doesn't handle many edge cases
    --holder:PushEvent("became_holder", self.inst)

    self._holder = owner
end

function InventoryItem:IsLastContainer(container)
    return self._last_container
end

function InventoryItem:SetLastContainer(container)
    self._last_container = container
end

--------------------------------
-- [[ Function Pre Inits ]]
--------------------------------

-- PEARL.AddClassFunctionPreCall("SetOwner", function(self, owner)
--     -- PEARL.debug(string.format("SetOwner[%s]<Owner: %s>",
--     --     self.inst.prefab, tostring(owner)
--     -- ))

--     self:SetHolder(owner)
-- end, InventoryItem)


PEARL.AddClassFunctionPreCall("ClearOwner", function(self)
    -- PEARL.debug(string.format("ClearOwner[%s]", self.inst.prefab))

    if self.owner and self.owner:HasTag("player") then
        self:SetLastPlayerOwner(self.owner)
    end

    self:SetLastOwner(self.owner)
end, InventoryItem)
