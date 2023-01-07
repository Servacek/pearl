--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--------------------------------------
-- [[ Constants ]]
--------------------------------------

local ADMINLIST_PATH = "../../adminlist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

--- @class AdminList
local AdminList = { _userids = {} }

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function AdminList:Add(userid)
    if userid then
        self._userids[userid] = true
    end
end

function AdminList:Remove(userid)
    if userid then
        self._userids[userid] = nil
    end
end

function AdminList:Clear()
    for userid, _ in pairs(self._userids) do
        self._userids[userid] = nil
    end
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function AdminList:Contains(userid)
    return self._userids[userid] == true
end

function AdminList:GetContent()
    local content = ""
    for userid, allowed in pairs(self._userids) do
        if allowed == true then
            content = content..userid.."\n"
        end
    end

    return content
end

--------------------------------------
-- [[ Loaders/Savers ]]
--------------------------------------
-- Since there are no built-in adminlist modifiers we have to implement our own.

function AdminList:Load()
    return TheSim:GetPersistentString(ADMINLIST_PATH, function(success, content)
        if not success then
            return -- Just silent exit here, not every server needs an adminlist...
        end

        -- Ids should be separated by a new-line character
        for _, line in ipairs(content:split("\n")) do
            -- Strip the lines because of the annoying '\r' on Windows...
            self:Add(line:strip())
        end
    end)
end

function AdminList:Save()
    local content = ""
    for userid, allowed in pairs(self._userids) do
        if allowed == true then
            content = content.."\n"..userid
        end
    end

    -- Adds the 'KLEI     1' prefix...
    return TheSim:SetPersistentString(ADMINLIST_PATH, content, false)
end

function AdminList:Reload()
    self:Clear()
    self:Load()
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return AdminList
