-- This thing needs some further investigation. Maybe in version 2.1?

require("stacktrace")

local PEARL = PEARL

PEARL.AddGlobalFunctionPreCall("moderror", function(mod, err, ...)
    pcall(PEARL.DiscordReporter.ReportModError, PEARL.DiscordReporter, err)
    PEARL.EventProcessor:HandleEvent("quit")
end)

PEARL.AddClassFunctionPreCall("RemoveBadMod", function(self, modname, reason)
    pcall(PEARL.DiscordReporter.ReportModError, PEARL.DiscordReporter, reason)
    PEARL.EventProcessor:HandleEvent("quit")
end, ModManager)
