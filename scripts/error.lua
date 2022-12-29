
local function OnError(error)
    PEARL.DiscordReporter:ReportModError(error.text:GetString())
    PEARL.EventProcessor:HandleEvent("quit")
end

PEARL.AddClassPostConstruct("widgets/scripterrorwidget", function(self)
    -- We do not want more errors
    print(pcall(OnError, self))
end)
