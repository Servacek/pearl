--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local UpvalueHacker = PEARL.loadfile("utils/upvaluehacker")

--------------------------------
-- [[ Global Localization ]]
--------------------------------

-- We want the actual table from the global environment that will be loaded.
local Prefabs = PEARL.GetValue(_G, "Prefabs")

--------------------------------
-- [[ Constants ]]
--------------------------------

local PREFAB_EXTENSION_PATH = "extensions/prefabs/%s"
local MT = getmetatable(PEARL.ENV)

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ExtensionManager
local ExtensionManager = {}

--------------------------------
-- [[ Private ]]
--------------------------------

local function GetEnvForPrefab(prefab)
    local fn
    local function LoadFn()
        local Prefab = Prefabs[prefab]
        fn = Prefab and Prefab.fn
        if type(fn) ~= "function" then
            return error("Prefab does not support extensions")
        end
    end

    -- Load the upvalues dynamically, use this as a cache
    local upvalues = {}--UpvalueHacker:GetSourceFileUpvalues(fn)
    local metatable = {
        __index = function(self, index)
            if not fn then
                LoadFn()
            end

            if upvalues[index] ~= nil then
                print("PULLING FROM CACHE", index)
                return upvalues[index]
            end

            print("SEARCHING...", index)
            local value = UpvalueHacker:GetUpvalueRecursively(fn, index)
            upvalues[index] = value
            return value
        end,

        __newindex = function(self, index, value)
            if not fn then
                LoadFn()
            end

            rawset(upvalues, index, value)
            return UpvalueHacker:SetUpvalue(fn, value, index)
        end,
    }

    return setmetatable({
        UPVALUES = setmetatable({
            Cache = function(self, index)
                if upvalues[index] then
                    return PEARL.warn("Index", index, "already cached!")
                end

                print("CACHING", index)
                return metatable.__index(self, index)
            end,

            SetSource = function(self, source)
                
            end
        }, metatable),
    }, MT)
end

--------------------------------
-- [[ Public ]]
--------------------------------

function ExtensionManager:ExtendPrefab(prefab)
    PEARL.info("Extending prefab", prefab)
    return PEARL.loadfile(
        PREFAB_EXTENSION_PATH:format(prefab), GetEnvForPrefab(prefab)
    )
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ExtensionManager
