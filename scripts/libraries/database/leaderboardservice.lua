--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Library = PEARL.loadfile("models/library")

--- @type PersistentMap
local PersistentMap = PEARL.loadfile("libraries/datastructures/persistentmap")

--- @type Leaderboard
local Leaderboard = PEARL.loadfile("libraries/database/models/leaderboard")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local FILE_EXTENSION = ".json"
local LEADERBOARD_FILE_PATH = PEARL.CONFIG.LEADERBOARD.DIRECTORY.."/leaderboards"..FILE_EXTENSION

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class LeaderboardService: Library
local LeaderboardService = {
    --- @type PersistentMap
    savedata = PersistentMap(LEADERBOARD_FILE_PATH),
    --- @type table<string, Leaderboard>
    leaderboards = {},
}

--- @type LeaderboardService
LeaderboardService = Library(LeaderboardService)

LeaderboardService.savedata:SetOnLoad(function(data)
    local leaderboards = data.leaderboards or {}
    for _, typ in pairs(Leaderboard.TYPE) do
        leaderboards[typ] = Leaderboard(typ, leaderboards[typ])
        LeaderboardService.leaderboards[typ] = leaderboards[typ]
    end

    data.leaderboards = leaderboards

    PEARL.DiscordLeaderBoarder:SetUpdatingMessageID(data.messageid)

    return data
end)
LeaderboardService.savedata:SetOnSave(function(data)
    local leaderboards = data.leaderboards or {}
    for _, typ in pairs(Leaderboard.TYPE) do
        local leaderboard = leaderboards[typ] or Leaderboard()
        leaderboards[typ] = leaderboard:OnSave()
    end

    data.leaderboards = leaderboards
    data.messageid = PEARL.DiscordLeaderBoarder:GetUpdatingMessageID()

    return data
end)

--------------------------------------
-- [[ Getters ]]
--------------------------------------

--- @return Leaderboard
function LeaderboardService:GetLeaderboard(typ)
    return self.leaderboards[typ]
end

--- @return table<string, Leaderboard>
function LeaderboardService:GetAllLeaderboards()
    return self.leaderboards
end

function LeaderboardService:IsLeaderboardingAllowedFor(userid)
    return PEARL.DB:IsRecordCachedFor(userid) and
            not PEARL.ServerNetwork:IsClientBanned(userid) and
           (not PEARL.ServerNetwork:IsAdmin(userid) or PEARL.CONFIG.DEBUG_MODE)
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

function LeaderboardService:ToString()
    local str
    for _, leaderboard in pairs(self:GetAllLeaderboards()) do
        str = (str and str.."\n\n" or "")..leaderboard:ToString()
    end

    if not str or PEARL.LeaderboardService:IsDisabled() then
        str = STRINGS.PEARL.EMBEDS.LEADERBOARD.NO_LEADERBOARDS
    end

    return str
end

function LeaderboardService:UpdateLeaderboardEmbeds()
    for _, leaderboard in pairs(self:GetAllLeaderboards()) do
        PEARL.DiscordLeaderBoarder:SetEmbed(leaderboard:GetIndex(), leaderboard:GetEmbed())
    end
end

function LeaderboardService:ArchiveLeaderboard(typ)
    local leaderboard = self:GetLeaderboard(typ)
    if leaderboard then
        leaderboard:SetIsArchived(true)

        -- Remove the absolute leaderboard embed from it so we can archive it.
        PEARL.DiscordLeaderBoarder:SetEmbed(leaderboard:GetIndex(), leaderboard:GetEmbed())
        PEARL.DiscordLeaderBoarder:DoUpdate()
    end
end

-- --- @return Leaderboard
-- function LeaderboardService:EnsureLeaderboard(typ)
--     if not self.leaderboards[typ] then -- No such leaderboard exists, add one!
--         self.leaderboards[typ] = Leaderboard()
--     end

--     return self.leaderboards[typ]
-- end

function LeaderboardService:ValidateLoadedData()
    -- Ensure that everything was loaded correctly.
    for _, typ in pairs(Leaderboard.TYPE) do
        if not Leaderboard.is_instance(self.leaderboards[typ]) then
            return error("Failed to load "..typ.." leaderboard!")
        end
    end
end

function LeaderboardService:Load()
    if not io.exists(self.savedata.filepath) then
        self:Save()
    end

    self.savedata:Load()
end

function LeaderboardService:Save()
    self.savedata:Save()
end

--------------------------------------
-- [[ Debugging ]]
--------------------------------------

function LeaderboardService:DisplayDebugInfo()
    table.dump(self.leaderboards)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return LeaderboardService
