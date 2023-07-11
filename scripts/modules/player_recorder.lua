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

local function RecordClientConnectionData(userid, data)
    -- This is the place where we want to create the record if needed.
    PEARL.PlayerDB:EnsureRecordFor(userid)

    PEARL.PlayerDB:OptionalSafeSetField(userid, "lastmods", data.enabled_mods)
    PEARL.PlayerDB:OptionalSafeSetField(userid, "lastlocale", data.locale)
    PEARL.PlayerDB:OptionalSafeSetField(userid, "lastplatform", data.platform)

    -- Make sure these data are saved, because they are important.
    PEARL.PlayerDB:SaveRecordFor(userid)
end

function PEARL.RecordProfileData(userid, cb)
    local gameplaytime = 0

    local steamid = userid and TheNet:GetNetIdForUser(userid)
    if not steamid then
        return PEARL.error("Failed to get steam ID for", userid)
    end

    local function RecordGamePlayTime(data)
        if type(data.response.games) == "table" and #data.response.games > 0 then
            gameplaytime = gameplaytime + data.response.games[1].playtime_forever
        end
    end

    PEARL.SteamAPI:CreateDataQuerySequenceFor(steamid)

    PEARL.SteamAPI:AddQueryToSequence(
        steamid, QUERIES.P_PLAYTIME, RecordGamePlayTime, DONT_STARVE_TOGETHER_APPID
    )
    PEARL.SteamAPI:AddQueryToSequence(
        steamid, QUERIES.P_PLAYTIME, RecordGamePlayTime, DONT_STARVE_APPID
    )

    PEARL.SteamAPI:ExecuteDataQuerySequenceFor(steamid, function()
        -- This is in minutes!
        PEARL.PlayerDB:OptionalSafeSetField(userid, "gameplaytime", gameplaytime)

        if type(cb) == "function" then
            cb()
        end
    end)
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function OnClientDataRecevied(userid, data)
    return RecordClientConnectionData(userid, data)
end

local function OnClientAgreementFinished(data)
    -- Only record data if we have agreed and enabled data collection
    if data.agreed and data.datacollection then
        -- Create record if needed here!
        local record = PEARL.PlayerDB:GetRecordFor(data.userid)
        if record and not record.agreedintime then
            -- Note only the first agreed-in time
            record.agreedintime = data.agreedintime
        end

        -- Here we can finally save the data with clear mind.
        PEARL.PlayerDB:SaveRecordFor(data.userid, record)
    end
end

local function OnClientConnected(world, player)
    PEARL.PlayerDB:OptionalSafeSetFild(player.userid, "lastjoinedtime", os.time())

    local client = TheNet:GetClientTableForUser(player.userid)
    if not client or not client.name then
        return
    end

    -- Update this on every connect since it could possibly change.
    PEARL.PlayerDB:OptionalSafeSetField(player.userid, "username", client.name)
end

local function OnClientDisconnected(world, player)
    PEARL.PlayerDB:OptionalSafeSetField(player.userid, "lastseentime", os.time())
    PEARL.PlayerDB:SaveRecordFor(player.userid)
    PEARL.PlayerDB:UnloadRecord(player.userid) -- Free the memory
end

local function OnPlayerSpawned(world, player)
    if player.prefab ~= "" then
        PEARL.PlayerDB:OptionalSetField(
            player.userid, "lastprefab", player.prefab
        )
    end
end

local function OnSave()
    PEARL.info("Saving the database...")

    -- Save lastseentime, lastdays here as well, because we may be shutting down,
    -- or the server may crash during restarting/rollbacking
    local time_now = os.time()
    for _, client in ipairs(TheNet:GetClientTable()) do
        -- Skip the host
        if client.performance == nil then
            PEARL.PlayerDB:OptionalSafeSetField(client.userid, "lastseentime", time_now)
            PEARL.PlayerDB:SaveRecordFor(client.userid)
        end
    end
end

--------------------------------------
-- [[ Hooks ]]
--------------------------------------

PEARL.AddGlobalFunctionPreCall("NotifyPlayerPresence", function(game_mode, count, age, player)
    if not (type(player) == "table" and player:IsValid() and type(player.userid) == "string") and type(count) == "number" and count > 0 then
        return
    end

    local record = PEARL.PlayerDB:GetRecordFor(player.userid)
    if record then
        record.totaldays = record.totaldays + count
    end
end)

PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)
PEARL.EventProcessor:AddSafeEventHandler("quit", OnSave)

PEARL.EventProcessor:AddSafeEventHandler("clientagreementfinished", OnClientAgreementFinished)

PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", OnClientDataRecevied)

PEARL.AddWorldPostInit(function(world)
    world:ListenForModEvent("ms_clientconnected", OnClientConnected)
    world:SafeListenForEvent("ms_clientdisconnected", OnClientDisconnected)

    world:SafeListenForEvent("ms_playerdespawn", OnPlayerSpawned)
end)
