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

---------------------------------
-- [[ Declaration ]]
---------------------------------

--- @class ClientLoader
local ClientLoader = {}

---------------------------------
-- [[ Private ]]
---------------------------------

local load_fn = Profile.Load
local load_fn_args = nil
local loaded = false

---------------------------------
-- [[ Public ]]
---------------------------------

function ClientLoader:Load()
    if type(load_fn) ~= "function" then
        return PEARL.error("_load_fn is invalid!")
    end

    if type(load_fn_args) ~= "table" then
        return PEARL.error("Invalid _load_fn_args!")
    end

    if self:IsLoaded() then
        return PEARL.debug("Client already loaded")
    end

    -- self:CancelDelayedLoad()

    PEARL.debug("Loading the client...")

    loaded = true
    load_fn(unpack(load_fn_args))
end


---------------------------------
-- [[ Setters ]]
---------------------------------

function ClientLoader:SetLoadArgs(...)
    load_fn_args = {...}
end

---------------------------------
-- [[ Getters ]]
---------------------------------

function ClientLoader:IsLoaded()
    return loaded == true
end

-- function ClientLoader:GetLoadDelay()
--     return _load_delay
-- end

-- function ClientLoader:SetLoadDelay(delay)
--     _load_delay = delay
-- end

-- function ClientLoader:SetIsDisabled(disabled)
--     _disabled = disabled
-- end

-- function ClientLoader:StartLoadDelayTask()
--     if _load_delay and _load_fn and _load_fn_args and not self:HasLoadDelayStarted() then
--         _load_task = staticScheduler:ExecuteInTime(_load_delay, self.Load, nil, self)
--     end
-- end

-- function ClientLoader:CancelDelayedLoad()
--     if self:HasLoadDelayStarted() then
--         _load_task:Cancel()
--         _load_task = nil
--     end
-- end

-- function ClientLoader:IsDisabled()
--     return _disabled
-- end

-- function ClientLoader:IsEnabled()
--     return not _disabled
-- end

-- function ClientLoader:HasLoadDelayStarted()
--     return _load_task ~= nil
-- end

---------------------------------
-- [[ Setup ]]
---------------------------------

--- @TODO: Create some timeout for this so the client won't be stuck on a black screen.
--- @TODO: Profile:Load seems to be the best option after quite a lot of testing.
--- Use that so far and rework the ClientLoader a bit.
--- Especially, make it so that we delay the load only if it's REALLY needed,
--- otherwise it makes just an unnecessary lag.
PEARL.OverrideVariable("Load", function(...)
    ClientLoader:SetLoadArgs(...)

    -- If we are diconnected or we are waiting for a response from the server
    -- we do not want to continue the loading now.
    if PEARL.ClientNetwork:IsDisconnected() or PEARL.ClientNetwork:IsWaitingForResponse() then
        return false
    end

    PEARL.debug("ClientLoader:Load")
    return ClientLoader:Load()
end, Profile)

-- The global 'OnNetworkDisconnect' needs to be handled after FrontEnd is loaded because
-- else we will crash the client since no widgets for the disconnection popup are loaded yet.
-- So save the reason and other parameters and call the actual function when FE is ready.
-- PEARL.AddGlobalFunctionPreCall("OnNetworkDisconnect", function()
--     ClientLoader:CancelDelayedLoad()
-- end)

return ClientLoader
