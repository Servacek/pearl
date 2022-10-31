setfenv(1, _G.SUB.env)
local io, table = io, table
local SUB = SUB

local Whitelist = Class(function(self)
    self.userids = {}
end)

--------------------------------------

function Whitelist:SourceFileExists()
    local file = io.open(SUB.CONSTANTS.WHITELIST_PATH, "r")

    return file ~= nil and io.close(file)
end

function Whitelist:Add(userid)
    self.userids[#self.userids + 1] = userid
end


function Whitelist:Remove(userid)
    table.removearrayvalue(self.userids, userid)
end

function Whitelist:Contains(userid)
    return table.contains(self.userids, userid)
end

function Whitelist:Load()
    if not self:SourceFileExists() then
        return SUB.error("Whitelist", "Couldn't load the whitelist:", SUB.CONSTANTS.WHITELIST_PATH, "was not found!")
    end

    for userid in io.lines(SUB.CONSTANTS.WHITELIST_PATH) do
        self:Add(userid)
    end
end

function Whitelist:Save()
    local file, msg = io.open(SUB.CONSTANTS.WHITELIST_PATH, "w")
    if file == nil then
        SUB.error("Error", "Couldn't write to the whitelist:\n", msg)
        return false
    end

    for _, userid in pairs(self.userids) do
        local _, errmsg = file:write(userid, "\n")

        if errmsg ~= nil then
            SUB.error("Error", "Couldn't write to the whitelist:\n", errmsg)
            return false
        end
    end

    return file:close()
end


return Whitelist