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
-- [[ Public Methods ]]
-------------------------------------

function EventProcessor:AddSafeEventHandler(event, fn, ...)
    return self:AddEventHandler(event, function(...)
        PEARL.SafeRun(fn, ...)
    end, ...)
end

function EventProcessor:SafeHandleEvent(...)
    return PEARL.SafeRun(self.HandleEvent, self, ...)
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
-- [[ Debugging ]]
-------------------------------------

if PEARL.CONFIG.DEBUG_MODE then
    -- Use "pre-call" in case the handler throws an error.
    PEARL.AddClassFunctionPreCall("HandleEvent", function(event, ...)
        PEARL.debug("EventProcesser:HandleEvent", event, ...)
    end, EventProcessor)
end
