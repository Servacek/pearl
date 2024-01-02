--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------------
-- [[ Constants ]]
--------------------------------------

local DAY_PERCENT_SEGMENT = .1

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

-- RECORDS ARE CREATED HERE
local function RecordClientConnectionData(userid, data)
    -- This is the place where we want to create the record if needed.
    if not PEARL.DB:HasRecordFile(userid) then
        if not PEARL.DB:CreateRecordFile(userid) then
            return -- We have failed to create the record.
        end

        PEARL.Reputation:InitializeFor(userid)
    end

    PEARL.DB:SafeSetField(userid, "lastmods", data.enabled_mods)
    PEARL.DB:SafeSetField(userid, "lastlocale", data.locale)
    PEARL.DB:SafeSetField(userid, "lastplatform", data.platform)

    -- Make sure these data are saved, because they are important.
    PEARL.DB:SaveRecordFor(userid)
end

local function SaveSessionInfoFor(userid)
    PEARL.DB:SafeSetField(userid, "lastsessionid", TheNet:GetSessionIdentifier())
    PEARL.DB:SafeSetField(userid, "lastsnapshot", TheNet:GetCurrentSnapshot())

    if TheWorld and TheWorld.state then
        PEARL.DB:SafeSetField(userid, "lastcycle", TheWorld.state.cycles)
    end
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function OnClientDataRecevied(userid, data)
    return RecordClientConnectionData(userid, data)
end

local function OnClientBanned(userid, seconds, reason, author)
    seconds = tonumber(seconds)
    local timenow = os.time()

    local bans = PEARL.DB:GetField(userid, "bans", {})
    bans[#bans + 1] = {
        reason      = reason,
        author      = author,
        timestart   = timenow,
        timestop    = seconds and timenow + seconds or nil
    }
    PEARL.DB:SetField(userid, "bans", bans)

    -- Reset reputation value in case of an unban.
    PEARL.Reputation:SetFor(userid, PEARL.CONSTS.STARTING_REPUTATION)
    PEARL.DB:SaveRecordFor(userid)
end

local function OnClientUnbanned(userid)
    local bans = PEARL.DB:GetField(userid, "bans")
    -- Try to get the latest ban.
    local ban = type(bans) == "table" and bans[#bans]
    if not ban then
        return
    end

    ban.timestop = os.time()
    PEARL.DB:SetField(userid, "bans", bans)
    PEARL.DB:SaveRecordFor(userid)
end

local function OnClientAgreementDataReceived(data)
    local record = PEARL.DB:GetRecordFor(data.userid)
    if not record then
        return
    end

    record.agreement = {
        collectdata = data.agreed and data.datacollection or false,
        version = data.version,
        lastdate = os.time(),
    }

    -- Only record data if we have agreed and enabled data collection
    if data.agreed and data.datacollection then
        if not record.agreement.agreedafter then
            -- Note only the first agreed-in time
            record.agreement.agreedafter = data.agreedintime
        end
    else -- User has disagreed or turned off datacollection (which is the same)
        record.agreement.collectdata = false
    end

    -- Here we can finally save the data with clear mind.
    -- On disagreement this will be the last saved data for this record.
    PEARL.DB:SaveRecordFor(data.userid, record)
end

-- Called after all connection filters succeeded!
local function OnClientConnected(world, player)
    PEARL.DB:SafeSetField(player.userid, "lastjoinedtime", os.time())
    SaveSessionInfoFor(player.userid)

    local client = TheNet:GetClientTableForUser(player.userid)
    if not client or not client.name then
        return
    end

    -- Update this on every connect since it could possibly change.
    PEARL.DB:SafeSetField(player.userid, "username", client.name)
end

local function OnClientAuthenticationComplete(world, data)
    print("SETTING LASTSHARID TO", PEARL.SHARDID)
    -- Set this as soon as possible.
    PEARL.DB:SafeSetField(data.userid, "lastshardid", tostring(PEARL.SHARDID))
    PEARL.DB:SaveRecordFor(data.userid)
end

local function OnClientDisconnected(world, data)
    -- No loading here! Also the userid can be nil or an empty string.
    if PEARL.DB:IsRecordLoadedFor(data.userid) then
        PEARL.DB:SafeSetField(data.userid, "lastseentime", os.time())

        PEARL.DB:SaveRecordFor(data.userid)
        PEARL.DB:UnloadRecord(data.userid) -- Free the memory
    end
end

local function OnClientMigrating(world, data)
    if type(data) ~= "table" or not data.player or not data.player.userid then
        return
    end

    if data.worldid then
        PEARL.DB:SetField(data.player.userid, "lastshardid", tostring(data.worldid))
    end

    OnClientDisconnected(world, {userid = data.player.userid})
end

local function OnClientProfileData(userid, data)
    for key, value in pairs(data) do
        PEARL.DB:SafeSetField(userid, key, value)
    end
end

local function OnPlayerChanged(world, player)
    -- Always save this field since we use it as fallback for the fancy version.
    local prefab = player.prefab
    if prefab == nil or player.userid == nil or player.userid == "" then
        return
    end

    PEARL.DB:SetField(
        player.userid, "lastprefab", prefab
    )

    local fancyprefab = player:GetFancyPrefabName()
    if type(fancyprefab) == "string" then
        PEARL.DB:SetField(
            player.userid, "lastprefabfancy", fancyprefab
        )
    end
end

local function OnPlayerDied(player)
    local userid = player.userid
    local deathscount = PEARL.DB:GetField(userid, "deathscount", 0)
    PEARL.DB:SetField(userid, "deathscount", deathscount + 1)
end

--- The World might be reloaded because of a regen.
local function OnWorldLoadedForClient(userid)
    SaveSessionInfoFor(userid)
end

local function OnNewSegmentSurvived(userid)
    local daysalive = PEARL.DB:GetField(userid, "daysalive", 0)
    local newdaysalive = daysalive + DAY_PERCENT_SEGMENT
    PEARL.DB:SetField(userid, "daysalive", newdaysalive)
    PEARL.Reputation:EarnFor(userid, PEARL.CONSTS.REPUTATION_TABLES.SEGMENT_SURVIVED)

    -- if math.floor(daysalive) < math.floor(newdaysalive) then
    --     OnNewDaySurvived(userid)
    -- end
end

local function OnNewDayPercentSegmentFor(userid)
    -- Always update the total days
    local totaldays = PEARL.DB:GetField(userid, "totaldays", 0)
    PEARL.DB:SetField(userid, "totaldays", totaldays + DAY_PERCENT_SEGMENT)

    local survived = true
    if PEARL.ServerNetwork:IsClientInactive(userid) then
        survived = false
        PEARL.Reputation:EarnFor(userid, PEARL.CONSTS.REPUTATION_TABLES.SEGMENT_AFK)
    end

    -- Do only increase the days alive for alive active players.
    if PEARL.ServerNetwork:IsClientGhost(userid) then
        survived = false
        PEARL.Reputation:EarnFor(userid, PEARL.CONSTS.REPUTATION_TABLES.SEGMENT_DEAD)
    end

    if survived then
        OnNewSegmentSurvived(userid)
    end
end

local function OnNewDayPercentSegment()
    -- Update only for players actually in the game (with a game instance)
    for _, player in ipairs(AllPlayers) do
        local userid = player.userid
        if userid ~= nil then
            OnNewDayPercentSegmentFor(userid)
        end
    end
end

local __dp = nil
local function OnWorldClockTick(world, data)
    local cp = data.time
    if __dp == nil then
        __dp = cp
        return
    end

    local delta = cp - __dp
    if delta >= .1 or delta <= -.1 then
        __dp = cp

        OnNewDayPercentSegment()
    end
end

-- Called before the actual saving so we have time to change some of the data.
local function OnSavingRecordFor(userid)
    SaveSessionInfoFor(userid)
end

local function OnCyclesChanged()
    for userid, _ in ipairs(PEARL.ServerNetwork:GetLocalClientIDs()) do
        OnWorldLoadedForClient(userid)
    end
end

--------------------------------------
-- [[ Hooks ]]
--------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("clientagreementdatareceived", OnClientAgreementDataReceived)

PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", OnClientDataRecevied)

PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)
PEARL.EventProcessor:AddSafeEventHandler("clientunbanned", OnClientUnbanned)

PEARL.EventProcessor:AddSafeEventHandler("clientprofiledata", OnClientProfileData)

PEARL.EventProcessor:AddSafeEventHandler("savingrecordfor", OnSavingRecordFor)

PEARL.AddWorldPostInit(function(world)
    -- Using this instead of NotifyPlayerPresence because that is really inaccurate.
    world:SafeListenForEvent("clocktick", OnWorldClockTick)

    world:ListenForModEvent("ms_clientconnected", OnClientConnected)
    world:SafeListenForEvent("ms_clientdisconnected", OnClientDisconnected)
    world:SafeListenForEvent("ms_playerdespawnandmigrate", OnClientMigrating)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", OnClientAuthenticationComplete)

    world:SafeListenForEvent("ms_playerdespawn", OnPlayerChanged)
    world:SafeListenForEvent("ms_playerspawn", OnPlayerChanged)

    world:SafeListenForEvent("cycleschanged", OnCyclesChanged)

    for userid, _ in ipairs(PEARL.ServerNetwork:GetLocalClientIDs()) do
        OnWorldLoadedForClient(userid)
    end
end)

PEARL.AddPlayerPostInit(function(player)
    player:SafeListenForEvent("death", OnPlayerDied)
end)
