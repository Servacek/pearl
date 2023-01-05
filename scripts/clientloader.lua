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
    Capable of delaying the client loading process via Profile:Load. Used
    by localizer when waiting for a server response.
--]]


-- In frontend, use staticScheduler for background tasks
-- In backend, staticScheduler doesn't work so wallScheduler is what should be used.
local staticScheduler = staticScheduler

---------------------------------
-- [[ Declaration ]]
---------------------------------

--- @class ClientLoader
local ClientLoader = {}

---------------------------------
-- [[ Private ]]
---------------------------------

local _load_fn = Profile.Load
local _load_fn_args = nil

local _load_task = nil
local _loaded = false
local _load_delay = nil

---------------------------------
-- [[ Public ]]
---------------------------------

function ClientLoader:Load()
    if type(_load_fn) ~= "function" then
        return PEARL.error("_load_fn is invalid!")
    end

    if type(_load_fn_args) ~= "table" then
        return PEARL.error("Invalid _load_fn_args!")
    end

    if self:IsLoaded() then
        return PEARL.warn("Client already loaded")
    end

    self:CancelDelayedLoad()

    PEARL.debug("Loading the client...")

    --_loading = true
    _load_fn(unpack(_load_fn_args))
    --_loading = false

    _loaded = true
end

function ClientLoader:SetLoadDelay(delay)
    _load_delay = delay
end

function ClientLoader:StartLoadDelayTask()
    if _load_delay and _load_fn and _load_fn_args and not self:HasLoadDelayStarted() then
        _load_task = staticScheduler:ExecuteInTime(_load_delay, self.Load, nil, self)
    end
end

function ClientLoader:CancelDelayedLoad()
    if self:HasLoadDelayStarted() then
        _load_task:Cancel()
        _load_task = nil
    end
end

function ClientLoader:IsLoaded()
    return _loaded == true
end

function ClientLoader:HasLoadDelayStarted()
    return _load_task ~= nil and _load_task.limit and _load_task.limit > 0
end

---------------------------------
-- [[ Setup ]]
---------------------------------

Profile.Load = function(...)
    if not _load_fn_args then
        _load_fn_args = {...}
    end

    if _load_delay and not ClientLoader:IsLoaded() then
        ClientLoader:StartLoadDelayTask()

        -- Do not load now
        return false
    end

    return _load_fn(...)
end

PEARL.AddGlobalFunctionPreCall("OnNetworkDisconnect", function()
    ClientLoader:CancelDelayedLoad()
end)

return ClientLoader
