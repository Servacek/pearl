--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class PlayerMetadata
local PlayerMetadata = Class(function(self, userid)
    assert(PEARL.IsKleiIDValid(userid) == true, "Invalid Klei ID provided!")

    --- @type integer
    self._age = -1
    --- @type string
    self._prefab = ""
    --- @type string
    self._userid = userid
    self._netid = TheNet:GetNetIdForUser(userid)
    --- @type string
    self._name = nil

    --- @type table
    --- @TODO: Separate equip slots from main slots
    --- Also separate backpacks.
    self._inventory = {}

    --- @type table
    self._session_data = nil

    --- @type boolean
    self._loaded = false
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

function PlayerMetadata:SetSessionData(data)
    self._session_data = data
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

--- @return EntityScript?
function PlayerMetadata:GetInstance()
    PEARL.debug("PlayerMetadata:GetInstance")

    local userid = self:GetUserID()
    local player = LookupPlayerInstByUserID(userid)
    if not player then -- Player is offline, lets simulate his instance.
        -- Load the data right from the start, so we know the prefab.
        if not self:IsLoaded() then
            if not self:LoadPlayerData() then
                return -- Failed to load the player data, we cant continue
            end
        end

        -- We are going to make a non-networked player entity, so prevent it
        -- from adding any network.
        local prefab = self:GetPrefab()
        player = SpawnPrefab(prefab ~= "" and prefab or "player_classified")

        if player then
            -- Make sure we are not in the AllPlayers table.
            table.removearrayvalue(AllPlayers, player)

            player.persists = false
            player.userid = userid
            player.name = self:GetName() or userid
            player.prefab = self:GetPrefab()
            player.player_classified = nil

            player.entity:SetCanSleep(false)
            player.entity:Hide()

            local session_data = self:GetSessionData()
            local inventory_data = session_data and session_data.data and session_data.data.inventory
            if inventory_data then
                -- Make sure we have the inventory component.
                if not player.components.inventory then
                    player:AddComponent("inventory")
                end

                player.components.inventory:OnLoad(inventory_data)

                player.GetSaveRecord = function()
                    local inv_save_data = player.components.inventory:OnSave()
                    session_data.data.inventory = inv_save_data

                    return session_data
                end
            else
                player:Remove()
                return -- Failed to load the session data.
            end

            -- Make sure the instance is removed the next tick.
            PEARL.WallScheduler:ExecuteInTime(0, function()
                if player ~= nil then
                    -- Save the changes.
                    SerializeUserSession(player)

                    player:Remove()
                end
            end)
        end
    end

    return player
end

function PlayerMetadata:SetInventoryIterator(__pairs)
    if type(__pairs) == "function" then
        return setmetatable(self._inventory, {
            __pairs = __pairs
        })
    end
end

--- FLAT version of the inventory for embed building.
function PlayerMetadata:GetInventory()
    return self._inventory
end

--- Used for simulating inventories of offline players.
function PlayerMetadata:GetSessionData()
    return self._session_data
end

function PlayerMetadata:GetPrefab()
    return self._prefab
end

function PlayerMetadata:GetName()
    return self._name
end

function PlayerMetadata:GetAge()
    return self._age or 0
end

function PlayerMetadata:GetUserID()
    return self._userid
end

function PlayerMetadata:GetNetID()
    return self._netid
end

-- Whether the basic player data are loaded or not.
function PlayerMetadata:IsLoaded()
    return self._loaded
end

-- Whether the player this metadata belongs to has an active instance on the server.
function PlayerMetadata:IsActive()
    return LookupPlayerInstByUserID(self._userid) ~= nil
end

-------------------------------------
-- [[ Loaders ]]
-------------------------------------

function PlayerMetadata:OnSessionLoaded(data)
    PEARL.debug("PlayerMetadata:OnSessionLoaded")

    self:SetSessionData(data)

    local client = self._userid and TheNet:GetClientTableForUser(self._userid) or PEARL.ServerNetwork:GetCachedClientTableFor(self._userid)
    self:SetAge((client and client.playerage) or data.age or self._age)
    self:SetPrefab(client and client.prefab or data.prefab)

    if not self._name then
        self:SetName(PEARL.DB:GetField(self._userid, "username", client and client.name))
    end

    if not self._netid then
        self:SetNetID(PEARL.DB:GetField(self._userid, "netid", client and client.netid))
    end

    self._loaded = true
end

function PlayerMetadata:LoadPlayerData()
    local userid = self:GetUserID()
    local sessionid = TheNet:GetSessionIdentifier()
    local file = TheNet:GetUserSessionFile(sessionid, userid)
    if not file then
        return false
    end

    local success = false
    -- This is some fake async function or something?
    TheNet:DeserializeUserSession(file, function(ok, str)
        -- The prefab provided here is the same as data.prefab
        local data, _ = ParseUserSessionData(str)
        if not data then
            return
        end

        self:OnSessionLoaded(data)
        success = self:IsLoaded()
    end)

    return success
end

--- @return boolean success
function PlayerMetadata:LoadInventoryData()
    if self:IsActive() then
        -- If the player is playing in the server.
        local player = LookupPlayerInstByUserID(self._userid)
        if player and player.components and player.components.inventory then
            self:SetInventory(player.components.inventory)
            return true
        end

        return false
    end

    local data = self:GetSessionData()

    -- we also want to check walter's woby
    if data and data.data and data.data.woby and data.data.woby.data and
    data.data.woby.data.container and data.data.woby.data.container.items then
        for _, v in pairs(data.data.woby.data.container.items) do
            self:AddInventoryItem(v)
        end
    end

    local inventory = data and data.data and data.data.inventory
    if not inventory then
        return false
    end

    for _, item in pairs(inventory.items) do
        self:AddInventoryItem(item)

        -- for bundles
        if item.data and item.data.unwrappable and item.data.unwrappable.items then
            for _, v in pairs(item.data.unwrappable.items) do
                self:AddInventoryItem(v)
            end
        end
    end

    --- [[ Active Item ]] ---
    if inventory.activeitem then
        self:AddInventoryItem(inventory.activeitem)
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

    return true
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return PlayerMetadata
