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
    Additional API helper functions. This is basically just
    an extension to modindex.lua's environment functions.
--]]

local mod_post_inits = {}
local file_pre_loads = {}
local client_pre_loads = {}
local game_logic_preloads = {}
local global_var_postassigns = {}
local frontend_preinits = {}

-- local UpValueHacker = PEARL.loadfile("utils/upvaluehacker")

----------------------------------
-- Function Pre/Post call adders
----------------------------------

-- Overrides the given func with a function that calls func first,
-- stores it's result(s) and then calls postcb with the result as the first argument.
-- This function returns the return value(s) of postcb.
--- @return function origin
--- @return function repl
function PEARL.AddFunctionPostCall(name, postcb, tbl, noraw)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddFunctionPostCall", name, postcb, tbl)
    end

    if not (type(name) == "string" and type(postcb) == "function" and type(tbl) == "table") then
        return PEARL.warn("<AddFunctionPreCall> Invalid arguments!")
    end

    local postfn
    local _func = noraw and tbl[name] or rawget(tbl, name)
    if type(_func) ~= "function" then
        PEARL.debug(
            "<AddFunctionPreCall> Function '"..tostring(name).."' not declared in", tbl
        )

        postfn = postcb
    else
        postfn = function(...)
            local result = {_func(...)}
            --- @TODO: Maybe create a version of this
            --- post call where the result of the original function
            --- will be provided as a parameter to the postcb.
            --return postcb({_func(...)}, ...)
            postcb(...)

            return unpack(result)
        end
    end


    if postfn ~= _func then
        if noraw then
            tbl[name] = postfn
        else
            rawset(tbl, name, postfn)
        end
    end

    return _func, postfn
end

-- Similiar to 'AddGlobalFunctionPostCall' but calls precb before func suppling
-- all the arguments. The return value of func is not changed but you can prevent
-- the executioon of the original function by returning false.
--
-- Note: This function does not require the function to be declared in the given table.
--- @return function origin
--- @return function repl
function PEARL.AddFunctionPreCall(name, precb, tbl, noraw)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddFunctionPreCall", name, precb, tbl)
    end

    if not (type(name) == "string" and type(precb) == "function" and type(tbl) == "table") then
        return PEARL.warn("<AddFunctionPreCall> Invalid arguments!", name, precb)
    end

    local replfn
    local _func = noraw and tbl[name] or rawget(tbl, name)
    if type(_func) ~= "function" then
        PEARL.debug(
            "<AddFunctionPreCall> Function '"..tostring(name).."' not declared in", tbl
        )

        replfn = precb
    else
        replfn = function(...)
            if precb(...) ~= false then
                return _func(...)
            end

            return false
        end
    end

    if _func ~= replfn then
        if noraw then
            tbl[name] = replfn
        else
            rawset(tbl, name, replfn)
        end
    end

    return _func, replfn
end

-- A wrapper function for AddFunctionPostCall for global functions
function PEARL.AddGlobalFunctionPostCall(name, postcb)
    -- Use _G override functions in the game's environment
    local _, repl = PEARL.AddFunctionPostCall(name, postcb, _G)

    -- Sync with mod's global environment since the reference there still refers to
    -- the origin.
    PEARL.OverrideVariable(name, repl)
end

-- A wrapper function for AddFunctionPreCall for global functions
function PEARL.AddGlobalFunctionPreCall(name, precb)
    -- Use _G override functions in the game's environment
    local _, repl = PEARL.AddFunctionPreCall(name, precb, _G)

    -- Sync with mod's global environment since the reference there still refers to
    -- the origin.
    PEARL.OverrideVariable(name, repl)
end

-- function PEARL.AddUpValueFunctionPreCall(name, precb, filename)
--     local env = loadfile(filename)
--     if not env then
--         PEARL.error("Failed to load the file!")
--     end

--     local target_fn = UpValueHacker.GetUpvalue(env, name)
--     PEARL.AddFunctionPreCall()
-- end

function PEARL.AddClassFunctionPreCall(name, precb, class)
    class = type(class) == "string" and require(class) or class

    return PEARL.AddFunctionPreCall(name, precb, class, true)
end

function PEARL.AddClassFunctionPostCall(name, postcb, class)
    class = type(class) == "string" and require(class) or class

    return PEARL.AddFunctionPostCall(name, postcb, class, true)
end

function PEARL.AddModPostInit(fn)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddModPostInit", fn)
    end

    if type(fn) == "function" then
        table.insert(mod_post_inits, fn)
    end
end

function PEARL.AddGameLogicPreLoad(fn)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddGameLogicPreLoad", fn)
    end

    table.insert(game_logic_preloads, fn)
end

function PEARL.AddModIndexPostInit(fn)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddModIndexPostInit", fn)
    end

    return PEARL.AddClassFunctionPostCall("EndStartupSequence", fn, KnownModIndex)
end

function PEARL.AddClientPreLoad(fn, ...)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddClientPreLoad", fn)
    end

    table.insert(client_pre_loads, fn)
end

function PEARL.AddFilePreLoad(filename, fn)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddFilePreLoad", fn)
    end

    -- If the file was already loaded
    if package.loaded[filename] then
        return
    end

    if type(file_pre_loads[filename]) == "function" then
        PEARL.warn("AddFilePreLoad: Overriding pre call handler for", filename)
    end

    if not file_pre_loads[filename] then
        file_pre_loads[filename] = {}
    end

    table.insert(file_pre_loads[filename], fn)
end

function PEARL.DeferGameFileLoad(filename, seconds)
    PEARL.AddFilePreLoad(filename, function() return false end)
    PEARL.Scheduler:ExecuteInTime(seconds, require, nil, filename)
end

function PEARL.AddMetaMethodPostCall(name, tbl, postcb)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddMetaMethodPostCall", name, tbl, postcb)
    end

    -- Do not allow overriding the _G's metamethods because it will break strict.lua!
    assert(tbl == _G, "Attempted to override metamethods of the global table!")

    local metatable = getmetatable(tbl) or {}
    local fn = rawget(metatable, name)
    rawset(metatable, name, function(...)
        fn(...)

        postcb(...)
    end)

    setmetatable(tbl, metatable)
end

function PEARL.AddWorldPostInit(fn, ...)
    return PEARL.AddPrefabPostInit("world", fn, ...)
end

-- TheFrontEnd is avaible when this is being called.
function PEARL.AddFrontEndPostInit(postfn, ...)
    return PEARL.AddGlobalClassPostConstruct("frontend", "FrontEnd", function(FE, ...)
        if not TheFrontEnd then
            PEARL.OverrideVariable("TheFrontEnd", FE, _G)
        end

        postfn(...)
    end, ...)
end

function PEARL.AddGlobalVariablePostAssign(name, postcb)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddGlobalVariablePostAssign", name, postcb)
    end

    if not global_var_postassigns[name] then
        global_var_postassigns[name] = {}
    end

    table.insert(global_var_postassigns[name], postcb)
end

function PEARL.AddFrontEndPreInit(precb)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddFrontEndPreInit", precb)
    end

    if not frontend_preinits then
        frontend_preinits = {}
    end

    table.insert(frontend_preinits, precb)
end

function PEARL.AddGlobalClassPreConstruct(filename, classname, precb)
    require(filename)
	local classdef = rawget(_G, classname)
	if classdef == nil then
		classdef = require(filename)
	end

	assert(type(classdef) == "table", "Class '"..classname.."' wasn't loaded to global from '"..filename.."'.")

    PEARL.AddClassFunctionPreCall("_ctor", precb, classdef)
end

----------------------------------
-- Overriders
----------------------------------

--- Overrides a global from the main game's environment.
--- Use with care.
function PEARL.OverrideVariable(name, value, tbl, optional)
    tbl = tbl or _G

    local origin = rawget(tbl, name)
    if origin ~= nil and optional then
        return
    end

    if PEARL.CONFIG.DEBUG_MODE and origin ~= nil then
        PEARL.debug("Overriding global "..name.." ("..tostring(origin)..") with "..tostring(value))
    end

    return rawset(tbl, name, value)
end

----------------------------------
-- Initializers
----------------------------------

function PEARL.SafeModTableExtend(name, init_val, replace)
    local tbl = rawget(PEARL, name)
    if not tbl then
        return rawset(PEARL, name, init_val or {})
    end

    if type(init_val) ~= "table" then
        return
    end

    for k, v in pairs(init_val) do
        if replace or tbl[k] == nil then
            tbl[k] = v
        end
    end
end

----------------------------------
-- UI
----------------------------------

function PEARL.AddNetworkDisconnectPopupStrings(id, title, body)
    if type(id) == "string" and type(title) ~= "string" and type(body) ~= "string" then
        return
    end

    rawset(STRINGS.UI.NETWORKDISCONNECT.TITLE, id, title)
    rawset(STRINGS.UI.NETWORKDISCONNECT.BODY, id, body)

    if PEARL.POPUPS ~= "table" then
        PEARL.POPUPS = {}
    end

    PEARL.POPUPS[id] = id
end

----------------------------------
-- API Handlers
----------------------------------

function PEARL.OnModPostInit(...)
    for _, fn in ipairs(mod_post_inits) do
        fn(...)
    end
end

-- PEARL.AddClassFunctionPreCall("Load", function(...)
--     local result
--     for _, fn in ipairs(client_pre_loads) do
--         if fn(...) == false then
--             result = false
--         end
--     end

--     return result
-- end, Profile)

PEARL.AddGlobalFunctionPreCall("require", function(name)
    if package.loaded[name] or not file_pre_loads[name] then
        return
    end

    local result = true
    for _, cb in ipairs(file_pre_loads[name]) do
        if cb() == false then
            result = false
        end
    end

    return result
end)

PEARL.AddFilePreLoad("gamelogic", function()
    local result = true
    for _, cb in ipairs(game_logic_preloads) do
        if cb() == false then
            result = false
        end
    end

    return result
end)

PEARL.AddGlobalClassPreConstruct("frontend", "FrontEnd", function(...)
    if TheFrontEnd then
        return false
    end

    local result = true
    for _, cb in ipairs(frontend_preinits) do
        if cb(...) == false then
            result = false
        end
    end

    return result
end)

--- Do not use because of strict.lua!
-- Called when a value is assigned to the global table's field but only if the
-- field had no value assigned before - referenced to nil.
-- PEARL.AddMetaMethodPostCall("__newindex", _G, function(self, name, value)
--     PEARL.info("NEW INDEX", name, value)
--     if not global_var_postassigns or not global_var_postassigns[name] then
--         return
--     end

--     for _, postcb in ipairs(global_var_postassigns[name]) do
--         postcb(value)
--     end
-- end)

--------------------------------
-- [[ Frontend Stuff ]]
--------------------------------

function PEARL.AddAnnouncementCategory(name, icon)
    assert(ANNOUNCEMENT_ICONS, "ANNOUNCEMENT_ICONS is nil!")

    if icon then
        ANNOUNCEMENT_ICONS[name] = {
            atlas = "images/announcements.xml", texture = icon
        }
    end

    if not PEARL.CONSTS.ANNOUNCEMENT_TYPES then
        PEARL.CONSTS.ANNOUNCEMENT_TYPES = {}
    end

    PEARL.CONSTS.ANNOUNCEMENT_TYPES[string.upper(name)] = name
end

--------------------------------
-- [[ Logging ]]
--------------------------------

--- Similiar to TheNet:Announce but determines using the type
--- whether to send the message to the game as well
--- or just to discord (according to the configurations).
---
---@param message string The content text of the announcement (supports multiline).
---@param tp string? The type of the announcement, see PEARL.CONSTS.ANNOUNCEMENT_TYPES.
---@param entity? unknown The entity the announcement is about.
---@param ... any Additional arguments to the TheNet:Announce function.
function PEARL.AnnounceWithType(message, tp, entity, ...)
    local enabled = PEARL.CONFIG.ANNOUNCEMENTS.default or true
    -- Everything overrides the default value
    if type(PEARL.CONFIG.ANNOUNCEMENTS[tp]) == "boolean" then
        enabled = PEARL.CONFIG.ANNOUNCEMENTS[tp]
    end

    -- The all config overrides everything
    if type(PEARL.CONFIG.ANNOUNCEMENTS.all) == "boolean" then
        enabled = PEARL.CONFIG.ANNOUNCEMENTS.all
    end

    if type(ANNOUNCEMENT_ICONS[tp]) ~= "table" then
        tp = "default"
    end

    -- Check for explicit false so by default is everything enabled.
    if enabled ~= false then
        -- When we announce the message it will be logged to discord implicitly.
        return TheNet:Announce(message, entity, nil, tp, ...)
    end

    PEARL.DiscordLogger:LogString(message, PEARL.ICONS.ANNOUNCEMENTS[tp])
end

--------------------------------
-- [[ Mod's Internal State ]]
--------------------------------

function PEARL.IsShuttingDown()
    return PEARL.__shutting_down == true
end

function PEARL.ModShutdown(...)
    if PEARL.IsShuttingDown() then
        return
    end

    PEARL.__shutting_down = true

    PEARL.info("Shutting down the mod and all it's components...")

    PEARL.EventProcessor:HandleEvent("quit", ...)
end
