
local PEARL = PEARL

----------------------------------------------
-- [[ Private Functions - Event Handlers ]]
----------------------------------------------

local function onclosecontainer(doer, container)
    PEARL.debug("<onclosecontainer>", container, "LOOT:")

    PEARL.debug(DataDumper(doer.components.thief:GetLoot()))
    if doer.components.thief:HasLoot() then
        doer:PushEvent("finishedlooting", {
            loot = doer.components.thief:GetLoot(),
            container = container,
        })
    end

    doer.components.thief:ClearActiveContainer()
    doer.components.thief:ClearLoot()
end

local function onopencontainer(doer, container)
    PEARL.debug("<onopencontainer>", container)

    doer.components.thief:SetActiveContainer(container)
end

local function onputitemonstack(doer, data)
    if not data then
        return
    end

    local src_item = data.src_item
    local dst_item = data.dst_item
    print(src_item, dst_item)
    if not (src_item and dst_item) then
        return
    end

    PEARL.debug("<onputitemonstack>", src_item, dst_item)

    local self = doer.components.thief
    return self:OnRareItemStolen(data.src_item)
end

local function removeitemfromstack(doer, data)
    if not data then
        return
    end
end

--- @TODO Ignore loaded items
--- Pushed only when a new item is added to the inventory.
--- Doesn't work for updating the stack size of an item.
local function onitemget(doer, data)
    PEARL.debug(string.format("GIVE ITEM[%s] (NEW OWNER: %s PREV OWNER: %s PREV CONTAINER: %s)",
        tostring(data.item), tostring(doer), tostring(data.item.components.inventoryitem.owner), tostring(data.item.prevcontainer)
    ))
    if not (doer and data and data.item) then
        return
    end

    local self = doer.components.thief
    local inv_item = data.item.components.inventoryitem

    if (inv_item.pholder == doer
        or not inv_item:IsVeryRare()
        -- Only count stuff in the inventory
        --or doer.components.inventory.activeitem == data.item
    ) then
        return
    end

    PEARL.debug("<onitemget[item:", data.item, "]>")
    self:OnRareItemStolen(data.item)
end

--- Called when we lose the whole stack of the item.
local function onitemlose(doer, data)
    if not (doer and data and data.prev_item) then
        return
    end

    local inv_item = data.prev_item.components.inventoryitem
    if (inv_item.owner == inv_item.pholder) then
        return
    end

    PEARL.debug("<onitemlose>", data.prev_item, inv_item.owner, inv_item.pholder)
    doer.components.thief:RemoveLoot(data.prev_item)
end

--------------------------------

local function RegisterListeners(inst)
    PEARL.info("Registering listeners for", inst)

    -- Use mod specific event's for these since the default ones do not handle all cases
    inst:ListenForEvent("pearl_closecontainer", onclosecontainer)
    inst:ListenForEvent("pearl_opencontainer", onopencontainer)
    inst:ListenForEvent("itemget", onitemget)
    inst:ListenForEvent("itemlose", onitemlose)
    inst:ListenForEvent("put_item_on_stack", onputitemonstack)
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

local Thief = Class(function(self, inst)

    self.inst = inst

    self.container = nil
    self.loot = {}

    inst:ListenForEvent("playerloaded", RegisterListeners)
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

function Thief:SetActiveContainer(container)
    self.container = container
end

function Thief:ClearActiveContainer()
    self.container = nil
end

function Thief:AddLoot(item, count)
    PEARL.debug("<AddLoot[item:", item, "count:", count, "]>")

    self.loot[item.prefab] = (self.loot[item.prefab] or 0) + (count or 1)
end

function Thief:GetLoot()
    return self.loot
end

function Thief:HasLoot()
    return not IsTableEmpty(self.loot)
end

function Thief:RemoveLoot(item, count)
    PEARL.debug("<RemoveLoot[item:", item, "count:", count, "]>")
    if not self.loot[item.prefab] then
        return
    end

    self.loot[item.prefab] = self.loot[item.prefab] - (count or 1)
    if self.loot[item.prefab] <= 0 then
        self.loot[item.prefab] = nil
    end
end

function Thief:ClearLoot()
    for prefab, _ in pairs(self.loot) do
        self.loot[prefab] = nil
    end
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function Thief:IsActiveContainer(container)
    return container ~= nil and self.container == container
end

-- function Thief:HasActiveContainer()
--     return self.container ~= nil
-- end

--------------------------------
-- [[ Handlers ]]
--------------------------------

function Thief:OnRareItemStolen(item, stack)
    -- Should always be a table
    local inv_item = item.components.inventoryitem
    if not inv_item:IsVeryRare(item) or inv_item.pholder == self.inst then
        return
    end

    stack = stack or (item.components.stackable and item.components.stackable:StackSize())
    PEARL.debug("<OnRareItemStolen[item:", item, "stack:", stack, "pcontainer:", inv_item.pcontainer, "]>")
    if inv_item and self:IsActiveContainer(inv_item.pcontainer) and stack > 0 then
        return self:AddLoot(item, stack)
    end

    self.inst:PushEvent("tookrareitem", {item = item, stacksize = stack})
end

function Thief:OnRareItemReturned(item, stack)
    stack = stack or (item.components.stackable and item.components.stackable:StackSize())

    PEARL.debug("<OnRareItemReturned[item:", item, "stack:", stack, "]>")

    self:RemoveLoot(item, stack)
end

function Thief:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("pearl_closecontainer", onclosecontainer)
    self.inst:RemoveEventCallback("pearl_opencontainer", onopencontainer)
    self.inst:RemoveEventCallback("itemget", onitemget)
    self.inst:RemoveEventCallback("itemlose", onitemlose)
    self.inst:RemoveEventCallback("put_item_on_stack", onputitemonstack)

    self:ClearLoot()
    self:ClearActiveContainer()
end

return Thief
