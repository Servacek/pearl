
local math = math
local PEARL = PEARL

--------------------------------------
-- [[ Contants ]]
--------------------------------------

local WHITELIST_PATH = "../../whitelist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------
--- @class Whitelist
local WhiteList = {}

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
    return max_players and tonumber(max_players) or 6
end

local function ResetMaxPlayers()
    TheNet:SetDefaultMaxPlayers(GetSavedMaxPlayers())
end

local function ReCalculateMaxPlayers()
    WhiteList:GetContent(function(success, content)
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
-- [[ Setters ]]
--------------------------------------

function WhiteList:Add(userid)
    TheNet:AddToWhiteList(userid)

    ReCalculateMaxPlayers()
end

function WhiteList:Remove(userid)
    TheNet:RemoveFromWhiteList(userid)

    ReCalculateMaxPlayers()
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function WhiteList:Contains(userid)
    return TheNet:IsWhiteListed(userid)
end

--- @async
function WhiteList:GetContent(cb)
    return TheSim:GetPersistentString(WHITELIST_PATH, cb)
end

--------------------------------------
-- [[ Setup ]]
--------------------------------------

PEARL.WhiteList = WhiteList
ReCalculateMaxPlayers()
