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
local COMPONENT_EXTENSION_PATH = "extensions/components/%s"
local COMPONENT_PATH = "components/%s"
local MT = getmetatable(PEARL.ENV)

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ExtensionManager
local ExtensionManager = {}

--------------------------------
-- [[ Private ]]
--------------------------------

local function errcb(rfp, errmsg)
    if PEARL.CONFIG.DEBUG_MODE then
        return error(errmsg)
    end

    PEARL.error("Failed to load extension file", rfp, "Error: ", errmsg)
end

local function PrefabFn(prefab)
    local Prefab = Prefabs[prefab]
    local fn = Prefab and Prefab.fn
    if type(fn) ~= "function" then
        return error("Prefab does not support extensions")
    end

    return fn
end

local function ComponentFn(component)
    local cmp = require(COMPONENT_PATH.format(component))
    if not (type(cmp) == "table" and type(cmp._ctor) == "function") then
        return error("Component does not support extensions")
    end

    return cmp._ctor
end

local function GetEnv(name, fnloader, dynamic)
    local fn = not dynamic and fnloader(name) or nil

    -- Load the upvalues dynamically, use this as a cache
    local upvalues = {}--UpvalueHacker:GetSourceFileUpvalues(fn)
    local metatable = {
        __index = function(self, index)
            if upvalues[index] ~= nil then
                return upvalues[index]
            end

            if not fn then
                fn = fnloader(name)
            end

            local value = UpvalueHacker:GetUpvalueRecursively(fn, index)
            upvalues[index] = value
            return value
        end,

        __newindex = function(self, index, value)
            if not fn then
                fn = fnloader(name)
            end

            rawset(upvalues, index, value)
            return UpvalueHacker:SetUpvalue(fn, value, index)
        end,
    }

    return setmetatable({
        UPVALUES = setmetatable({
            -- Cache = function(self, index)
            --     if upvalues[index] then
            --         return PEARL.warn("Index", index, "already cached!")
            --     end

            --     return metatable.__index(self, index)
            -- end,

            -- SetSource = function(self, source)

            -- end
        }, metatable),
    }, MT)
end
--------------------------------
-- [[ Public ]]
--------------------------------

function ExtensionManager:ExtendPrefab(prefab)
    PEARL.info("Extending prefab", prefab)
    return PEARL.loadfile(
        -- Use dynamic fn loading here because prefabs are not initialized yet.
        PREFAB_EXTENSION_PATH:format(prefab), GetEnv(prefab, PrefabFn,true), false, errcb
    )
end

function ExtensionManager:ExtendComponent(component)
    PEARL.info("Extending component", component)
    return PEARL.loadfile(
        COMPONENT_EXTENSION_PATH:format(component), GetEnv(component, ComponentFn), false, errcb
    )
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ExtensionManager
