--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Handles uncatched errors and reports them to discord.
]]


local function OnError(error)
    PEARL.DiscordReporter:ReportUncatchedLuaError(error.text:GetString())
    -- Disable to prevent any looping since these reports are sent by force.
    PEARL.DiscordReporter:SetIsDisabled(true)

    --- @TODO: Maybe some internal "error" event would be better?
    if TheWorld then
        TheWorld:PushModEvent("shard_shutdown")
    end

    PEARL.EventProcessor:HandleEvent("quit")
end

PEARL.AddClassPostConstruct("widgets/scripterrorwidget", function(self)
    -- We do not want more errors
    print(pcall(OnError, self))
end)
