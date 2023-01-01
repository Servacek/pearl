--[[
    Alternative to whitelist.txt.
]]

if TheNet:GetIsClient() or not TheNet:IsDedicated() then
    return
end

local io = io
local PEARL = PEARL

--------------------------------------
-- [[ Contants ]]
--------------------------------------

local ALLOWLIST_PATH = PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/allowlist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

--- @class AllowList
local AllowList = {
    userids = {},

    enabled = false,
}

--------------------------------------
-- [[ Member Functions ]]
--------------------------------------

function AllowList:Toggle()
    self.enabled = not self.enabled

    return self.enabled
end

function AllowList:SetIsEnabled(enabled)
    self.enabled = enabled
end

function AllowList:IsEnabled()
    return self.enabled
end

function AllowList:Add(userid)
    if userid and not self.userids[userid] then
        self.userids[userid] = true
    end
end

function AllowList:Remove(userid)
    if self.userids[userid] then
        self.userids[userid] = nil
    end
end

function AllowList:Contains(userid)
    return self.userids[userid] or false
end

function AllowList:Load()
    if not io.exists(ALLOWLIST_PATH) then
        PEARL.info("Allowlist file not found. Creating a new one...")
        return self:Save()
    end

    -- We do not care about the order so create an key-value table
    -- for faster and easier access.
    for line in io.lines(ALLOWLIST_PATH) do
        -- Strip the lines because of the annoying '\r' on Windows...
        self:Add(line:strip())
    end
end

function AllowList:Save()
    local file, msg = io.open(ALLOWLIST_PATH, "w")
    if file == nil then
        PEARL.error("Couldn't create the allowlist file:\n", msg)
        return false
    end

    for userid, allowed in pairs(self.userids) do
        if allowed == true then
            local _, errmsg = file:write(userid, "\n")
            if errmsg then
                PEARL.error("Couldn't write to the allowlist:\n", errmsg)
                return false
            end
        end
    end

    return file:close()
end

--------------------------------------
-- [[ Setup ]]
--------------------------------------

-- Master does handle all the connections.
if TheShard:IsMaster() then
    PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid)
        if AllowList:IsEnabled() then
            PEARL.debug("Prohibiting connection for", userid)
            return AllowList:Contains(userid)
        end

        -- Else let the the default callback execute.
        -- It should return always true.
    end)
end

-- PEARL.EventProcessor:AddEventHandler("quit", function()
--     AllowList:Save()
-- end)

return AllowList
