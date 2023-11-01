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
    A nice convinience wrapper class for the netvars API.
    It's goal is to provide a well documented and robust API.
--]]

---------------------------
-- [[ Constants ]]
---------------------------

local EVENT_PATTERN = "on_%s_changed"

RegisterSinglePrefab(Prefab("pearl_mod_network", function()
    local inst = CreateEntity()
    inst.entity:AddNetworkProxy()

    return inst
end))

TheSim:LoadPrefabs({"pearl_mod_network"})

local _netinst = SpawnPrefab("pearl_mod_network")
table.insert(ModManager.loadedprefabs, _netinst.name)
print(_netinst, _netinst:IsValid())

---------------------------
-- [[ Class Declaration ]]
---------------------------

--- @class Netvars
local Netvars = {}

---------------------------
-- [[ Static ]]
---------------------------

--- @type table<string, fun(GUID: number, name: string, event: string): userdata>
Netvars.TYPE = {
    BOOL            = net_bool,             -- maps to a single bit boolean
    TINYBYTE        = net_tinybyte,         -- maps to an unsigned 3-bit integer
    SMALLBYTE       = net_smallbyte,        -- maps to an unsigned 6-bit integer
    BYTE            = net_byte,             -- maps to an unsigned 8-bit integer
    SHORTINT        = net_shortint,         -- maps to a signed 16-bit integer
    USHORTINT       = net_ushortint,        -- maps to an unsigned 16-bit integer
    INT             = net_int,              -- maps to a signed 32-bit integer
    UINT            = net_uint,             -- maps to an unsigned 32-bit integer
    FLOAT           = net_float,            -- maps to a 32-bit float

    STRING          = net_string,           -- maps to a string of variable length
    HASH            = net_hash,             -- maps to a unsigned 32-bit integer hash of the string assigned
    ENTITY          = net_entity,           -- maps to an unsigned 64-bit integer containing the network id of the entity instance that is assigned
    BYTEARRAY       = net_bytearray,        -- maps to an array of unsigned 8-bit integers
    SMALLBYTEARRAY  = net_smallbytearray,   -- maps to an array of unsigned 6-bit integers
}

---------------------------
-- [[ Local Functions ]]
---------------------------

local function GetEventFor(name)
    return EVENT_PATTERN:format(name)
end

---------------------------
-- [[ Public Functions ]]
---------------------------

--- Registers a netvar for an entity. Note that netvars cannot be unregistered.
--- @param name string Name of the netvar to be registered.
--- @param nettype fun(GUID: number, name: string, event: string): userdata Type of the netvar to be registered.
--- @param onsetfn fun(new: any)? Function to be called when this netvar is changed.
--- @param inst EntityScript? The entity to register the netvar for or nil for the default entity.
--- @return userdata netvar
function Netvars:Register(name, nettype, onsetfn, inst)
    PEARL.debug("Netvars:Register", name, onsetfn)

    assert(table.contains(Netvars.TYPE, nettype), "Attempted to create a netvar with an invalid type.")

    local event = GetEventFor(name)
    inst = inst or _netinst
    local netvar = nettype(inst.GUID, name, event)

    if type(onsetfn) == "function" then
        inst:ListenForEvent(event, function()
            print("CALLBACK!!")
            onsetfn(netvar:value())
        end)
    end

    return netvar --{set = function() end, value = function() end, set_local = function() end}
end

---------------------------
-- [[ Return ]]
---------------------------

return Netvars
