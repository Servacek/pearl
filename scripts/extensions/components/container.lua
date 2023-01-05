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
