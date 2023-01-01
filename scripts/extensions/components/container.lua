
local PEARL = PEARL

--- @class Container
local Container = require("components/container")

--------------------------------
-- [[ Getters ]]
--------------------------------

function Container:GetRareItems()
    local items = {}

    -- Go just one level deep for now
    self:ForEachItem(function(item)
        if item.components.inventoryitem:IsRare() then
            items[#items + 1] = item
        end
    end)

    return items
end

--------------------------------
-- [[ Public Functions ]]
--------------------------------

PEARL.AddClassFunctionPreCall("Close", function(self, doer)
    if doer then
        doer:PushModEvent("closedcontainer", self.inst)
    end
end, Container)

PEARL.AddClassFunctionPreCall("Open", function(self, doer)
    if doer then
        doer:PushModEvent("openedcontainer", self.inst)
    end
end, Container)
