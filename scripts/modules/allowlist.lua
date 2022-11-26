--[[
    Alternative to whitelist.txt.

    This is deprecated. Use the default one instead.
]]

local io = io
local PEARL = PEARL

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

function AllowList:SourceFileExists()
    local file = io.open(ALLOWLIST_PATH, "r")

    return file ~= nil and io.close(file)
end

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
    if not self:SourceFileExists() then
        return PEARL.error("Couldn't load the whitelist:", ALLOWLIST_PATH, "was not found!")
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
    PEARL.AddFunctionPreCall("JoinServerFilter", function(userid)
        return List:Contains(userid)
    end)
end

return List
