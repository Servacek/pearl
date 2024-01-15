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
    Additional API helper functions. This is basically just
    an extension to modindex.lua's environment functions.
--]]

----------------------------------
-- Global Localization
----------------------------------

local unpack = unpack

----------------------------------
-- Constants
----------------------------------

local MOD_PREFAB_PT = PEARL.MODNAME.."_%s"

----------------------------------
-- Locals
----------------------------------

local file_pre_loads = {}
local frontend_preinits = {}
local prefab_post_registers = {}

local usercommand_pre_inits = {}

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

--- @param t table The lookup table for the value.
--- @param name string The name of the table field holding the value.
--- @param noraw boolean? Whether we should call the table's metamethods when looking up the value or not.
function PEARL.GetValue(t, name, noraw)
    return noraw and t[name] or rawget(t, name)
end

function PEARL.SetValue(t, name, value, noraw)
    if noraw then
        t[name] = value
        return t
    end

    return rawset(t, name, value)
end

--- @return any origin, any new
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

--- Use ALWAYS noraw for Class Methods!!!!
--- @param func fun(old_ret: any, ...: any): any
--- @return any origin
function PEARL.OverrideReturnValue(t, funcname, func, noraw, optional)
    local origin
    origin = PEARL.OverrideValue(t, funcname, function(...)
        local old_ret = (type(origin) == "function") and origin(...) or nil
        return func(old_ret, ...) or (optional and old_ret or nil)
    end, noraw)
end

--- @param overridefn fun(old_ret: any, ...: any): any
--- @return function? origin
function PEARL.OverrideMethodReturnValue(class, methodname, overridefn, optional)
    return PEARL.OverrideReturnValue(class, methodname, overridefn, true, optional)
end

function PEARL.OverrideUserdataFnReturn(userdata, funcname, overridefn, noraw, optional)
    local mt = getmetatable(userdata)
    assert(type(mt) == "table" and type(mt.__index) == "table", "invalid userdata provided")

    return PEARL.OverrideReturnValue(mt.__index, funcname, overridefn, noraw, optional)
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
function PEARL.AddGlobalFunctionPostCall(name, postcb, ignoremodenv)
    -- Override in the global environment
    local origin, repl = PEARL.AddFunctionPostCall(name, postcb, _G)

    -- Sync with mod's global environment since the reference there still refers to
    -- the origin.
    if not ignoremodenv then
        PEARL.OverrideVariable(name, repl, PEARL.ENV)
    end

    return origin
end

-- A wrapper function for AddFunctionPreCall for global functions
function PEARL.AddGlobalFunctionPreCall(name, precb, ignoremodenv)
    -- Override in the global environment
    local origin, repl = PEARL.AddFunctionPreCall(name, precb, _G)

    -- Sync with mod's global environment since the reference there still refers to
    -- the origin.
    if not ignoremodenv then
        PEARL.OverrideVariable(name, repl, PEARL.ENV)
    end

    return origin
end

function PEARL.AddRPCHandlerPreCall(name, precb)
    local handlers = PEARL.GetDefaultRPCHandlers()
    if type(handlers[name]) ~= "function" then
        return error("Invalid RPC handler", name);
    end

    return PEARL.AddClassFunctionPreCall(name, precb, handlers)
end

--- @param class table
function PEARL.AddClassFunctionPreCall(name, precb, class)
    PEARL.debug("PEARL.AddClassFunctionPreCall", name, class)

    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    return PEARL.AddFunctionPreCall(name, precb, class, true)
end

--- @param class table
function PEARL.AddClassFunctionPostCall(name, postcb, class, with_res)
    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    return PEARL.AddFunctionPostCall(name, postcb, class, with_res, true)
end

--- @param class table
function PEARL.AddClassAttrPostSet(attrname, postcb, class)
    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    local attrs = rawget(class, "_")
    if table.empty(attrs) ~= false then
        return error("Class has no attribute setters!")
    end

    return PEARL.AddFunctionPostCall(2, postcb, attrs[attrname])
end

--- @param userdata userdata
function PEARL.AddUserDataFunctionPreCall(name, precb, userdata)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddUserDataFunctionPreCall", precb, userdata)
    end

    local mt = getmetatable(userdata)
    assert(type(mt) == "table" and type(mt.__index) == "table", "invalid userdata provided")

    return PEARL.AddFunctionPreCall(name, precb, mt.__index)
end

--- @param userdata userdata
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

function PEARL.AddUserCommandPreInit(name, postcb)
    if not usercommand_pre_inits[name] then
        usercommand_pre_inits[name] = {}
    end

    table.insert(usercommand_pre_inits[name], postcb)
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

--- For networking between servers
function PEARL.AddShardNetworkPostInit(fn, ...)
    return PEARL.AddPrefabPostInit("shard_network", fn, ...)
end

--- For networking between server and client.
function PEARL.AddWorldNetworkPostInit(fn, ...)
    PEARL.AddPrefabPostInit("cave_network", fn, ...)
    PEARL.AddPrefabPostInit("forest_network", fn, ...)
end

-- TheFrontEnd is avaible when this is being called.
function PEARL.AddFrontEndPostInit(postfn, ...)
    return PEARL.AddGlobalClassPostConstruct("frontend", "FrontEnd", function(FE, ...)
        if not TheFrontEnd then
            PEARL.OverrideVariable("TheFrontEnd", FE, _G)
        end

        postfn(FE, ...)
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

function PEARL.AddClassPreConstruct(filename, classname, precb)
    require(filename)

	local classdef = rawget(_G, classname)
	if not classdef then
		classdef = require(filename)
	end

	assert(type(classdef) == "table", "Class '"..tostring(classname).."' wasn't loaded to global from '"..filename.."'.")

    PEARL.AddClassFunctionPreCall("_ctor", precb, classdef)
end

----------------------------------
-- Overriders
----------------------------------

--- @return nil
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

--- Overrides a global from the main game's environment.
--- Use with care.
--- @return nil
function PEARL.OverrideGlobalVariable(name, value, optional)
    PEARL.OverrideVariable(name, value, _G, optional)
    PEARL.OverrideVariable(name, value, PEARL.ENV, optional)
end

--- @return any origin, any new
function PEARL.OverrideUserdataValue(name, value, userdata)
    local mt = type(userdata) == "userdata" and getmetatable(userdata) or nil
    assert(type(mt) == "table" and type(mt.__index) == "table", "invalid userdata provided")

    return PEARL.OverrideValue(mt.__index, name, value)
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

function PEARL.ModPrefab(prefab, ...)
    return Prefab(MOD_PREFAB_PT:format(prefab), ...)
end

function PEARL.SpawnModPrefab(prefab, ...)
    return SpawnPrefab(MOD_PREFAB_PT:format(prefab), ...)
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
end

----------------------------------
-- Safety
----------------------------------

PEARL.AddPrefabPostInit = function(...) PEARL.SafeRun(PEARL.ENV.AddPrefabPostInit, ...) end
PEARL.AddComponentPostInit = function(...) PEARL.SafeRun(PEARL.ENV.AddComponentPostInit, ...) end
PEARL.AddClassPostConstruct = function(...) PEARL.SafeRun(PEARL.ENV.AddClassPostConstruct, ...) end
PEARL.AddGamePostInit = function(...) PEARL.SafeRun(PEARL.ENV.AddGamePostInit, ...) end
PEARL.AddSimPostInit = function(...) PEARL.SafeRun(PEARL.ENV.AddSimPostInit, ...) end

----------------------------------
-- API Handlers
----------------------------------

PEARL.AddGlobalFunctionPreCall("AddUserCommand", function(name, ...)
    if not usercommand_pre_inits[name] then
        return
    end

    local pre_inits = usercommand_pre_inits[name]
    usercommand_pre_inits[name] = nil
    for _, fn in ipairs(pre_inits) do
        fn(...)
    end
end)

PEARL.AddGlobalFunctionPostCall("RegisterPrefabsImpl", function(inst)
    if not inst or not prefab_post_registers[inst.name] then
        return
    end

    for _, fn in ipairs(prefab_post_registers[inst.name]) do
        fn(inst)
    end
end)

PEARL.AddClassPreConstruct("frontend", "FrontEnd", function(...)
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

function PEARL.RegisterAnnouncementType(type)
    if not PEARL.CONSTS.ANN_TYPE then
        PEARL.CONSTS.ANN_TYPE = {}
    end

    PEARL.CONSTS.ANN_TYPE[string.upper(type)] = type
end

function PEARL.RegisterDefaultAnnouncementTypes()
    for type, _ in pairs(ANNOUNCEMENT_ICONS) do
        PEARL.RegisterAnnouncementType(type)
    end
end

function PEARL.AddAnnouncementIcon(name, icon)
    assert(ANNOUNCEMENT_ICONS, "ANNOUNCEMENT_ICONS is nil!")
    assert(ANNOUNCEMENT_ICONS[name] == nil, "ANNOUNCEMENT ICON already exists for type "..name)

    if icon then
        ANNOUNCEMENT_ICONS[name] = {
            atlas = "images/announcement_icons.xml", texture = icon
        }
    end

    PEARL.RegisterAnnouncementType(name)
end

function PEARL.RemoveDefaultLoadingTips()
    PEARL.debug("PEARL.RemoveAllLoadingTips")

    for _, tv in pairs(PEARL.CONSTS.LT_TYPE_TABLES) do
        cleartable(tv)
    end
end

--------------------------------
-- [[ Logging ]]
--------------------------------

--- Similiar to TheNet:Announce but determines using the type
--- whether to send the message to the game as well
--- or just to discord (according to the configurations).
---
---@param str string The content text of the announcement (supports multiline).
---@param tp? string The type of the announcement, see PEARL.CONSTS.ANNOUNCEMENT_TYPES.
---@param entity? unknown The entity the announcement is about.
---@param silent? boolean Whether the announcement should be sent to game or not.
---@param icon? string The specific icon for silent announcements.
function PEARL.AnnounceWithType(str, tp, entity, silent, icon, timestamp)
    tp = tp and string.lower(tp) or "default"

    local enabled = PEARL.CONFIG.ANNOUNCEMENTS.default or true
    -- Everything overrides the default value
    if type(PEARL.CONFIG.ANNOUNCEMENTS[tp]) == "boolean" then
        enabled = PEARL.CONFIG.ANNOUNCEMENTS[tp]
    end

    -- The all config overrides everything
    if type(PEARL.CONFIG.ANNOUNCEMENTS.all) == "boolean" then
        enabled = PEARL.CONFIG.ANNOUNCEMENTS.all
    end

    -- Check for explicit false so by default is everything enabled.
    if enabled ~= false and silent ~= true then
        -- If there is no UI icon for the announcement display the default one
        if type(ANNOUNCEMENT_ICONS[tp]) ~= "table" then
            tp = "default"
        end

        -- When we announce the message it will be logged to discord implicitly.
        return TheNet:Announce(str, entity, nil, tp)
    end

    icon = icon or PEARL.ICONS.ANNOUNCEMENTS[tp] or PEARL.ICONS.ANNOUNCEMENTS.default
    PEARL.DiscordLogger:LogString(str, icon)
end

--------------------------------
-- [[ Classes ]]
--------------------------------

--- @type fun(base: Class|fun(self, ...: any), _ctor: fun(self, ...: any)|table<string, fun(value)>?, props: table<string, fun(value)>?)
PEARL.Class = Class

--------------------------------
-- [[ Mod's Internal State ]]
--------------------------------

function PEARL.IsShuttingDown()
    return PEARL.__shutting_down == true
end

function PEARL.ModShutdown(...)
    if PEARL.IsShuttingDown() or PEARL.INIT then
        return
    end

    PEARL.__shutting_down = true

    PEARL.info("Shutting down the mod and all it's components...")

    PEARL.EventProcessor:HandleEvent("quit", ...)
end

function PEARL.Reboot()
    -- Keep this here so the default disconnect event wont have a chance to reach the server.
    PEARL.ServerNetwork:DisconnectAllClients(nil, true)

    --- @HACK: Crashing the server will result in automatic restart by the provider.
    --- This is an engine side crash so no reports are sent to discord.
    PEARL.warn("Shutting down with an error status code to force the provider to restart us!")
    TheSim:Crash(true)
end

-- Restarts only the shard this is called on.
function PEARL.ReloadShard()
    StartNextInstance({
        reset_action = RESET_ACTION.LOAD_SLOT,
        save_slot = ShardGameIndex:GetSlot()
    })
end

function PEARL.RegenerateShard()
    if TheWorld == nil then
        return
    end

    if TheWorld.ismastersim then
        WorldResetFromSim()
    else
        -- In case this is being called from a client.
        c_remote("c_regenerateshard()")
    end
end

-- Provides access to the original ban functions.
local _Ban, _BanForTime, _Kick = TheNet.Ban, TheNet.BanForTime, TheNet.Kick
function PEARL.Ban(userid, seconds)
    seconds = tonumber(seconds)
    if seconds then
        return _BanForTime(TheNet, userid, seconds)
    end

    return _Ban(TheNet, userid)
end

-- Provides access to the original kick function.
function PEARL.Kick(userid, seconds)
    _Kick(TheNet, userid, seconds)
end
