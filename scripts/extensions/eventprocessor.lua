--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
---@diagnostic disable: redundant-parameter

--[[
    A little extension for the built-in EventProcessor.
    Adds safe versions for AddEventHandler and HandleEvent methods.
]]


--- @class EventProcessor
local EventProcessor = EventProcessor


function EventProcessor:AddSafeEventHandler(event, fn, ...)
    return self:AddEventHandler(event, function(...)
        PEARL.SafeRun(fn, ...)
    end, ...)
end

function EventProcessor:SafeHandleEvent(...)
    return PEARL.SafeRun(self.HandleEvent, self, ...)
end
