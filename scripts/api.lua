--[[
    Additional API helper functions. This is basically just
    an extension to modindex.lua's environment functions.
--]]

local mod_post_inits = {}
local file_post_loads = {}
local client_pre_loads = {}

----------------------------------
-- Function Pre/Post call adders
----------------------------------

-- Overrides the given func with a function that calls func first,
-- stores it's result(s) and then calls postcb with the result as the first argument.
-- This function returns the return value(s) of postcb.
function PEARL.AddFunctionPostCall(name, postcb, tbl, noraw)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddFunctionPostCall", name, postcb, tbl)
    end

    if not (type(name) == "string" and type(postcb) == "function") then
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
            return postcb({_func(...)}, ...)
        end
    end


    if noraw then
        tbl[name] = postfn
    else
        rawset(tbl, name, postfn)
    end
end

-- Similiar to 'AddGlobalFunctionPostCall' but calls precb before func suppling
-- all the arguments. The return value of func is not changed but you can prevent
-- the executioon of the original function by returning false.
--
-- Note: This function does not require the function to be declared in the given table.
function PEARL.AddFunctionPreCall(name, precb, tbl, noraw)
    if KnownModIndex:IsModInitPrintEnabled() then
        PEARL.info("AddFunctionPreCall", name, precb, tbl)
    end

    if not (type(name) == "string" and type(precb) == "function") then
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

    if noraw then
        tbl[name] = replfn
    else
        rawset(tbl, name, replfn)
    end

    return _func
end

-- A wrapper function for AddFunctionPostCall for global functions
function PEARL.AddGlobalFunctionPostCall(name, postcb)
    -- Use _G instead of GLOBAL so this can override even mod specific globals
    return PEARL.AddFunctionPostCall(name, postcb, _G)
end

-- A wrapper function for AddFunctionPreCall for global functions
function PEARL.AddGlobalFunctionPreCall(name, precb)
    -- Use _G instead of GLOBAL so this can override even mod specific globals
    return PEARL.AddFunctionPreCall(name, precb, _G)
end

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

function PEARL.AddModIndexPostInit(fn)
    PEARL.info("AddModIndexPostInit", fn)

    return PEARL.AddClassFunctionPostCall("EndStartupSequence", fn, KnownModIndex)
end

function PEARL.AddClientPreLoad(fn, ...)
    table.insert(client_pre_loads, fn)
end

function PEARL.AddFilePreLoad(filename, fn)
    if type(file_post_loads[filename]) == "function" then
        PEARL.warn("AddFilePreLoad: Overriding pre call handler for", filename)
    end

    file_post_loads[filename] = fn
end

function PEARL.AddWorldPostInit(fn, ...)
    return AddPrefabPostInit("world", fn, ...)
end

----------------------------------
-- Overriders
----------------------------------

--- Overrides a global from the main game's environment.
--- Use with care.
function PEARL.OverrideGlobal(name, value)
    if PEARL.CONFIG.DEBUG_MODE then
        local old_v = rawget(_G, name)
        PEARL.warn("Overriding global "..name.." ("..tostring(old_v)..") with "..tostring(value))
    end

    return rawset(_G, name, value)
end

----------------------------------
-- Initializers
----------------------------------

function PEARL.ModTableSafeAppend(name, init_val)
    local tbl = rawget(PEARL, name)
    if not tbl then
        return rawset(PEARL, name, init_val or {})
    end

    if type(init_val) ~= "table" then
        return
    end

    for k, v in pairs(init_val) do
        if tbl[k] == nil then
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

PEARL.AddClassFunctionPreCall("Load", function(...)
    local result
    for _, fn in ipairs(client_pre_loads) do
        if fn(...) == false then
            result = false
        end
    end

    return result
end, Profile)

--------------------------------
-- [[ Frontend Stuff ]]
--------------------------------

function PEARL.AddAnnouncementCategory(name, icon, enabled)
    assert(ANNOUNCEMENT_ICONS, "ANNOUNCEMENT_ICONS is nil!")

    ANNOUNCEMENT_ICONS[name] = {
        atlas = "images/announcements.xml", texture = icon
    }

    if not PEARL.CONFIG.ANNS then
        PEARL.CONFIG.ANNS = {}
    end

    if not PEARL.CONSTS.ANNOUNCEMENT_TYPES then
        PEARL.CONSTS.ANNOUNCEMENT_TYPES = {}
    end

    PEARL.CONFIG.ANNS[string.lower(name)] = enabled
    PEARL.CONFIG.ANNS[string.upper(name)] = enabled
    PEARL.CONSTS.ANNOUNCEMENT_TYPES[string.upper(name)] = name
end

--------------------------------
-- [[ Logging ]]
--------------------------------

--- @TODO figure out what is the third param for TheNet:Announce.
function PEARL.Announce(message, type, entity, ...)
    --print("ANNOUNCE", message)
    if PEARL.CONFIG.ANNS[type] then
        return TheNet:Announce(message, entity, nil, type, ...)
    end

    PEARL.Logger:LogString(message, PEARL.ICONS.ANNOUNCEMENTS[type])
end
