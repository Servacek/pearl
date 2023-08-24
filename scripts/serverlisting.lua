--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Constants ]]
--------------------------------

local LOBBY_REGIONS_URL = "https://lobby-v2-cdn.klei.com/regioncapabilities-v2.json"
local LOBBY_BASE_URL = "https://lobby-v2-eu-central-1.klei.com/lobby/"
local LOBBY_ENDPOINTS = {
    WRITE       = "write",
    READ        = "read",
    UPDATE      = "update",
    DELETE      = "delete",
    KEEP_ALIVE  = "keepAlive",
    GET_IP      = "getIP"
}

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class ServerListing
local ServerListing = {}

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function ServerListing:GetAvailableRegions(cb)
    PEARL.HTTPClient:GET(LOBBY_REGIONS_URL, cb)
        :Send()
end

function ServerListing:GetRow()
    return TheNet:GetServerListing().row
end

--- @param cb fun(response: string|table, self: Request, ...: any):any?
function ServerListing:GetData(cb, raw)
    local data = {
        __token = PEARL.SERVER_TOKEN,
        __gameId = PEARL.CONSTS.DST_WEB_GAME_ID,
        query = {
            __rowId = self:GetRow(),
        },
    }

    PEARL.HTTPClient:POST(LOBBY_BASE_URL..LOBBY_ENDPOINTS.READ, cb, data)
        :SetIsRaw(raw)
        :Send()
end

function ServerListing:SetDataField(name, value)
    local data = {
        __token = PEARL.SERVER_TOKEN,
        __gameId = PEARL.CONSTS.DST_WEB_GAME_ID,
        __rowId = self:GetRow(),
        [name] = value,
    }

    PEARL.HTTPClient:POST(LOBBY_BASE_URL..LOBBY_ENDPOINTS.UPDATE, function(data)
        print(data)
    end, data)
        :SetIsRaw(true)
        :Send()
end

function ServerListing:UpdateModConfigData()
    PEARL.CONFIG.SOCIAL_LINKS = "HENLO!!!"
    local data_str = PEARL.ModConfig:GetEnabledServerModsConfigDataString()
    print(data_str)
    self:SetDataField("mods_config_data", data_str)
end

function ServerListing:DisplayData()
    self:GetData(function(data)
        print(data)
    end, true)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return ServerListing
