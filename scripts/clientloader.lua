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

    PEARL.debug("Loading the client...")

    loaded = true
    load_fn(unpack(load_fn_args))
end

function ClientLoader:ForceLoad()
    return self:Load()
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

---------------------------------
-- [[ Setup ]]
---------------------------------

--- Use that so far and rework the ClientLoader a bit.
--- Especially, make it so that we delay the load only if it's REALLY needed,
--- otherwise it makes just an unnecessary lag.
if (not TheNet:GetIsServerAdmin() or PEARL.CONFIG.DEBUG_MODE) and PEARL.ClientNetwork:IsJoiningServer() then
    PEARL.OverrideVariable("Load", function(...)
        -- Always save these args for the future.
        ClientLoader:SetLoadArgs(...)

        -- If we are diconnected or we are waiting for a response from the server
        -- we do not want to continue the loading now.
        if PEARL.ClientNetwork:IsDisconnecting() or PEARL.ClientNetwork:IsWaitingForResponse() then
            PEARL.debug("Deffering further loading of the client...")
            return false
        end

        PEARL.debug("ClientLoader:Load")
        return ClientLoader:Load()
    end, Profile)
end

---------------------------------
-- [[ Return ]]
---------------------------------

return ClientLoader
