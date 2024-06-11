--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category Backend/Frontend

--[[
    Soo... here is the deal, even though we have 3 storage types
    (per-machine, pre-cluster, per-instance) we will use just the one at the bottom
    of the hierarchy which is "per-instance". You can also translate it as per process.
    On a server this basically means per-shard whereas on a client it means per-Account.

    Why you don't use the other 2 types?! you may ask. Well, when you think about it, there is basically
    no data required to be stored per-machine. And even if there would be any, you would have to deal
    with concurrent writes of multiple processes first. The same problem goes with the "per-cluster"
    type, but this time all you need to solve this issue is to let only one shard (likely the Master)
    write the data. But isn't this a per-instance storage now?
--]]


--------------------------------
-- [[ Constants ]]
--------------------------------

local DEFAULT_PERSISTENCE_MANAGER = PEARL.ModPersistence

--------------------------------
-- [[ Class Definition ]]
--------------------------------

--- @static
--- @singleton
--- @class STORAGE
local STORAGE = {
    DATA = {},
    TYPE = {
        MACHINE = "MACHINE", -- One file per machine for all instances of this mod.
        CLUSTER = "CLUSTER", -- One file per cluster for all shard instances of this mod (Master only write)
        SHARD   = "SHARD",   -- Separate file for each mod instance (each shard).
    },
    PATH = {},

    PERSISTENCE_MANAGER = {}, -- The default manager is ModPersistence
}

--------------------------------
-- [[ Static ]]
--------------------------------

--- MPS - Mod Persistent Storage
--- Keep the storage type in the file name so even when the files change their locate we won't swap them.
STORAGE.PATH[STORAGE.TYPE.MACHINE] = PEARL.ModPersistence:GetRootDirectoryPath().."/mps_machine_data.json"
STORAGE.PATH[STORAGE.TYPE.CLUSTER] = "../../mps_cluster_data.json"
STORAGE.PATH[STORAGE.TYPE.SHARD]   = MODROOT.."/data/mps_shard_data.json"
if not PEARL.IN_UGC_FOLDER then -- Only the UGC folder provides separate mod folder for each shard.
    STORAGE.PATH[STORAGE.TYPE.SHARD] = "../mps_shard_data.json"
    STORAGE.PERSISTENCE_MANAGER[STORAGE.TYPE.SHARD] = PEARL.ClusterPersistence
end

STORAGE.PERSISTENCE_MANAGER[STORAGE.TYPE.CLUSTER] = PEARL.ClusterPersistence

--- @enum STORAGE.TYPE
STORAGE.TYPE = {}
for storage_type, _ in pairs(STORAGE.PATH) do
    STORAGE.TYPE[storage_type] = storage_type
end

--------------------------------
-- [[ Public ]]
--------------------------------

--- @param storage_type STORAGE.TYPE
function STORAGE.Save(storage_type)
    local data = STORAGE.DATA[storage_type]
    if table.empty(data) == false then -- Do not create the file if we have no data.
        local storage_path = STORAGE.PATH[storage_type]
        local manager = STORAGE.PERSISTENCE_MANAGER[storage_type] or DEFAULT_PERSISTENCE_MANAGER
        manager:SaveDataToFile(storage_path, data, not PEARL.CONFIG.DEBUG_MODE)
    end
end

function STORAGE.SaveAll()
    for storage_type, _ in pairs(STORAGE.PATH) do
        STORAGE.Save(storage_type)
    end
end

--- @param storage_type STORAGE.TYPE
function STORAGE.Load(storage_type)
    local storage_path = STORAGE.PATH[storage_type]
    --- @type Persistence
    local manager = STORAGE.PERSISTENCE_MANAGER[storage_type] or DEFAULT_PERSISTENCE_MANAGER
    local data = manager:LoadDataFromFile(storage_path, false)
    STORAGE.DATA[storage_type] = type(data) == "table" and data or {}
end

function STORAGE.LoadAll()
    for storage_type, _ in pairs(STORAGE.PATH) do
        STORAGE.Load(storage_type)
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return STORAGE
