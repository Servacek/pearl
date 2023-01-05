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

local Inventory = require("components/inventory")

-----------------------------------
-- [[ Contants ]]
-----------------------------------

-- Suspicious Inventory Detector
local MAX_SUSPICION = 3

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

function Inventory:GetSorted()
    local length = 0
    local result = {}
    self:ForEachItem(function(item)
        if not result[item.prefab] then
            length = length + 1
        end

        result[item.prefab] = (result[item.prefab] or 0) + PEARL.GetStackSize(item)
    end)

    return result, length
end

function Inventory:GetItemCount(prefab)
    local count = 0

    for _, item in pairs(self.itemslots) do
        if item.prefab == prefab then
            count = count + PEARL.GetStackSize(item)
        end
    end

    for _, item in pairs(self.equipslots) do
        if item.prefab == prefab then
            count = count + PEARL.GetStackSize(item)
        end
    end

    if self.activeitem and self.activeitem.prefab == prefab then
        count = count + PEARL.GetStackSize(self.activeitem)
    end

    local overflow = self:GetOverflowContainer()
    if overflow ~= nil then
        for _, item in pairs(overflow:FindItems(function(item)
            return item.prefab == prefab
        end)) do
            count = count + PEARL.GetStackSize(item)
        end
    end

    return count
end

--- @TODO Tags:
--[[
    "gem"
    "rangedweapon"
    "rangelighter"
    "weapon"
--]]
function Inventory:CalcSuspicioness()
    local suspicioness = 0
    for _, item in ipairs(self:ReferenceAllItems()) do
        if suspicioness >= MAX_SUSPICION then
            break
        end

        local rarity = item.components.inventoryitem:GetTotalRarity()
        -- print("\tRARITY:", rarity)
        suspicioness = suspicioness + rarity
        -- print("\tTOTAL:", suspicioness)
        -- print("-----------------")
    end

    --PEARL.debug("SUSPICION:", suspicioness)
    return suspicioness / MAX_SUSPICION
end

-----------------------------------
-- [[ Low-Level Handlers ]]
-----------------------------------
-- This doesn't work for containers
-- PEARL.AddClassFunctionPreCall("GiveItem", function(self, item)
--     PEARL.debug(string.format("GiveItem[%s]<Holder: %s>",
--         tostring(item), tostring(item.components.inventoryitem.owner)
--     ))
-- end, Inventory)

-- PEARL.AddClassFunctionPreCall("RemoveItem", function(self, item)
--     -- We only care if the active item is places somewhere outside the inventory
--     -- if self.activeitem ~= item then
--     --     return
--     -- end

--     PEARL.debug(string.format("RemoveItem[%s]<Holder: %s>",
--         tostring(item), tostring(item.components.inventoryitem.owner)
--     ))
-- end, Inventory)
