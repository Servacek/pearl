--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
---@diagnostic disable: redundant-parameter

--[[
    A little extension for the built-in EventProcessor.
    Adds safe versions for AddEventHandler and HandleEvent methods.

    We keep the unsafe versions for the game since
    that's a place where Klei should catch errors themselves if they feel so.
    Such side effect could cause corruption of user data if the crash
    is propagated too much into the system.

    This should be used for internal mod-side events that are not
    subjective to any game entity. For such, use the built-in event
    system that each EntityScript instance has (ListenForEvent and PushEvent).
]]

-- Make sure all the needed global variables are declared.
require("events")

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class EventProcessor
EventProcessor = EventProcessor
--- @class EventProcessor
local EventProcessor = EventProcessor

-------------------------------------
-- [[ Event Listeners ]]
-------------------------------------

function EventProcessor:AddSafeEventHandler(event, fn, ...)
    return self:AddEventHandler(event, function(...)
        PEARL.SafeRun(fn, ...)
    end, ...)
end

function EventProcessor:AddSafeOneTimeHandler(event, fn, ...)
    return self:AddSafeEventHandler(event, function(...)
        fn(...)

        -- Make this event a one timer.
        local handlers = PEARL.EventProcessor:GetHandlersForEvent(event)
        for handler, _ in pairs(handlers) do
            PEARL.EventProcessor:RemoveHandler(handler)
        end
    end, ...)
end

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function EventProcessor:SafeHandleEvent(...)
    return PEARL.SafeRun(self.HandleEvent, self, ...)
end

-------------------------------------
-- [[ Debugging ]]
-------------------------------------

if PEARL.CONFIG.DEBUG_MODE and TheNet:IsDedicated() then
    -- Use "pre-call" in case the handler throws an error.
    PEARL.AddClassFunctionPreCall("HandleEvent", function(event, ...)
        PEARL.debug("EventProcesser:HandleEvent", event, ...)
    end, EventProcessor)
end
