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

--- @type Leaderboard
local Leaderboard = PEARL.loadfile("libraries/database/models/leaderboard")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local FILE_EXTENSION = ".json"
local ROOT = PEARL.ModPersistance:GetRootDirectoryPath()
local LEADERBOARD_FILE_PATH = ROOT.."/"..PEARL.CONFIG.LEADERBOARD.DIRECTORY.."/leaderboards"..FILE_EXTENSION

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class LeaderboardService: Library
local LeaderboardService = {
    --- @type table<string, Leaderboard>
    leaderboards = {},
    ui_webhook = PEARL.DiscordLeaderBoarder,
}

--- @type LeaderboardService
LeaderboardService = Library(LeaderboardService)

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

function LeaderboardService:IsAnySessionActive()
    return self.ui_webhook:HasUpdatingMessage() == true
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

function LeaderboardService:HasAnyUnsavedChanges()
    for _, leaderboard in pairs(self.leaderboards) do
        if leaderboard:HasAnyUnsavedChanges() then
            return true
        end
    end

    return false
end

function LeaderboardService:ForEach(fn)
    for _, leaderboard in pairs(self.leaderboards) do
        fn(leaderboard)
    end
end

function LeaderboardService:NeedsToUpdateUI()
    for _, leaderboard in pairs(self.leaderboards) do
        if not leaderboard:IsUIUpToDate() and not leaderboard:IsUpdatingUI() then
            return true
        end
    end

    return false
end

function LeaderboardService:ToString()
    local str
    for _, leaderboard in pairs(self.leaderboards) do
        str = (str and str.."\n\n" or "")..leaderboard:ToString()
    end

    if not str or self:IsDisabled() then
        str = STRINGS.PEARL.EMBEDS.LEADERBOARD.NO_LEADERBOARDS
    end

    return str
end

--- @param leaderboard Leaderboard
function LeaderboardService:ArchiveLeaderboardEmbed(leaderboard)
    leaderboard:GetMessage():SetEmbed(leaderboard:GetIndex(), leaderboard:GetEmbed(true))
end

function LeaderboardService:UpdateLeaderboardEmbeds()
    local ui_message = self.ui_webhook:GetMessage()
    for _, leaderboard in pairs(self:GetAllLeaderboards()) do
        ui_message:SetEmbed(leaderboard:GetIndex(), leaderboard:GetEmbed())
    end
end

function LeaderboardService:UpdateUI()
    PEARL.debug("Updating the leaderboard...")

    self:UpdateLeaderboardEmbeds()

    local update_request = self.ui_webhook:UpdateMessage()
    if not update_request then
        PEARL.error("Failed to update the leaderboard message!")
        return
    end

    self:ForEach(function(leaderboard)
        leaderboard:OnUpdateStart()
    end)

    update_request:SetOnSuccess(function()
        self:ForEach(function(leaderboard)
            leaderboard:OnUpdateDone()
            self:Save()
        end)
    end)
end

function LeaderboardService:StartNewSession()
    -- Make sure the newest embeds are assigned.
    self:UpdateLeaderboardEmbeds()

    self.ui_webhook:PostUpdatingMessage()
end

function LeaderboardService:ValidateLoadedData()
    -- Ensure that everything was loaded correctly.
    for _, typ in pairs(Leaderboard.TYPE) do
        if not Leaderboard.is_instance(self.leaderboards[typ]) then
            return error("Failed to load "..typ.." leaderboard!")
        end
    end
end

function LeaderboardService:Load()
    local savedata = PEARL.ModPersistance:LoadDataFromFile(LEADERBOARD_FILE_PATH, true)
    local leaderboards = savedata and savedata.leaderboards
    for _, typ in pairs(Leaderboard.TYPE) do
        LeaderboardService.leaderboards[typ] = Leaderboard(typ, (leaderboards and leaderboards[typ]))
    end
end

function LeaderboardService:Save()
    local savedata = {
        leaderboards = {}
    }
    for typ, leaderboard in pairs(self.leaderboards) do
        savedata.leaderboards[typ] = leaderboard:OnSave()
    end

    PEARL.ModPersistance:SaveDataToFile(LEADERBOARD_FILE_PATH, savedata, true)
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
