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

local QUERIES = PEARL.SteamAPI.QUERIES

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

function PEARL.RecordProfileData(userid, cb)
    local gameplaytime

    local steamid = userid and TheNet:GetNetIdForUser(userid)
    if not steamid then
        return PEARL.error("Failed to get steam ID for", userid)
    end

    local function RecordGamePlayTime(data)
        PEARL.debug("RecordGamePlayTime")
        table.dump(data)

        local games = type(data.response) == "table" and data.response.games
        local playtime = type(games) == "table" and #games > 0 and games[1].playtime_forever
        if type(playtime) == "number" and playtime > 0 then
            gameplaytime = (gameplaytime or 0) + playtime
        end
    end

    PEARL.SteamAPI:CreateDataQuerySequenceFor(steamid, function()
        if gameplaytime == 0 then
            gameplaytime = nil
        end

        -- This is in minutes!
        PEARL.DB:SafeSetField(userid, "gameplaytime", gameplaytime)

        if type(cb) == "function" then
            cb()
        end
    end)

    PEARL.SteamAPI:AddQueryToSequence(
        steamid, QUERIES.P_PLAYTIME, RecordGamePlayTime, DONT_STARVE_TOGETHER_APPID
    )
    PEARL.SteamAPI:AddQueryToSequence(
        steamid, QUERIES.P_PLAYTIME, RecordGamePlayTime, DONT_STARVE_APPID
    )
end

local function SaveSessionInfoFor(userid)
    PEARL.DB:SafeSetField(userid, "lastsessionid", TheNet:GetSessionIdentifier())
    PEARL.DB:SafeSetField(userid, "lastsnapshot", TheNet:GetCurrentSnapshot())
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function OnClientDataRecevied(userid, data)
    return RecordClientConnectionData(userid, data)
end

local function OnClientBanned(userid, reason, author, seconds)
    seconds = tonumber(seconds)
    local timenow = os.time()

    local bans = PEARL.DB:GetField(userid, "bans", {})
    bans[#bans] = {
        reason      = reason,
        author      = author,
        timestart   = timenow,
        timestop    = seconds and timenow + seconds or nil
    }
    PEARL.DB:SetField("bans", bans)

    -- Reset reputation value in case of an unban.
    PEARL.Reputation:SetFor(userid, PEARL.CONSTS.STARTING_REPUTATION)
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
    -- Maybe a pairs loop would be better here but then we would have to rely
    -- on the names provided by steamprofilechecker.
    -- This way, changing the names there won't break the DB.
    PEARL.DB:SafeSetField(userid, "profilecountrycode", data.loccountrycode)
    PEARL.DB:SafeSetField(userid, "profiletimecreated", data.timecreated)
    PEARL.DB:SafeSetField(userid, "profilerep", data.profilerep)
    PEARL.DB:SafeSetField(userid, "communityprofile", data.communityprofile)
    PEARL.DB:SafeSetField(userid, "avatar", data.avatar)
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

local function OnNewDaySurvived(userid)
    PEARL.debug("OnNewDaySurvived", userid)
    -- Add reputation for surviving days.
end

local function OnNewDayPercentSegment()
    for _, player in ipairs(AllPlayers) do
        local userid = player.userid

        -- Do only increase the days alive for alive active players.
        if not PEARL.ServerNetwork:IsClientGhost(userid) and not PEARL.ServerNetwork:IsClientInactive(userid) then
            local daysalive = PEARL.DB:GetField(userid, "daysalive", 0)
            local newdaysalive = daysalive + DAY_PERCENT_SEGMENT
            PEARL.DB:SetField(userid, "daysalive", newdaysalive)

            if math.floor(daysalive) < math.floor(newdaysalive) then
                OnNewDaySurvived(userid)
            end
        end

        local totaldays = PEARL.DB:GetField(userid, "totaldays", 0)
        PEARL.DB:SetField(userid, "totaldays", totaldays + DAY_PERCENT_SEGMENT)
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

--------------------------------------
-- [[ Hooks ]]
--------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("clientagreementdatareceived", OnClientAgreementDataReceived)

PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", OnClientDataRecevied)

PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)

PEARL.EventProcessor:AddSafeEventHandler("clientprofiledata", OnClientProfileData)

PEARL.AddWorldPostInit(function(world)
    -- Using this instead of NotifyPlayerPresence because that is really inaccurate.
    world:SafeListenForEvent("clocktick", OnWorldClockTick)

    world:ListenForModEvent("ms_clientconnected", OnClientConnected)
    world:SafeListenForEvent("ms_clientdisconnected", OnClientDisconnected)
    world:SafeListenForEvent("ms_playerdespawnandmigrate", OnClientMigrating)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", OnClientAuthenticationComplete)

    world:SafeListenForEvent("ms_playerdespawn", OnPlayerChanged)
    world:SafeListenForEvent("ms_playerspawn", OnPlayerChanged)

    for _, client in ipairs(PEARL.ServerNetwork:GetConnectedClients()) do
        OnWorldLoadedForClient(client.userid)
    end
end)

PEARL.AddPlayerPostInit(function(player)
    player:SafeListenForEvent("death", OnPlayerDied)
end)
