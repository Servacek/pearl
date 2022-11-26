
local PEARL = PEARL

PEARL.AddClassFunctionPreCall("Close", function(self, doer)
    if doer then
        doer:PushEvent("pearl_closecontainer", self.inst)
    end
end, "components/container")

PEARL.AddClassFunctionPreCall("Open", function(self, doer)
    if doer then
        doer:PushEvent("pearl_opencontainer", self.inst)
    end
end, "components/container")
