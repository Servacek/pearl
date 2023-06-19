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

    The main idea of synchronizing things efficiently is by listening to the onopen and
    onclose events that are provided by the container component.
    If the "onopen" event happens on a secondary shard we send a sync request to the master
    shard that will synchronize it's up-to-date content with us. Otherwise, if this event
    happens on a Master shard we just ignore it because the Master shard should already be
    synchronized.

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
-- [[ Localization ]]
--------------------------------

local checkbit = checkbit
local setbit = setbit

--------------------------------
-- [[ Constants ]]
--------------------------------

local STATE_ACTIVE      = 1 -- Whether the container is opened on this shard or not
                            -- This is being managed by the shard itself.

local STATE_UPTODATE    = 2 -- Whether the shard's items are synchronized with Master's.
                            -- Master shard makes the main decisions here.

--------------------------------
-- [[ Static Variables ]]
--------------------------------

local _shardid = TheShard:GetShardId()
local _ismastershard = TheNet:GetIsMasterSimulation() and TheShard:IsMaster()

-- Flag for ignoring events sent during internal data changes.
local _handling = false

local _bindings, _states
if _ismastershard then
    --- @type table<int, Container>
    _bindings = {}
    --- @type table<int, net_tinybyte>
    -- This stores the state netvars for all individual connected shards.
    -- We do only care about the shard as a whole not about it's containers.
    _states = {}
end

--------------------------------
-- [[ Private Functions ]]
--------------------------------

local function _GetItemReplicationData(item)
    local data = item:GetSaveRecord()

    -- Clear some unnecessary stuff to save some bytes.
    data.y = nil -- defaults to 0
    data.x = nil -- defaults to 0
    data.z = nil -- defaults to 0

    return data
end

-- Called only on the master shard.
-- Synchronizes the provided shard's container with the master's version of it.
local function _SendSyncDataTo(shardid, cid)
    if (type(_bindings[cid]) ~= "table") then
        return PEARL.error("Attempted to sync with an invalid entity!")
    end

    print("SENDING SYNC DATA FROM MASTER TO SLAVE")

    _handling = true
    PEARL.SendRPCToShard(
        PEARL.RPC.SDC_Sync, shardid, cid, ZipAndEncodeString(
            _bindings[cid].components.sharditemsyncer:GetAllItemsReplicationData()
        )
    )
    _handling = false
end

local function _ReplicateItems(cid, items)
    if (type(_bindings[cid]) ~= "table") then
        return PEARL.error("Attempted to sync with an invalid entity!")
    end

    print("SYNCHRONIZING MASTER ITEM DATA")

    local container = _bindings[cid].components.container
    for slot = 1, container.numslots do
        local inst = SpawnSaveRecord(items[slot])
        if inst then
            container:GiveItem(inst, slot)
        else
            PEARL.error("Failed to replicate item entity! Data:", DataDumper(items[slot]))
        end
    end
end

-- We send a sync request to master
local function _RequestSynchronization()
    print("REQUEST SYNC FROM MASTER")

    PEARL.SendRPCToMaster(PEARL.RPC.SDC_Sync)
end

local function _SendRPCToActiveShards(rpc_id, ...)
    if (IsTableEmpty(_states)) then
        return print("NO SHARDS BOUND, IGNORING")
    end

    for shardid, state in pairs(_states) do
        if checkbit(state:value(), STATE_ACTIVE) then
            print("Sending the RPC to active shard", shardid)
            PEARL.SendRPCToShard(
                rpc_id, shardid, ...
            )
        end
    end
end

local function _SendRPCToInactiveSyncedShards(rpc_id, ...)
    local connected_shards = PEARL.ServerNetwork:GetConnectedShardIDs()
    if IsTableEmpty(connected_shards) then
        return print("NO SHARDS CONNECTED - IGNORING")
    end

    local shardid
    for i = 1, #connected_shards do
        shardid = connected_shards[i]
        if shardid and not connected_shards[shardid] and _uptodate_shards[shardid] then
            print("Sending the RPC to inactive shard", shardid)
            PEARL.SendRPCToShard(
                rpc_id, shardid, ...
            )
        end
    end
end

local function _AddBinding(id, inst)
    if _bindings then
        _bindings[id] = inst
    end
end

local function _CreateStateNetvarFor(shardid)
    return net_tinybyte(shardid, "SDC["..tostring(shardid).."]")
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

-- Called for itemget and stacksizechange
local function oncontentchanged(inst, data)
    print("oncontentchanged")
    if (not data or not data.item or not (data.slot or data.src_pos) or _handling) then
        return
    end

    if IsTableEmpty(_active_shards) then
        return print("NO SHARDS ACTIVE - IGNORING")
    end

    _SendRPCToActiveShards(PEARL.RPC.SDC_ItemGet, _GetItemReplicationData(data.item))
    _SendRPCToInactiveSyncedShards(PEARL.RPC.SDC_StateChange, false, false)
end

local function onitemlost(inst, data)
    print("onitemlost")
    if _handling then
        return
    end

    _SendRPCToActiveShards(PEARL.RPC.SDC_ItemLose, data.slot)
    _SendRPCToInactiveSyncedShards(PEARL.RPC.SDC_StateChange, false, false)
end

--------------------------------
-- [[ Slave Event Handlers ]]
--------------------------------

-- Called when the first opener opens the container
local function onopen(inst)
    local self = inst.components.sharditemsyncer
    local state = self._state:value()

    if not checkbit(state, STATE_ACTIVE) then
        self._state:set(setbit(state, STATE_ACTIVE))

        if not checkbit(state, STATE_UPTODATE) then
            _RequestSynchronization()
        end
    end
end

-- Called when all the openers close the container
local function onclose(inst)
    local self = inst.comtaponerns.sharditemsyncer
    local state = self._state:value()

    if checkbit(state, STATE_ACTIVE) then
        self._state:set(STATE_)
    end
end

--------------------------------
-- [[ Prefab Post Init ]]
--------------------------------

--- @class ShardItemSyncer
local ShardItemSyncer = Class(function(self, inst)
    self._id = nil
    self._state = nil
    self._contaner = nil
    self._inst = inst

    -- Whether the shard's items are unique or replicated from Master
    self._replicated = false

    inst:ListenForEvent("itemget", oncontentchanged)
    inst:ListenForEvent("stacksizechange", oncontentchanged)
    inst:ListenForEvent("itemlose", onitemlost)

    if not _ismastershard then
        inst:ListenForEvent("onopen")
        inst:ListenForEvent("onclose")
    end

    if _ismastershard then
        PEARL.EventProcessor:AddSafeEventHandler("shard_connected", function(shardid)

        end)

        PEARL.EventProcessor:AddSafeEventHandler("shard_disconnected", _UnbindShard)
    end
end)

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ShardItemSyncer:PrepareForReplication()
    self._container:DropEverything()
    self:SetWasReplicated(true)
end

function ShardItemSyncer:SetWasReplicated(replicated)
    self._replicated = replicated

    -- TODO: Debug + maybe rethink this a bit
    self._inst.components.container.persists = false
end

function ShardItemSyncer:SetContainer(container)
    self._container = container
end

function ShardItemSyncer:SetUniqueID(id)
    self._id = id

    if _ismastershard then
        _AddBinding(id, self._inst)
    end
end

function ShardItemSyncer:SetupSlaveNetvars()
    self._state = _CreateStateNetvarFor(_shardid)
end

function ShardItemSyncer:GetAllItemsReplicationData()
    local items = {}
    local container = self.inst.components.container
    for i = 1, container.numslots do
        items[i] = _GetItemReplicationData(container.slots[i])
    end

    return items
end

function ShardItemSyncer:IsActive()

end

function ShardItemSyncer:IsActive()

end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

if _ismastershard then
    PEARL.EventProcessor:AddSafeEventHandler("shard_connected", _BindShard)
    PEARL.EventProcessor:AddSafeEventHandler("shard_disconnected", _UnbindShard)
end

--------------------------------
-- [[ RPC Handlers ]]
--------------------------------

PEARL.AddShardRPCHandler("SDC_ItemGet", function(shard, slot, data)
    local item = DecodeAndUnzipString(data)
    print("RECEIVED FROM ", shard, DataDumper(item))

    _handling = true
    PEARL._sdc.components.container:RemoveItemBySlot(slot)
    PEARL._sdc.components.container:GiveItem(SpawnSaveRecord(item), slot)
    _handling = false

    if _ismastershard then
        -- Master data changed so notify all the active shards about it.
        _SendRPCToActiveShards(PEARL.RPC.SDC_ItemGet, slot)
    end
end)

PEARL.AddShardRPCHandler("SDC_Sync", function(shardid, cid, srecords)
    -- If we have no SaveRecords, then this is a request from
    -- a slave shard to send our up-to-date data.
    if not srecords and _ismastershard then
        _SendSyncDataTo(shardid)
        _states[shardid]:set(setbit(_states[shardid]:value(), STATE_UPTODATE))
        return
    end

    local items = DecodeAndUnzipString(srecords)
    if type(items) ~= "table" then
        return error("String decoding failed!")
    end

    if IsTableEmpty(items) then
        return error("Invalid data received")
    end

    print("RECEIVED FROM ", shardid, DataDumper(items))

    _handling = true

    local self = _bindings[cid].components.sharditemsyncer
    local container = self._inst.components.container
    if not self._replicated then
        container:DropEverything()
        self:SetWasReplicated(true)
    end

    container:RemoveAllItems()
    _ReplicateItems(items)

    _handling = false
    self._state:set(setbit(self._state:value(), STATE_UPTODATE))
end)

PEARL.AddShardRPCHandler("SDC_ItemLose", function(shard, slot)
    print("RECEIVED FROM ", shard, slot)

    _handling = true
    PEARL._sdc.components.container:RemoveItemBySlot(slot)
    _handling = false

    if _ismastershard then
        -- Master data changed so notify all the active shards about it.
        _SendRPCToActiveShards(PEARL.RPC.SDC_ItemLose, slot)
    end
end)

PEARL.AddShardRPCHandler("SDC_ActivityChanged", onshardstatechanged)

--------------------------------
-- [[ Return ]]
--------------------------------

return ShardItemSyncer
