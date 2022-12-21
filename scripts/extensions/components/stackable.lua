
local PEARL = PEARL

--- @class Stackable
local Stackable = require("components/stackable")

-----------------------------------
-- [[ Extension Functions ]]
-----------------------------------

-- function Stackable:GetStackPercent()
--     return self.stacksize / self.maxsize
-- end

local _Get = Stackable.Get
Stackable.Get = function(self, ...)
    local new_item = _Get(self, ...)

    -- If the container is an active container and someone takes a part of
    -- it's item's stack.
    if self.inst.components.inventoryitem then
        PEARL.debug("Stackable:GET -> Inheriting Last Container")
        new_item.components.inventoryitem:SetLastContainer(
            self.inst.components.inventoryitem._last_container
        )
    end

    -- print("GET: Inherit Owner")
    -- new_item.components.inventoryitem:SetOwner(self.inst.components.inventoryitem.owner)


    return new_item
end

local _Put = Stackable.Put
Stackable.Put = function(self, item, ...)
    _Put(self, item, ...)

    -- if self.inst.components.inventoryitem then
    --     PEARL.debug("Stackable:GET -> Inheriting Stolen Flag")
    --     self._inst.components.inventoryitem:SetLastContainer(
    --         self.inst.components.inventoryitem._last_container
    --     )
    -- end

    -- if not item then
    --     return
    -- end

    -- print("PUT: Inherit owner")
    -- item.components.inventoryitem:SetOwner(self.inst.components.inventoryitem.owner)

    -- print("Stackable:Put<"..tostring(item)..">", item.components.inventoryitem._holder, self.inst.components.inventoryitem._holder)

    -- if self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner then
    --     self.inst.components.inventoryitem.owner:PushEvent("itemaddtostack", {item = item})
    -- end

    -- item.components.inventoryitem:SetHolder(self.inst.components.inventoryitem:GetHolder())
end
