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
    Capable of deffering the client's loading process when waiting for a server's response.
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
local load_deffered = false

local function LoadOverride(...)
    -- Always save these args for the future.
    ClientLoader:SetLoadArgs(...)

    if ClientLoader:IsLoadDeffered() then
        PEARL.debug("Deffering further loading of the client...")
        return false
    end

    PEARL.debug("ClientLoader:Load")
    return ClientLoader:Load()
end

local function OverrideLoader()
    if Profile.Load == LoadOverride then
        return PEARL.warn("Loader already overriden!")
    end

    return PEARL.OverrideVariable("Load", LoadOverride, Profile)
end

local function RestoreLoader()
    if Profile.Load == load_fn then
        return PEARL.warn("Loader wasn't changed!")
    end

    return PEARL.OverrideVariable("Load", load_fn, Profile)
end

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

-- Loading is only being deffered if ClientNetwork requests so. Else nothing is being overriden or
-- changed in any way.
function ClientLoader:DefferLoad()
    PEARL.debug("ClientLoader:DefferLoad")

    if self:IsLoadDeffered() then
        return --PEARL.warn("Loading of the client was already deffered!")
    end

    self:SetLoadDeffered(true)
    OverrideLoader()
end

function ClientLoader:CancelDeffer()
    if not self:IsLoadDeffered() then
        return PEARL.warn("The loading is not deffered!")
    end

    RestoreLoader()
    self:SetLoadDeffered(false)
end

---------------------------------
-- [[ Setters ]]
---------------------------------

function ClientLoader:SetLoadArgs(...)
    load_fn_args = {...}
end

function ClientLoader:SetLoadDeffered(deffered)
    load_deffered = deffered
end

---------------------------------
-- [[ Getters ]]
---------------------------------

function ClientLoader:IsLoaded()
    return loaded == true
end

function ClientLoader:IsLoadDeffered()
    return load_deffered == true
end

---------------------------------
-- [[ Return ]]
---------------------------------

return ClientLoader
