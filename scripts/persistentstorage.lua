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

--- Either ModPersistence or ClusterPersistence
local DEFAULT_PERSISTENCE_MANAGER = PEARL.ClusterPersistence

--- MPS - Mod Persistent Storage
local FILE_NAME = PEARL.UNIQUE_IDENTIFIER.."_mps_data.json"
local FILE_PATH = TheNet:GetIsClient() and FILE_NAME or "../"..FILE_NAME

--------------------------------
-- [[ Class Definition ]]
--------------------------------

--- @static
--- @singleton
--- @class STORAGE
local STORAGE = {
    DATA = {},
}

--------------------------------
-- [[ Public ]]
--------------------------------

function STORAGE.Save()
    if table.empty(STORAGE.DATA) == false then -- Do not create the file if we have no data.
        DEFAULT_PERSISTENCE_MANAGER:SaveDataToFile(FILE_PATH, STORAGE.DATA, not PEARL.CONFIG.DEBUG_MODE)
    end
end

function STORAGE.Load()
    print(FILE_PATH)
    local data = DEFAULT_PERSISTENCE_MANAGER:LoadDataFromFile(FILE_PATH, false)
    STORAGE.DATA = type(data) == "table" and data or {}
end

--------------------------------
-- [[ Return ]]
--------------------------------

return STORAGE
