--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Capable of defering the client's loading process when waiting for a server's response.
--]]

---------------------------------
-- [[ Declaration ]]
---------------------------------

--- @class ClientLoader
local ClientLoader = {}

---------------------------------
-- [[ Private ]]
---------------------------------

local load_fn = Profile and Profile.Load
local load_fn_args = nil
local loaded = false
local load_defered = false

local preload_handlers      = {}
local deferants             = {}

---------------------------------
-- [[ Local Functions ]]
---------------------------------

local function LoadOverride(...)
    -- Always save these args for the future.
    ClientLoader:SetLoadArgs(...)

    -- If not defered, then this is not being called but just to be sure.
    -- In case we cachanged mind during that few frames.
    if ClientLoader:ShouldDeferLoad() then
        PEARL.debug("Defering further loading of the client...")

        ClientLoader:SetLoadDefered(true)
        return false
    end

    PEARL.debug("ClientLoader:Load")
    return ClientLoader:Load()
end

local function IsLoaderOverriden()
    return Profile.Load == LoadOverride
end

local function OverrideLoader()
    if type(Profile) ~= "table" then
        return PEARL.error("Profile is invalid!")
    end

    if IsLoaderOverriden() then
        return PEARL.warn("Loader already overriden!")
    end

    return PEARL.OverrideVariable("Load", LoadOverride, Profile)
end

local function RestoreLoader()
    PEARL.debug("RestoreLoader")

    if type(Profile) ~= "table" then
        return PEARL.error("Profile is invalid!")
    end

    if type(load_fn) ~= "function" then
        return PEARL.error("Original loading function is invalid!")
    end

    if not IsLoaderOverriden() then
        return PEARL.warn("Loader wasn't changed!")
    end

    return PEARL.OverrideVariable("Load", load_fn, Profile)
end

---------------------------------
-- [[ Public ]]
---------------------------------

function ClientLoader:Load()
    if not self:IsLoadDefered() then
        return PEARL.debug("Loading was not defered.")
    end

    if type(load_fn) ~= "function" then
        return PEARL.error("_load_fn is invalid!")
    end

    -- This should actually never happen
    if type(load_fn_args) ~= "table" then
        return PEARL.error("Invalid _load_fn_args!")
    end

    if self:IsLoaded() then
        return PEARL.debug("Client already loaded")
    end

    -- In case this gets called in the future as well.
    PEARL.debug("Restoring default load handler and cleaning up...")
    RestoreLoader()

    self:Cleanup()

    PEARL.debug("Loading the client...")
    loaded = true
    load_fn(PEARL.unpack(load_fn_args))

    -- Make sure we are not defering garbage collection too!
    load_fn_args = nil
end

function ClientLoader:RemoveDeferant(name)
    PEARL.debug("ClientLoader:RemoveDeferant", name)

    if type(name) ~= "string" then
        return PEARL.error("Invalid deferant name!")
    end

    deferants[name] = nil

    -- This was the last deferant preventing us from loading.
    if not self:ShouldDeferLoad() then
        self:Load()

        return
    end

    -- In case the loader was not yet defered and we have
    -- removed all deferants for some weird reason.
    -- No point in keeping the loader overriden.
    if not self:IsLoadDefered() and IsLoaderOverriden() then
        RestoreLoader()
    end
end

function ClientLoader:AddDeferant(name)
    PEARL.debug("ClientLoader:AddDeferant", name)

    if type(name) ~= "string" then
        return PEARL.error("Invalid deferant name!")
    end

    if deferants[name] ~= nil then
        PEARL.error("Deferant already exists!", name)
        -- Do not return here so we ensure the value is always "true"
    end

    deferants[name] = true

    if not IsLoaderOverriden() then
        OverrideLoader()
    end
end

function ClientLoader:AddPreLoadHandler(handler)
    PEARL.debug("ClientLoader:AddPreloadFn")

    if table.contains(preload_handlers, handler) then
        PEARL.warn("Preload handler already exists!")
    end

    table.insert(preload_handlers, handler)
end

function ClientLoader:Cleanup()
    self:SetLoadDefered(false)

    table.clear(deferants)
end

---------------------------------
-- [[ Setters ]]
---------------------------------

function ClientLoader:SetLoadArgs(...)
    load_fn_args = {...}
end

function ClientLoader:SetLoadDefered(defered)
    load_defered = defered
end

---------------------------------
-- [[ Getters ]]
---------------------------------

function ClientLoader:IsLoaded()
    return loaded == true
end

function ClientLoader:ShouldDeferLoad()
    return table.size(deferants) > 0
end

function ClientLoader:IsLoadDefered()
    return load_defered == true and IsLoaderOverriden()
end

---------------------------------
-- [[ Post-Inits ]]
---------------------------------

PEARL.AddFrontEndPostInit(function(fe)
    PEARL.debug("Running preloaders...")

    for _, handler in ipairs(preload_handlers) do
        PEARL.SafeRun(handler)
    end
end)

---------------------------------
-- [[ Return ]]
---------------------------------

return ClientLoader
