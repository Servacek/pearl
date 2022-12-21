
local PEARL = PEARL

--- @class Container
local Container = require("components/container")

--------------------------------
-- [[ Public Functions ]]
--------------------------------

PEARL.AddClassFunctionPreCall("Close", function(self, doer)
    if doer then
        doer:PushEvent("closedcontainer", self.inst)
    end
end, Container)

PEARL.AddClassFunctionPreCall("Open", function(self, doer)
    if doer then
        doer:PushEvent("openedcontainer", self.inst)
    end
end, Container)
