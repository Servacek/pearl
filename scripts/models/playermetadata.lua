--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class PlayerMetadata
local PlayerMetadata = Class(function(self, userid, netid)
    --- @type number
    self._age = -1
    --- @type string
    self._prefab = ""
    --- @type string
    self._userid = userid
    self._netid = netid
    --- @type string
    self._name = nil

    --- @type table
    --- @TODO: Separate equip slots from main slots
    --- Also separate backpacks.
    self._inventory = {}
end)

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function PlayerMetadata:SetAge(age)
    self._age = age
end

function PlayerMetadata:SetPrefab(prefab)
    self._prefab = prefab
end

function PlayerMetadata:SetName(name)
    self._name = name
end

function PlayerMetadata:SetNetID(netid)
    self._netid = netid
end

function PlayerMetadata:AddInventoryItem(item)
    if not (item and item.prefab) then
        return
    end

    if not self._inventory[item.prefab] then
        self._inventory[item.prefab] = 0
    end

    self._inventory[item.prefab] = self._inventory[item.prefab] + PEARL.GetStackSize(item)

    -- for bundles and gifts
    if item.components and item.components.unwrappable and item.components.unwrappable.itemdata then
        for _, v in pairs(item.components.unwrappable.itemdata) do
            self:AddInventoryItem(v)
        end
    end
end

--- @param inventory Inventory
function PlayerMetadata:SetInventory(inventory)
    inventory:ForEachItem(function(...)
        self:AddInventoryItem(...)
    end)
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function PlayerMetadata:GetInventory()
    return self._inventory
end

function PlayerMetadata:GetPrefab()
    return self._prefab
end

function PlayerMetadata:GetAge()
    return self._age
end

function PlayerMetadata:GetName()
    return self._name
end

function PlayerMetadata:GetAge()
    return (self._age or -1) + 1
end

function PlayerMetadata:GetUserID()
    return self._userid
end

function PlayerMetadata:GetNetID()
    return self._netid
end

-------------------------------------
-- [[ Loaders ]]
-------------------------------------

function PlayerMetadata:Load(data)
    self._age = data.age
    self._prefab = data.prefab

    -- we also want to check walter's woby
    if data.data.woby and data.data.woby.data and data.data.woby.data.container
    and data.data.woby.data.container.items then
        for _, v in pairs(data.data.woby.data.container.items) do
            self:AddInventoryItem(v)
        end
    end

    local inventory = data.data and data.data.inventory
    if inventory then
        for _, item in pairs(inventory.items) do
            self:AddInventoryItem(item)

            -- for bundles
            if item.data and item.data.unwrappable and item.data.unwrappable.items then
                for _, v in pairs(item.data.unwrappable.items) do
                    self:AddInventoryItem(v)
                end
            end
        end
    end

    --- [[ Equip slots ]] ---
    local equip_slots = inventory.equip
    if equip_slots then
        if equip_slots.body then
            self:AddInventoryItem(equip_slots.body)

            -- In case of a backpack
            if equip_slots.body.data and equip_slots.body.data.container and equip_slots.body.data.container.items then
                for _, item in pairs(equip_slots.body.data.container.items) do
                    self:AddInventoryItem(item)

                    -- for bundles inside the backpack
                    if item.data and item.data.unwrappable and item.data.unwrappable.items then
                        for _, v in pairs(item.data.unwrappable.items) do
                            self:AddInventoryItem(v)
                        end
                    end
                end
            end
        end

        if equip_slots.hands then
            self:AddInventoryItem(equip_slots.hands)
        end

        if equip_slots.head then
            self:AddInventoryItem(equip_slots.head)
        end
    end
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return PlayerMetadata
