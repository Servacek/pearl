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

----------------------------------
-- Global Localization
----------------------------------

local unpack = unpack

----------------------------------
-- Locals
----------------------------------

local mod_post_inits = {}
local file_pre_loads = {}
local frontend_preinits = {}
local prefab_post_registers = {}

--- @TODO: Refactor these + Add support for local functions
----------------------------------
-- Function Pre/Post call adders
----------------------------------

-- Overrides the given func with a function that calls func first,
-- stores it's result(s) and then calls postcb with the result as the first argument.
-- This function returns the return value(s) of postcb.
--- @return function? wrapped The wrapped function.
local function WrapFunctionPostCall(origin, postcb, with_res)
    if not origin then
        return error("Invalid postcb target.")
    end

    if with_res then
        return function(...)
            local results = {origin(...)}
            postcb(results, ...)
            return results and unpack(results)
        end
    end

    return function(...)
        local results = {origin(...)}
        postcb(...)
        return unpack(results)
    end
end

local function WrapFunctionPreCall(origin, precb)
    return function(...)
        if precb(...) == false then
            return false
        end

        return origin and origin(...)
    end
end

function PEARL.GetValue(t, name, noraw)
    return noraw and t[name] or rawget(t or _G, name)
end

function PEARL.SetValue(t, name, value, noraw)
    if noraw then
        t[name] = value
        return t
    end

    return rawset(t, name, value)
end

function PEARL.OverrideValue(t, name, value, noraw)
    t = t or _G
    local origin = PEARL.GetValue(t, name, noraw)
    if not origin then
        PEARL.debug("Adding new index to table.", tostring(t).."["..tostring(name).."] = "..tostring(value))
    else
        PEARL.debug("Overriding value of index", origin, "->", value)
    end
    PEARL.SetValue(t, name, value, noraw)
    return origin, value
end

function PEARL.AddFunctionPreCall(name, precb, t, noraw)
    return PEARL.OverrideValue(
        t, name, WrapFunctionPreCall(PEARL.GetValue(t, name, noraw), precb), noraw
    )
end

function PEARL.AddFunctionPostCall(name, postcb, t, with_res, noraw)
    return PEARL.OverrideValue(
        t, name, WrapFunctionPostCall(PEARL.GetValue(t, name, noraw), postcb, with_res), noraw
    )
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
function PEARL.AddGlobalFunctionPreCall(name, precb, ignoremodenv)
    -- Use _G override functions in the game's environment
    local _, repl = PEARL.AddFunctionPreCall(name, precb, _G)

    -- Sync with mod's global environment since the reference there still refers to
    -- the origin.
    if not ignoremodenv then
        PEARL.OverrideVariable(name, repl)
    end
end

function PEARL.AddClassFunctionPreCall(name, precb, class)
    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    return PEARL.AddFunctionPreCall(name, precb, class, true)
end

function PEARL.AddClassFunctionPostCall(name, postcb, class, with_res)
    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    return PEARL.AddFunctionPostCall(name, postcb, class, with_res, true)
end

function PEARL.AddUserDataFunctionPreCall(name, precb, userdata)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddUserDataFunctionPreCall", precb, userdata)
    end

    local mt = getmetatable(userdata)
    assert(type(mt) == "table" and type(mt.__index) == "table", "invalid userdata provided")

    return PEARL.AddFunctionPreCall(name, precb, mt.__index)
end

function PEARL.AddUserDataFunctionPostCall(name, postcb, userdata)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddUserDataFunctionPostCall", postcb, userdata)
    end

    local mt = getmetatable(userdata)
    assert(type(mt) == "table" and type(mt.__index) == "table", "invalid userdata provided")

    return PEARL.AddFunctionPostCall(name, postcb, mt.__index)
end

function PEARL.AddPrefabPostRegister(prefab, cb)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddPrefabFilePostLoad", cb)
    end

    if not prefab_post_registers[prefab] then
        prefab_post_registers[prefab] = {}
    end

    table.insert(prefab_post_registers[prefab], cb)
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

--- WARNING: can cause a lot of nasty issues so do not use if not required!
-- function PEARL.AddMetaMethodPostCall(name, tbl, postcb)
--     if KnownModIndex:IsModInitPrintEnabled() then
--         PEARL.info("AddMetaMethodPostCall", name, tbl, postcb)
--     end

--     -- Do not allow overriding the _G's metamethods because it will break strict.lua!
--     assert(tbl == _G, "Attempted to override metamethods of the global table!")

--     local metatable = getmetatable(tbl) or {}
--     local fn = rawget(metatable, name)
--     rawset(metatable, name, function(...)
--         fn(...)

--         postcb(...)
--     end)

--     setmetatable(tbl, metatable)
-- end

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

function PEARL.GetGlobal(name)
    return rawget(_G, name)
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

PEARL.AddGlobalFunctionPostCall("RegisterPrefabsImpl", function(inst)
    if not inst or not prefab_post_registers[inst.name] then
        return
    end

    for _, fn in ipairs(prefab_post_registers[inst.name]) do
        fn(inst)
    end
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
---@param silent? boolean Whether the announcement should be sent to game or not.
---@param ... any Additional arguments to the TheNet:Announce function.
function PEARL.AnnounceWithType(message, tp, entity, silent, ...)
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
    if enabled ~= false and silent ~= true then
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
