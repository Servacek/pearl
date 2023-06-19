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
    We except the Master's version of the shadow container to be the main one
    and also the most updated one, since that's where most of the activity will be.

    Openers were limited to 1 in order to prevent any duplication bugs and reduce complexity.
    This allows us to handle the synchronization a lot better since we do not have to handle
    all the rare cases and combinations that come up with multiple openers.

    The main idea of synchronizing things efficiently is by making the Master shard
    always synchronized and up-to-date while other shards will be synchronized after
    their container is opened.

    Active shard is a shard where at least one player is observing the container.

    TODO:
        - Remove all environmental modifiers for food in the shadow container.

    Notes:
        - Netvars similiar to RPCs work only when the simulation is running.
        - Netvars can only be modified by the master shard.
        - Shards do not support networked entities as clients do. net_entity will
            not replicate on slave shards but the event will be pushed accordingly.
        - In order to use inter shard netvars entity needs to have ShardNetwork.
--]]

--------------------------------
-- [[ Constants ]]
--------------------------------

STRINGS.CHARACTERS.WAXWELL.ACTIONFAIL.USEMAGICTOOL = STRINGS.CHARACTERS.WAXWELL.ACTIONFAIL.USEMAGICTOOL or {}
STRINGS.CHARACTERS.WAXWELL.ACTIONFAIL.USEMAGICTOOL.INUSE = "Ugh! Someone is already looking inside."

local MAGICIAN_CONTAINERS = {
    ["magician_chest"] = true,
    ["tophat"] = true,
    ["chester"] = true,
}

--------------------------------
-- [[ Private Variables ]]
--------------------------------

PEARL._sdc = nil
local _ismastershard = TheNet:GetIsMasterSimulation() and TheShard:IsMaster()

-- Those are inner state flags that should be modified only from inside.
PEARL._replicated = false -- Whether the shard's items are unique or replicated from Master
PEARL._uptodate = false
PEARL._modified = false

local _opener_queue
if _ismastershard then
    PEARL._uptodate_shards = {}
else
    _opener_queue = {}
end

-- Flag for ignoring events sent during internal data changes.
local _handling = false

function PEARL.display()
    table.foreach(PEARL._sdc:ReferenceAllItems(), print)
end

--------------------------------
-- [[ Private Functions ]]
--------------------------------

local function _ShowContainer(doer)
    return PEARL._sdc.inst.replica and PEARL._sdc.inst.replica.container
    and PEARL._sdc.inst.replica.container:AddOpener(doer)
end

local function _HideContainer(doer)
    return PEARL._sdc.inst.replica and PEARL._sdc.inst.replica.container
    and PEARL._sdc.inst.replica.container:RemoveOpener(doer)
end

local function _GetItemReplicationData(item)
    local data = item:GetSaveRecord()

    -- Clear some unnecessary stuff to save some bytes.
    data.y = nil -- defaults to 0
    data.x = nil -- defaults to 0
    data.z = nil -- defaults to 0

    return data
end

local function _GetAllItemsReplicationData()
    local items = {}

    for slot = 1, PEARL._sdc.numslots do
        if PEARL._sdc.slots[slot] then
            items[slot] = _GetItemReplicationData(PEARL._sdc.slots[slot])
        end
    end

    return items
end

local function _GetSyncData()
    return ZipAndEncodeString(
        _GetAllItemsReplicationData()
    )
end

local function _SendSyncDataTo(shardid)
    print("SEND SYNC DATA TO", shardid)
    PEARL.SendRPCToShard(
        PEARL.RPC.SDC_Sync, shardid, _GetSyncData()
    )
end

local function _HandleOpenerQueue()
    for i = #_opener_queue, 1, -1 do
        local opener = _opener_queue[i]
        if type(opener) == "table" and opener:IsValid() then
            _ShowContainer(opener)
        end

        _opener_queue[i] = nil
    end
end

local function _SwitchToGlobalShardProxy(pos)
    -- Maybe not the most ideal solution but should be enought for now.
    PEARL._sdc:DropEverything(pos)
    PEARL._replicated = true
end

local function _ReplicateItems(items)
    for slot = 1, PEARL._sdc.numslots do
        if items[slot] then
            local inst = SpawnSaveRecord(items[slot])
            if inst then
                PEARL._sdc:GiveItem(inst, slot)
            else
                PEARL.error("Failed to replicate item entity! Data:", DataDumper(items[slot]))
            end
        end
    end
end

local function _UnsyncShards(except)
    print("_UnsyncInactiveShards")

    local shards = PEARL.ServerNetwork:GetConnectedShardIDs()
    if IsTableEmpty(shards) then
        return print("NO SHARDS CONNECTED - IGNORING")
    end

    except = tostring(except)
    for _, shardid in ipairs(shards) do
        shardid = tostring(shardid)
        if shardid ~= except and PEARL._uptodate_shards[shardid] then
            PEARL._uptodate_shards[shardid] = nil

            PEARL.SendRPCToShard(shardid, PEARL.RPC.SDC_UpToDate)
        end
    end
end

local function _HandleSyncData(shardid, data)
    local items = DecodeAndUnzipString(data)
    if type(items) ~= "table" then
        return error("String decoding failed!")
    end

    -- An empty container is totally valid!
    -- if IsTableEmpty(items) then
    --     return error("Invalid data received")
    -- end

    print("RECEIVED FROM ", shardid, DataDumper(items))

    _handling = true

    -- Set this before adding the items.
    PEARL._uptodate = true
    PEARL._sdc:DestroyContents()
    _ReplicateItems(items)

    if _ismastershard then
        _UnsyncShards(shardid)
    else
        -- PEARL._sdc.inst.replica.container.classified.Network:SetClassifiedTarget(doer)
        -- We have updated the server-side data, now show the container to the client.
        -- Unfortunately, this won't prevent the ocassional flickering :/
        _HandleOpenerQueue()
    end
    _handling = false
end

local function _CanOpenPocket()
    return (
        not (PEARL._sdc._netopened and PEARL._sdc._netopened:value()) or
        PEARL._sdc:IsOpen() -- If the container is already open on this shard
    )
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

-- Called for itemget, stacksizechange and itemlose events.
local function oncontentchanged()
    print("oncontentchanged")
    if _handling or POPULATING then
        return
    end

    if _ismastershard then
        _UnsyncShards()
    else
        PEARL._modified = true
    end
end

--------------------------------
-- [[ Slave Event Handlers ]]
--------------------------------

local function onopen(inst, data)
    print("onopen")

    PEARL._modified = false

    PEARL._sdc._netopened:set(true)
    PEARL._sdc._netopened:set_local(true)
    if not _ismastershard then
        PEARL.SendRPCToMaster(PEARL.RPC.SDC_OnOpen)

        -- We except replication at this point.
        -- So prepare for it!
        if not PEARL._uptodate then
            local doer = data and data.doer

            _handling = true

            -- We do not have to worry about item overriding
            -- on the Master shard because it's content will
            -- always be synced with the slave shard upon opening.
            if not PEARL._replicated then
                _SwitchToGlobalShardProxy(doer and doer:GetPosition())
            end

            PEARL._sdc:DestroyContents()

            _handling = false
        end
    end
end

-- Called when all the openers close the container
local function onclose()
    print("onclose")

    PEARL._sdc._netopened:set(false)
    PEARL._sdc._netopened:set_local(false)

    if not _ismastershard then
        local data
        if PEARL._modified and not PEARL._sdc:IsEmpty() then
            data = _GetSyncData()
        end

        PEARL.SendRPCToMaster(PEARL.RPC.SDC_OnClose, data)
    end

    PEARL._modified = false
end

--------------------------------
-- [[ Slave RPC Handlers ]]
--------------------------------

PEARL.AddShardRPCHandler("SDC_Sync", _HandleSyncData)

PEARL.AddShardRPCHandler("SDC_UpToDate", function(shardid, uptodate)
    PEARL._uptodate = (uptodate or false)

    -- We have been unsyced so close the container.
    if not PEARL._uptodate and PEARL._sdc:IsOpen() then
        PEARL._sdc:Close()
    end
end)

--------------------------------
-- [[ Master RPC Handlers ]]
--------------------------------

-- This should be only called when a container is opened for the first time.
PEARL.AddShardRPCHandler("SDC_OnOpen", function(shardid)
    print("SDC_OnOpen")
    PEARL._sdc._netopened:set(true)

    shardid = tostring(shardid)
    if not PEARL._uptodate_shards[shardid] then
        -- Prevent multiple sync requests
        PEARL._uptodate_shards[shardid] = true
        _SendSyncDataTo(shardid)
    end
end)

-- This should be called after all openers close the container.
PEARL.AddShardRPCHandler("SDC_OnClose", function(shardid, data)
    print("SDC_OnClose")
    PEARL._sdc._netopened:set(false)

    if type(data) == "string" then
        _HandleSyncData(shardid, data)
    end
end)

--------------------------------
-- [[ Prefab Post Init ]]
--------------------------------

PEARL.AddPrefabPostInit("shadow_container", function(inst)
    if (not TheWorld or TheWorld.ismastersim ~= true) then
        return
    end

    if not (inst.components.container) then
        return error("Missing container component!")
    end

    -- Required for netvar inter-shard communication
    inst.entity:AddShardNetwork()

    PEARL._sdc = inst.components.container
    -- A net boolean that determines whether the container is opened on a shard already or not.
    PEARL._sdc._netopened = net_bool(inst.GUID, "__"..PEARL.MODNAME.."_shardcontainer_netopened__")

    local _CanOpen = PEARL._sdc.CanOpen
    PEARL._sdc.CanOpen = function(...)
        return _CanOpenPocket() and _CanOpen(...)
    end

    -- Register custom load/save handlers for slave shards.
    if not _ismastershard then
        local _GiveItem = PEARL._sdc.GiveItem
        PEARL._sdc.GiveItem = function(...)
            -- Do not accept items if we are not up-to-date.
            -- This is mainly here for the STORE action,
            if PEARL._sdc:IsOpen() and not PEARL._uptodate then
                return false
            end

            return _GiveItem(...)
        end

        local _Open = PEARL._sdc.Open
        PEARL._sdc.Open = function(self, doer, ...)
            if not _CanOpenPocket() then
                return false
            end

            _Open(self, doer, ...)

            if not PEARL._uptodate then
                -- Hide the container's HUD until we are ready!
                _HideContainer(doer)

                _opener_queue[#_opener_queue+1] = doer
            end
        end

        -- TODO:
        local _OnLoad = PEARL._sdc.OnLoad
        PEARL._sdc.OnLoad = function(self, data, ...)
            print("ONLOAD POST PASS")
            if type(data) == "table" and type(data._replicated) == "boolean" then
                PEARL._replicated = data._replicated
            end

            return _OnLoad and _OnLoad(self, data, ...)
        end

        local _OnSave = PEARL._sdc.OnSave
        PEARL._sdc.OnSave = function(...)
            print("ONSAVE")

            -- Do not save normally if we were replicated from Master shard.
            -- This is to prevent item duplication when turning this mod off.
            local data = (not PEARL._replicated and _OnSave) and _OnSave(...) or nil
            if PEARL._replicated then
                data = data or {}
                data._replicated = PEARL._replicated
            end

            return data
        end
    end

    -- Use these instead of the events because these
    -- are called only on the first and last opener.
    local _onopenfn = PEARL._sdc.onopenfn
    PEARL._sdc.onopenfn = function(...)
        onopen(...)

        if type(_onopenfn) == "function" then
            return _onopenfn(...)
        end
    end

    local _onclosefn = PEARL._sdc.onclosefn
    PEARL._sdc.onclosefn = function(...)
        onclose()

        if type(_onclosefn) == "function" then
            return _onclosefn(...)
        end
    end

    inst:SafeListenForEvent("itemget", oncontentchanged)
    inst:SafeListenForEvent("stacksizechange", oncontentchanged)
    inst:SafeListenForEvent("itemlose", oncontentchanged)
end)

--------------------------------
-- [[ Action Handlers ]]
--------------------------------

local _USEMAGICTOOL = ACTIONS.USEMAGICTOOL.fn
ACTIONS.USEMAGICTOOL.fn = function(act, ...)
    if act.invobject and MAGICIAN_CONTAINERS[act.invobject.prefab] then
        if not _CanOpenPocket() then
            return false, "INUSE"
        end
    end

    return _USEMAGICTOOL(act, ...)
end
