
local PEARL = PEARL

----------------------------------------------
-- [[ Private Functions - Event Handlers ]]
----------------------------------------------
--- @TODO create the more expensive aproach first
local function onclosecontainer(doer, container)
    if not container or not doer.components.thief:IsLooting() then
        return
    end

    PEARL.debug("<onclosecontainer>", container, "LOOT:")

    if doer.components.thief:HasLoot() then
        doer:PushEvent("finishedlooting", {
            loot = doer.components.thief:BuildLootTable(),
            container = container,
        })
    end

    doer.components.thief:ClearActiveContainer()
    doer.components.thief:ClearLoot()
end

local function onopencontainer(doer, container)
    if not (doer and container) then
        return
    end

    if container.components.inventoryitem and container.components.inventoryitem:WasHeldBy(doer) then
        return
    end

    PEARL.debug("<onopencontainer>", container)
    shallowcopy(doer.components.inventory)
    doer.components.thief:SetActiveContainer(container)
end

--- @TODO Ignore loaded items
--- Pushed only when a new item is added to the inventory.
--- Doesn't work for updating the stack size of an item.
local function onbecameholder(doer, item)
    if not (doer and item) then
        return
    end

    local inv_item = item.components.inventoryitem
    if (inv_item:WasHeldBy(doer) or not inv_item:IsVeryRare()) then
        return
    end

    PEARL.debug(string.format("<onbecameholder[item: %s, owner: %s, holder_prev: %s, holder_new: %s]>", item.prefab, tostring(inv_item.owner), tostring(inv_item.holder), tostring(doer)))
    local self = doer.components.thief
    -- holder should be the last player owner
    -- owner should be the last actual owner
    if self:IsLooting() and self:IsActiveContainer(inv_item.owner) then
        return self:AddLootPrefab(item.prefab)
    end

    self._inst:PushEvent("tookrareitem", {item = item, stacksize = PEARL.GetStackSize(item)})
end

--- @TODO
--- Called when we lose the whole stack of the item.
local function onreturnitem(doer, item)
    -- We only care about this event when the player is looting a container
    if not (doer and item and doer.components.thief:IsLooting()) then
        return
    end

    PEARL.debug("<onitemlose>", item.prefab)
    doer.components.thief:RemoveLootPrefab(item.prefab)
end

--------------------------------
--- @TODO: An item means one occupied block of an inventory.
--- Therefore it should be a better idea to just store the prefabs
--- of taken items and process their exact amounts when the container is closed.
local function RegisterListeners(inst)
    PEARL.info("Registering listeners for", inst)

    -- Do not use itemget and itemlose events for this since they are used by the Frontend
    inst:ListenForEvent("became_holder", onbecameholder)
    inst:ListenForEvent("return_item", onreturnitem)

    -- Container looting
    inst:ListenForEvent("pearl_closecontainer", onclosecontainer)
    inst:ListenForEvent("pearl_opencontainer", onopencontainer)
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

local Thief = Class(function(self, inst)
    self._inst = inst

    self._container = nil
    --self._loot = {}

    self._cached_inv = {}

    --- @TODO Load after the player is activated
    RegisterListeners(inst)
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

function Thief:SetActiveContainer(container)
    self._container = container
end

function Thief:ClearActiveContainer()
    self._container = nil
end

function Thief:AddLootPrefab(prefab)
    PEARL.debug("<AddLootPrefab[item:", prefab, "]>")

    self._loot[prefab] = true
end

function Thief:GetLoot()
    return self._loot
end

function Thief:BuildLootTable()
    local loot_table = {}
    for prefab, _ in pairs(self._loot) do
        loot_table[prefab] = self._inst.components.inventory:GetItemCount(prefab)
    end

    return loot_table
end

function Thief:HasLoot()
    return not IsTableEmpty(self._loot)
end

function Thief:RemoveLootPrefab(prefab)
    PEARL.debug("<RemoveLootPrefab[item:", prefab, "]>")
    self._loot[prefab] = nil
end

function Thief:ClearLoot()
    for prefab, _ in pairs(self._loot) do
        self._loot[prefab] = nil
    end
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function Thief:IsActiveContainer(container)
    return container ~= nil and self._container == container
end

function Thief:IsLooting()
    return self._container ~= nil
end

--------------------------------
-- [[ Handlers ]]
--------------------------------

function Thief:OnRemoveFromEntity()
    self._inst:RemoveEventCallback("pearl_closecontainer", onclosecontainer)
    self._inst:RemoveEventCallback("pearl_opencontainer", onopencontainer)
    self._inst:RemoveEventCallback("became_holder", onbecameholder)
    self._inst:RemoveEventCallback("return_item", onreturnitem)

    self:ClearLoot()
    self:ClearActiveContainer()
end

return Thief
