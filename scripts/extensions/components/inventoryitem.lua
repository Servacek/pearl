--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local PEARL = PEARL

--- @class InventoryItem
local InventoryItem = require("components/inventoryitem")

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
