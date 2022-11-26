-- This thing needs some further investigation. Maybe in version 2.1?

require("stacktrace")

local PEARL = PEARL

PEARL.AddGlobalFunctionPreCall("moderror", function(mod, err, ...)
    pcall(PEARL.Reporter.ReportModError, PEARL.Reporter, err)
    PEARL.EventProcessor:HandleEvent("quit")
end)

PEARL.AddClassFunctionPreCall("RemoveBadMod", function(self, modname, reason)
    pcall(PEARL.Reporter.ReportModError, PEARL.Reporter, reason)
    PEARL.EventProcessor:HandleEvent("quit")
end, ModManager)
