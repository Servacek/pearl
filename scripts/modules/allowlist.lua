--[[
    Alternative to whitelist.txt.
]]

local io = io
local PEARL = PEARL

PEARL.warn("Allowlist is enabled! Only players on the list or admins will be able to join.")

local ALLOWLIST_PATH = PEARL.MODROOT..""..PEARL.DATA_DIR_NAME.."/allowlist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------
--- @class AllowList
local AllowList = Class(function(self)
    self.userids = {}
end)

--------------------------------------
-- [[ Member Functions ]]
--------------------------------------

function AllowList:Add(userid)
    if userid and not self.userids[userid] then
        self.userids[userid] = true
    end
end

function AllowList:Remove(userid)
    if userid and self.userids[userid] then
        self.userids[userid] = nil
    end
end

function AllowList:Contains(userid)
    return self.userids[userid]
end

function AllowList:Load()
    if not io.exits(ALLOWLIST_PATH) then
        PEARL.info("Allowlist file not found. Creating a new one...")
        return self:Save()
    end

    -- We do not care about the order so create an key-value table
    -- for faster and easier access.
    for userid in io.lines(ALLOWLIST_PATH) do
        self:Add(userid)
    end
end

function AllowList:Save()
    local file, msg = io.open(ALLOWLIST_PATH, "w")
    if file == nil then
        PEARL.error("Couldn't write to the whitelist:\n", msg)
        return false
    end

    for _, userid in pairs(self.userids) do
        local _, errmsg = file:write(userid, "\n")

        if errmsg ~= nil then
            PEARL.error("Couldn't write to the whitelist:\n", errmsg)
            return false
        end
    end

    return file:close()
end

--------------------------------------
-- [[ Setup ]]
--------------------------------------

local List = AllowList()
List:Load()

-- This module loads when localization is enabled as well.
if PEARL.CONFIG.ALLOWLIST then
    PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid)
        return List:Contains(userid)
    end)
end

return List
