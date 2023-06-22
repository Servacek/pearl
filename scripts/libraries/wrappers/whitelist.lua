--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local math = math
local PEARL = PEARL

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local WHITELIST_PATH = "../../whitelist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

--- @class Whitelist
local WhiteList = {
    MODE = {
        DISABLED = 0,
        DEFAULT = 1,
        -- Keep total player slots count in sync with the total reserved slot's count
        ALLOWLIST = 2,
    }
}

--------------------------------------
-- [[ Private Variables ]]
--------------------------------------

local _mode = WhiteList.MODE.DEFAULT

--------------------------------------
-- [[ Private Functions ]]
--------------------------------------

local function GetSavedMaxReservedSlots()
    -- This can be nil when not configured.
    local whitelist_slots = TheSim:GetSetting("NETWORK", "whitelist_slots")
    return whitelist_slots and tonumber(whitelist_slots) or 0
end


local function GetSavedMaxPlayers()
    local max_players = TheSim:GetSetting("GAMEPLAY", "max_players")
    return max_players and tonumber(max_players) or TUNING.MAX_SERVER_SIZE
end

local function ResetMaxPlayers()
    TheNet:SetDefaultMaxPlayers(GetSavedMaxPlayers())
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function WhiteList:Add(userid)
    TheNet:AddToWhiteList(userid)

    if _mode == WhiteList.MODE.ALLOWLIST then
        self:SyncReservedWithSlots()
    end
end

function WhiteList:Remove(userid)
    TheNet:RemoveFromWhiteList(userid)

    if _mode == WhiteList.MODE.ALLOWLIST then
        self:SyncReservedWithSlots()
    end
end

function WhiteList:SetMode(mode)
    _mode = mode
end

function WhiteList:SyncReservedWithSlots()
    return TheSim:GetPersistentString(WHITELIST_PATH, function(success, content)
        if not success then
            return PEARL.error("Failed to load the whitelist!")
        end

        local reserved_slots = 0
        for _, line in ipairs(content:split("\n")) do
            -- If the ID on the line is vaid.
            if #line:lstrip() > 3 then
                reserved_slots = reserved_slots + 1
            end
        end

        if reserved_slots <= 0 then
            return ResetMaxPlayers()
        end

        local max_reserved_slots = GetSavedMaxReservedSlots()
        local max_slots = GetSavedMaxPlayers()

        if max_reserved_slots ~= nil and max_reserved_slots > 0 then
            return TheNet:SetDefaultMaxPlayers(
                math.min(math.min(max_reserved_slots, max_slots), reserved_slots)
            )
        end

        return TheNet:SetDefaultMaxPlayers(
            math.min(max_slots, reserved_slots)
        )
    end)
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

-- TODO: Read the whitelist by ourselves
-- because this doesn't work for the Caves shard.
function WhiteList:Contains(userid)
    return TheNet:IsWhiteListed(userid)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return WhiteList
