--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODO:
------------------------------------------
-- [[ Constants ]]
------------------------------------------

local URL_BASE = "https://api.steampowered.com/IPublishedFileService"
local VERSION = "v1"
local API_KEY = PEARL.CONFIG.STEAM.API_KEY or ""

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class PublishedFileService
local PublishedFileService = {}

------------------------------------------
-- [[ Static ]]
------------------------------------------

--- @enum ENDPOINT
PublishedFileService.ENDPOINT = {
    CAN_SUBSCRIBE = "CanSubscribe",
    GET_DETAILS = "GetDetails",
    GET_SUB_SECTION_DATA = "GetSubSectionData",
    GET_USER_FILE_COUNT = "GetUserFileCount",
    GET_USER_FILES = "GetUserFiles",
}

------------------------------------------
-- [[ Local Functions ]]
------------------------------------------

--- @param endpoint ENDPOINT
--- @param params table<string, any>?
local function GetURLForEndpoint(endpoint, params)
    local url = URL_BASE.."/"..endpoint.."/"..VERSION.."/?key="..API_KEY
    for name, value in pairs(params) do
        if type(value) == "table" then
            for i, v in ipairs(value) do
                local field = name.."["..tostring(i).."]"
                url = url.."&"..field.."="..tostring(v)
            end
        else
            url = url.."&"..name.."="..tostring(value)
        end
    end
end

------------------------------------------
-- [[ Getters ]]
------------------------------------------

--- Check if the user can subscribe to the published file
function PublishedFileService:CanSubscribe()

end

--- Retrieves information about a set of published files.
function PublishedFileService:GetDetails(params, cb)
    PEARL.HTTPClient:GET(GetURLForEndpoint(PublishedFileService.ENDPOINT.GET_DETAILS, params), cb)
end

--- Retrieves a count of files published by a user. Uses the same messages as GetUserFiles but totalonly must be true.
function PublishedFileService:GetSubSectionData()

end

--- Retrieves a count of files published by a user. Uses the same messages as GetUserFiles but totalonly must be true.
function PublishedFileService:GetUserFileCount()

end

--- Retrieves files published by a user.
function PublishedFileService:GetUserFiles()

end

--- Get user vote summary
function PublishedFileService:GetUserVoteSummary()

end

--- Performs a search query for published files
function PublishedFileService:QueryFiles()

end

------------------------------------------
-- [[ Constants ]]
------------------------------------------

return PublishedFileService
