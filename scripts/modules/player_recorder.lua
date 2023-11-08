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

local QUERIES = PEARL.SteamAPI.QUERIES

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

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function OnClientDataRecevied(userid, data)
    return RecordClientConnectionData(userid, data)
end

local function OnClientBanned(userid)
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

    local client = TheNet:GetClientTableForUser(player.userid)
    if not client or not client.name then
        return
    end

    -- Update this on every connect since it could possibly change.
    PEARL.DB:SafeSetField(player.userid, "username", client.name)
end

local function OnClientDisconnected(world, player)
    -- No loading here! Also the userid can be nil or an empty string.
    if PEARL.DB:IsRecordLoadedFor(player.userid) then
        PEARL.DB:SafeSetField(player.userid, "lastseentime", os.time())
        PEARL.DB:SaveRecordFor(player.userid)
        PEARL.DB:UnloadRecord(player.userid) -- Free the memory
    end
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

--------------------------------------
-- [[ Hooks ]]
--------------------------------------

PEARL.AddGlobalFunctionPreCall("NotifyPlayerPresence", function(game_mode, count, age, player)
    if not (type(player) == "table" and player:IsValid() and player.userid ~= "") then
        return
    end

    count = tonumber(count)
    if count and count > 0 then
        local record = PEARL.DB:GetRecordFor(player.userid)
        if record then
            record.totaldays = record.totaldays + count
        end
    end
end)

PEARL.EventProcessor:AddSafeEventHandler("clientagreementdatareceived", OnClientAgreementDataReceived)

PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", OnClientDataRecevied)

PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)

PEARL.EventProcessor:AddSafeEventHandler("clientprofiledata", OnClientProfileData)

PEARL.AddWorldPostInit(function(world)
    world:ListenForModEvent("ms_clientconnected", OnClientConnected)
    world:SafeListenForEvent("ms_clientdisconnected", OnClientDisconnected)

    world:SafeListenForEvent("ms_playerdespawn", OnPlayerChanged)
    world:SafeListenForEvent("ms_playerspawn", OnPlayerChanged)
end)
