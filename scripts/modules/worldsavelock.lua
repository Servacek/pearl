--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

-- Locking mechanism for loading world saves to prevent corruption.


local WorldSaveLock = {
    locked = false,
    installed = {},
}

local function BlockSave()
    if WorldSaveLock.locked then
        PEARL.warn("Blocked world save while the world reload lock is active.")
        return false
    end
end

local function InstallGlobalGuards()
    for _, name in ipairs({
        "SaveGame",
        "SerializeWorldSession",
        "SerializeUserSession",
    }) do
        if not WorldSaveLock.installed["global:"..name] and type(rawget(_G, name)) == "function" then
            PEARL.AddGlobalFunctionPreCall(name, BlockSave)
            WorldSaveLock.installed["global:"..name] = true
        else
            if not WorldSaveLock.installed["global:"..name] then
                PEARL.warn("World save guard target is unavailable:", name)
            end
        end
    end
end

local function InstallUserdataGuards()
    local targets = {
        {TheNet, "SerializeWorldSession"},
        {TheNet, "SerializeUserSession"},
        {TheNet, "SerializeUserSessionInClusterSlot"},
        {TheSim, "SetPersistentStringInClusterSlot"},
    }

    for _, target in ipairs(targets) do
        local userdata, name = target[1], target[2]
        local metatable = getmetatable(userdata)
        local methods = metatable and metatable.__index
        local key = tostring(userdata)..":"..name
        if not WorldSaveLock.installed[key] and type(methods) == "table" and type(methods[name]) == "function" then
            PEARL.AddUserDataFunctionPreCall(name, BlockSave, userdata)
            WorldSaveLock.installed[key] = true
        else
            if not WorldSaveLock.installed[key] then
                PEARL.warn("World save guard target is unavailable:", name)
            end
        end
    end
end

function WorldSaveLock:Install()
    InstallGlobalGuards()
    InstallUserdataGuards()
end

function WorldSaveLock:Lock()
    self:Install()
    self.locked = true
    PEARL.info("World save lock enabled.")
end

function WorldSaveLock:Unlock()
    self.locked = false
    PEARL.info("World save lock disabled.")
end

function WorldSaveLock:IsLocked()
    return self.locked
end

return WorldSaveLock
