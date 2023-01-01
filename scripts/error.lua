
local function OnError(error)
    PEARL.DiscordReporter:ReportUncatchedLuaError(error.text:GetString())
    -- Disable to prevent any looping since these reports are sent by force.
    PEARL.DiscordReporter:SetIsDisabled(true)

    --- @TODO: Maybe some internal "error" event would be better?
    if TheWorld then
        TheWorld:PushEvent("shard_shutdown")
    end

    PEARL.EventProcessor:HandleEvent("quit")
end

PEARL.AddClassPostConstruct("widgets/scripterrorwidget", function(self)
    -- We do not want more errors
    print(pcall(OnError, self))
end)
