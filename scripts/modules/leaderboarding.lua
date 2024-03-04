--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    1. Leaderboard Module
    2. Leaderboard Service
    3. Leaderboard Webhook
    4. Leaderboard Model
--]]


local MARKDOWN = PEARL.loadfile("libraries/markdown")

--- @type Leaderboard
local Leaderboard = PEARL.loadfile("libraries/database/models/leaderboard")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local MIN_ABS_RECORDS = 3
local MIN_CURRENT_RECORDS = 5

local MIN_DAY_LEADER_GAINS = 25

local REP_BUFFER_TIME = 5

--------------------------------------
-- [[ Locals ]]
--------------------------------------

--- @type Leaderboard
local absolute_leaderboard = PEARL.LeaderboardService:GetLeaderboard(Leaderboard.TYPE.ABSOLUTE)
absolute_leaderboard:SetMinPlayers(MIN_ABS_RECORDS)
absolute_leaderboard:SetIndex(1)

--- @type Leaderboard
local monthly_leaderboard = PEARL.LeaderboardService:GetLeaderboard(Leaderboard.TYPE.MONTHLY)
monthly_leaderboard:SetMinPlayers(MIN_CURRENT_RECORDS)
monthly_leaderboard:SetIndex(2)

local leaderboards = PEARL.LeaderboardService:GetAllLeaderboards()

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function SaveChangesIfNeeded()
    PEARL.debug("SaveChanges")

    if PEARL.LeaderboardService:HasAnyUnsavedChanges() then
        PEARL.LeaderboardService:Save()
    end
end

local function CompeteDayLeader(rivalid)
    local leaderid = monthly_leaderboard:GetLeaderUserID()
    if leaderid == rivalid then
        return
    end

    local rivalgains = PEARL.Reputation:GetTodayGainsOf(rivalid)
    if not rivalgains or rivalgains < MIN_DAY_LEADER_GAINS then
        return
    end

    local leadergains = PEARL.Reputation:GetTodayGainsOf(leaderid)
    if leadergains < rivalgains then
        monthly_leaderboard:SetDayLeaderUserID(rivalid)
    end
end

local function AnnounceNewPOTM(userid, month, year)
    local monthname = PEARL.GetMonthFancyName(month)
    local monthfullname = STRINGS.PEARL.FULL_MONTH_NAME:format(monthname, year)

    local name = PEARL.DB:GetField(userid, "username")
    local netid = PEARL.DB:GetField(userid, "netid")
    local discordid = PEARL.DB:GetField(userid, "discordid")

    local mention
    if discordid then
        mention = MARKDOWN.mention(discordid, MARKDOWN.MENTION_TYPE.USER)
    end

    PEARL.DiscordLeaderBoarder:Announce(PEARL.EMOJIS.GAME_TO_DISCORD.TROPHY.." "..STRINGS.PEARL.UI.POTM_ANNOUNCEMENT:format(
        MARKDOWN.bold(monthfullname), mention or PEARL.NetProfileLink(name, netid) or MARKDOWN.bold(name)
    ))
end

function PEARL.UpdateLeaderboard()
    PEARL.LeaderboardService:UpdateUI()
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnClientBanned(userid)
    for _, leaderboard in pairs(leaderboards) do
        -- Do this for all leaderboards.
        leaderboard:RemovePlayer(userid)
    end

    --UpdateUIIfNeeded()
end

local function OnClientUnbanned(userid)
    for _, leaderboard in pairs(leaderboards) do
        -- Do this for all leaderboards.
        leaderboard:AddPlayer(userid)
    end

    --UpdateUIIfNeeded()
end

--- @type table<string, Task>
local buffer = {}
local buffer_task
local function OnBufferDone()
    buffer_task:cancel()
    buffer_task = nil

    -- Clear the buffer and handle the changes for the players inside it.
    for userid, old_rep in pairs(buffer) do
        buffer[userid] = nil

        local new_rep = PEARL.Reputation:GetOf(userid)
        if new_rep > old_rep then
            CompeteDayLeader(userid)
        end

        for _, leaderboard in pairs(leaderboards) do
            leaderboard:OnReputationChanged(userid)
        end
    end

    -- SaveChangesIfNeeded()
    -- UpdateUIIfNeeded()
end

local function OnReputationChanged(userid, old, new)
    PEARL.debug("OnReputationDelta", userid, new, old)

    if not (old and new) or old == new or not PEARL.LeaderboardService:IsLeaderboardingAllowedFor(userid)  then
        return
    end

    if not buffer[userid] then
        buffer[userid] = old
    end

    if not buffer_task then
        buffer_task = PEARL.WallScheduler:ExecuteInTime(REP_BUFFER_TIME, OnBufferDone)
    end
end

local function OnNewDay()
    PEARL.debug("OnNewDay")
    monthly_leaderboard:SetDayLeaderUserID(nil)
    SaveChangesIfNeeded()
end

local function OnNewMonth(stb)
    PEARL.debug("OnNewMonth")

    -- If the monthly leaderboard has enough players (it does display them),
    -- choosing the player of the month is automatically enabled.
    local leaderid = monthly_leaderboard:GetLeaderUserID()
    if monthly_leaderboard:IsPlayerVisible(leaderid) then
        AnnounceNewPOTM(leaderid, stb.month, stb.year)
    end

    -- Since we are creating a new updating message, archive the old one.
    -- Do NOT update the other embeds so the data do match the date.
    PEARL.LeaderboardService:ArchiveLeaderboardEmbed(absolute_leaderboard)
    PEARL.DiscordLeaderBoarder:UpdateMessage()

    -- Clear all the player data and start again.
    monthly_leaderboard:Reset()
    PEARL.LeaderboardService:StartNewSession()
end

function PEARL.OnNewMonth()
    OnNewMonth(PEARL.TimestampToTable(os.time()))
end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddSafeEventHandler("onreputationchanged", OnReputationChanged)
PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)
PEARL.EventProcessor:AddSafeEventHandler("clientunbanned", OnClientUnbanned)

PEARL.EventProcessor:AddSafeEventHandler("newday", OnNewDay)
PEARL.EventProcessor:AddSafeEventHandler("newmonth", OnNewMonth)

--- @type Task?, boolean?
local buffered_task, was_visible = nil, false
PEARL.EventProcessor:AddSafeEventHandler("leaderboardchanged", function(leaderboard, visible)
    if visible == true then
        was_visible = visible
    end

    if not buffered_task then
        buffered_task = PEARL.WallScheduler:ExecuteInTime(0, function()
            if buffered_task then
                buffered_task:cancel()
                buffered_task = nil
            end

            PEARL.LeaderboardService:Save()

            if was_visible then
                PEARL.LeaderboardService:UpdateUI()
            end

            was_visible = nil
        end)
    end
end)

--------------------------------
-- [[ Init ]]
--------------------------------

PEARL.AddGamePostInit(function()
    if PEARL.LeaderboardService:IsAnySessionActive() then
        if PEARL.LeaderboardService:NeedsToUpdateUI() then
            PEARL.debug("UpdateUI")

            PEARL.LeaderboardService:UpdateUI()
        end

        return
    end

    PEARL.LeaderboardService:StartNewSession()
end)
