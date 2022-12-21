--[[
Detects movements with rare items caused by a player. This is an internal component.
It doesn't provide basically any useful function to the outside. It uses event's
for broadcasting information. Used only by the logger.

-- NEEDS SOME DEBUG AND TESTING

KNOWN BUGS:
- When the taken item is being split in the inventory to smaller stacks,
    the announced stacksize is not correct.
- No previous owner is being saved so it is annouced every time someone takes the item
- Picking up an container containing some rare items is not being taken as a theft.
- Sometimes a weird announcement happens when opening a chest full of items.
- Items that are not stackable will be displayed multiple times in the theft announcement.
--]]

local PEARL = PEARL

--------------------------------------------------------------------------
--[[ Class Initialization - Thief ]]
--------------------------------------------------------------------------

--- @class Thief
return Class(function(self, inst)
self._inst = inst

-- self._container = nil
self._ac_items_cache = {}

--------------------------------------------------------------------------
--[[ Private Atrributes and Methods ]]
--------------------------------------------------------------------------

local AddLoot, ClearLoot, WasItemLooted, SetActiveContainer, ClearActiveContainerCache, CacheActiveContainerItems, ClearActiveContainer, IsLooting, GetStolenItems

-- local function ongavetoactivecontainer(self, act_cont, item)
--     PEARL.debug("<ongavetoactivecontainer>", item, item.components.inventoryitem._holder)
--     if not (item and item.components.inventoryitem and item.components.inventoryitem:WasHeldBy(self._inst)) then
--         return
--     end

--     self:RemoveLoot(item.prefab, PEARL.GetStackSize(item))
-- end

-- local function ontookfromactivecontainer(act_cont, item)
--     PEARL.debug("<ontookfromactivecontainer>", item, item.components.inventoryitem.owner)
--     if not (item and item.components.inventoryitem
--         and item.components.inventoryitem:IsHeldBy(self._inst)
--         and item.components.inventoryitem:IsVeryRare()
--         ) then
--         return
--     end

--     AddLoot(item)
-- end

-- local function oncontaineritemlose(container, data)
--     if not (data and data.prev_item) or data.prev_item.components.inventoryitem:IsLastOwner(self._inst) then
--         return
--     end

--     -- Execute this in the next frame so the owner is correctly
--     -- assigned to the taken item.
--     PEARL.Scheduler:ExecuteInTime(0, ontookfromactivecontainer, nil, container, data.prev_item)
-- end

local function oncontaineritemlose(container, data)
    if not (container and data and data.prev_item) then
        return
    end

    PEARL.debug("<oncontaineritemlose>", data.prev_item)
    data.prev_item.components.inventoryitem:SetLastContainer(container)
end

local function oncontaineritemget(container, data)
    if not (container and data and data.item) then
        return
    end

    PEARL.debug("<oncontaineritemget>", data.item)
    data.item.components.inventoryitem:SetLastContainer(container)
end

local function onclosecontainer(doer, container)
    if not (container) then --and IsLooting()) then
        return
    end

    PEARL.debug("<onclosecontainer>", container)

    local stolen_items = GetStolenItems(container)
    if not IsTableEmpty(stolen_items) then
        doer:PushEvent("finishedlooting", {
            loot = stolen_items,
            container = container,
        })
    end

    --ClearActiveContainerCache()

    container:RemoveEventCallback("itemget", oncontaineritemget)
    container:RemoveEventCallback("itemlose", oncontaineritemlose)

    -- ClearActiveContainer()
    -- ClearLoot()
end

local function onopencontainer(doer, container)
    if not (doer and container and not container:IsInLimbo()) then
        return
    end

    -- We do not care about an empty container, there is nothing to steal from.
    -- if container.components.container and container.components.container:IsEmpty() then
    --     return
    -- end

    -- if container.components.inventoryitem and container.components.inventoryitem:WasHeldBy(doer) then
    --     return
    -- end

    -- Make sure we start with an clean cache
    --ClearActiveContainerCache()

    PEARL.debug("<onopencontainer>", container)
    -- Cache all items in the newly opened container

    container:ListenForEvent("itemget", oncontaineritemget)
    container:ListenForEvent("itemlose", oncontaineritemlose)
    --CacheActiveContainerItems(container)
    -- SetActiveContainer(container)
end

local function onpickupitem(doer, data)
    local item = data.item
    if not (doer and item) then
        return
    end

    local inv_item = item.components.inventoryitem
    if (inv_item:IsLastPlayerOwner(doer) or not inv_item:IsVeryRare()) then
        return
    end

    -- PEARL.debug(string.format("<onpickupitem[item: %s, owner: %s, holder_prev: %s, holder_new: %s]>", item.prefab,
    --     tostring(inv_item.owner), tostring(inv_item.holder), tostring(doer)))
    self._inst:PushEvent("tookrareitem", item)
end

local function onplayerdespawned(player)
    --onclosecontainer()
end

--------------------------------

local function RegisterListeners()
    if not self._inst then
        return
    end

    PEARL.info("Registering listeners for", inst)

    --> Do not use itemget and itemlose events for this since they are used by the Frontend
    self._inst:ListenForEvent("onpickupitem", onpickupitem)

    self._inst:ListenForEvent("openedcontainer", onopencontainer)
    --> Use "closecontainer" instead of the built-in "closecontainer" event because
    --> that is for some reason called only when closing a container by clicking on it.
    self._inst:ListenForEvent("closedcontainer", onclosecontainer)

    --- @TODO: Debug if this is needed
    self._inst:ListenForEvent("player_despawn", onplayerdespawned)
end

-------------- Setup ------------------

--- @TODO Load after the player is activated (Should not be needed anymore)
RegisterListeners()

--------------------------------
-- [[ Setters ]]
--------------------------------

-- SetActiveContainer = function(container)
--     self._container = container

--     if not self._container then
--         return
--     end

--     -- self._container:ListenForEvent("itemget", self._oncontaineritemget)
--     self._container:ListenForEvent("itemlose", oncontaineritemlose)
-- end

-- ClearActiveContainer = function()
--     if self._container then
--         -- self._container:RemoveEventCallback("itemget", self._oncontaineritemget)
--         self._container:RemoveEventCallback("itemlose", oncontaineritemlose)
--         -- self._container:ListenForEvent("itemlosefromstack", self._oncontaineritemlose)
--         -- self._container:ListenForEvent("itemaddtostack", self._oncontaineritemget)
--     end

--     self._container = nil
-- end

-- WasItemLooted = function(item)
--     for i = 1, #self._loot do
--         if self._loot[i].GUID == item.GUID then
--             return true
--         end
--     end

--     return false
-- end

-- AddLoot = function(item)
--     if not WasItemLooted(item) then
--         PEARL.debug("<AddLoot[item:", item.prefab, "]>")

--         self._loot[#self._loot + 1] = item
--     end
-- end

GetStolenItems = function(container)
    local stolen_items = {}

    -- self._inst.components.inventory:ForEachItem(function(item)
    --     if item.components.inventoryitem:WasStolen() then
    --         stolen_items[#stolen_items + 1] = item
    --     end
    -- end)

    -- Items can be invalid here
    -- Create some algorithm that can detect changes in the stacksizes of items.
    container.components.container:ForEachItem(function(item)

        for _, cached_item in ipairs(self._ac_items_cache) do
            if cached_item.components.inventoryitem and cached_item.components.inventoryitem:IsHeldBy(self._inst) then
            -- Make sure we still own the item
                stolen_items[#stolen_items + 1] = cached_item
            end
        end
    end)

    return stolen_items
end

CacheActiveContainerItems = function(container)
    if not container.components.container then
        return
    end

    container.components.container:ForEachItem(function(item)
        if item.components.inventoryitem:IsVeryRare() then
            print("CACHING CONTAINER ITEM -> ", item)
            self._ac_items_cache[#self._ac_items_cache + 1] = item
        end
    end)
end

-- function Thief:RemoveLoot(prefab, amount)
--     PEARL.debug("<RemoveLootPrefab[item:", prefab, "]>")

--     if not self._loot[prefab] or not amount or amount == self._loot[prefab] then
--         self._loot[prefab] = nil
--         return
--     end

--     self._loot[prefab] = self._loot[prefab] - amount
-- end

ClearActiveContainerCache = function()
    for i, item in ipairs(self._ac_items_cache) do
        print("CLEARING", item, "FROM CACHE!")
        self._ac_items_cache[i] = nil
    end
end

-- ClearLoot = function()
--     for prefab, _ in pairs(self._loot) do
--         self._loot[prefab] = nil
--     end
-- end

--------------------------------
-- [[ Getters ]]
--------------------------------

-- IsActiveContainer = function(container)
--     return container ~= nil and self._container == container
-- end

-- IsLooting = function()
--     return self._container ~= nil
-- end

--------------------------------
-- [[ Handlers ]]
--------------------------------

function self:OnRemoveFromEntity()
    self._inst:RemoveEventCallback("closedcontainer", onclosecontainer)
    self._inst:RemoveEventCallback("openedcontainer", onopencontainer)
    self._inst:RemoveEventCallback("onpickupitem", onpickupitem)

    self:ClearLoot()
    self:ClearActiveContainer()
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

end)
