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
local function OnSynchronousFiltersDoneFor(userid, allowed, data)
    if allowed == false then
        return -- Do not create new records when we fail
    end

    -- This is the place where we want to create the record if needed.
    if not PEARL.DB:HasRecordFile(userid) then
        if not PEARL.DB:CreateRecordFor(userid) then
            return -- We have failed to create the record.
        end

        PEARL.Reputation:ResetFor(userid)
    end

    PEARL.DB:SafeSetField(userid, "lastmods", data.enabled_mods)
    PEARL.DB:SafeSetField(userid, "lastlocale", data.locale)
    PEARL.DB:SafeSetField(userid, "lastplatform", data.platform)

    -- Make sure these data are saved, because they are important.
    PEARL.DB:SaveRecordFor(userid)
end

local function SaveSessionInfoFor(userid)
    local sessionid = TheNet:GetSessionIdentifier()
    if sessionid ~= nil then
        PEARL.AccountBindings:AddBinding(userid, sessionid, PEARL.AccountBindings.BINDING_TYPE.SESSIONID)
    end

    PEARL.DB:SafeSetField(userid, "lastsnapshot", TheNet:GetCurrentSnapshot())
    if TheWorld and TheWorld.state then
        PEARL.DB:SafeSetField(userid, "lastcycle", TheWorld.state.cycles)
    end
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

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
    PEARL.DB:SaveRecordFor(userid)
end

local function OnClientUnbanned(userid)
    PEARL.debug("OnClientUnbanned", userid)

    local bans = PEARL.DB:GetField(userid, "bans")
    -- Try to get the latest ban.
    local lastban = type(bans) == "table" and bans[#bans]
    if not lastban then
        return
    end

    lastban.timestop = os.time()
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

local function OnClientConnectionAllowed(userid, data)
    PEARL.DB:SafeSetField(userid, "lastjoinedtime", os.time())
    SaveSessionInfoFor(userid)
end

local function OnRecordLoadedFor(userid, record)
    local lastban = record and record:GetLastBan()
    local banned = PEARL.BlackList:Contains(userid)
    -- In case the user was unbanned manually by removing the userid from the blocklist.txt file.
    if lastban and lastban.timestop == nil and not banned then
        OnClientUnbanned(userid)
    elseif (not lastban or lastban.timestop ~= nil) and banned then
        OnClientBanned(userid)
    end
end

local function OnClientAuthenticationComplete(world, data)
    local userid = data and data.userid
    if PEARL.DB:IsRecordCachedFor(userid) then
        -- Set this as soon as possible.
        PEARL.DB:SafeSetField(userid, "lastshardid", tostring(PEARL.SHARDID))
        PEARL.DB:SaveRecordFor(userid)
    end

    -- Update this on every authentication since it could possibly change.
    local client = userid and TheNet:GetClientTableForUser(userid)
    if client and client.name then
        PEARL.AccountBindings:AddBinding(userid, client.name, PEARL.AccountBindings.BINDING_TYPE.USERNAME)
    end

    local netid = client and client.netid or userid and TheNet:GetNetIdForUser(userid)
    if netid then
        PEARL.AccountBindings:AddBinding(userid, netid, PEARL.AccountBindings.BINDING_TYPE.STEAMID)
    end
end

local function OnClientDisconnected(userid, expected)
    -- No loading here! Also the userid can be nil or an empty string.
    if PEARL.DB:IsRecordCachedFor(userid) then
        if expected == false then
            PEARL.DB:SafeSetField(userid, "last_unexpected_disconnection", os.time())
        end

        PEARL.DB:SafeSetField(userid, "lastseentime", os.time())

        PEARL.DB:SaveRecordFor(userid)
        PEARL.DB:UnloadRecord(userid) -- Free the memory
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

    if type(data.profilerep) == "number" then
        local FILTER = PEARL.CONFIG.PROFILE_FILTER
        local profilerep = math.clamp(data.profilerep, FILTER.MIN_REPUTATION, FILTER.MAX_REPUTATION)

        --- So that players with bad profiles are closer to a ban in case they start to be nasty.
        PEARL.Reputation:DoDeltaTo(userid, profilerep)
    end

    -- These data are quite important so we do not want to lose them!
    PEARL.DB:SaveRecordFor(userid)
end

local function OnPlayerChanged(world, player, ...)
    -- Always save this field since we use it as fallback for the fancy version.
    if player.prefab == nil or player.userid == nil or player.userid == "" then
        return
    end

    PEARL.DB:SetField(player.userid, "lastprefab", player.prefab)

    local fancyprefab = player:GetFancyPrefabName()
    if type(fancyprefab) == "string" then
        PEARL.DB:SetField(player.userid, "lastprefabfancy", fancyprefab)
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
    -- Save lastseentime, lastdays here as well, because we may be shutting down,
    -- or the server may crash during restarting/rollbacking

    if PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        -- These do only make sense when the player is connected.
        PEARL.DB:SafeSetField(userid, "lastseentime", os.time())

        SaveSessionInfoFor(userid)
    end
end

local function OnCyclesChanged()
    for userid, _ in pairs(PEARL.ServerNetwork:GetLocalClientIDs()) do
        OnWorldLoadedForClient(userid)
    end
end

local function OnUserSessionSerialized(userid)
    if PEARL.DB:IsRecordCachedFor(userid) then
        PEARL.DB:SaveRecordFor(userid)
    end
end

--------------------------------------
-- [[ Hooks ]]
--------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("clientagreementdatareceived", OnClientAgreementDataReceived)

PEARL.EventProcessor:AddSafeEventHandler("synchronousfiltersdone", OnSynchronousFiltersDoneFor)

PEARL.EventProcessor:AddSafeEventHandler("db_recordloaded", OnRecordLoadedFor)

PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)
PEARL.EventProcessor:AddSafeEventHandler("clientunbanned", OnClientUnbanned)

PEARL.EventProcessor:AddSafeEventHandler("clientprofiledata", OnClientProfileData)

PEARL.EventProcessor:AddSafeEventHandler("db_savingrecord", OnSavingRecordFor)

PEARL.EventProcessor:AddSafeEventHandler("seriliaze_user_session", OnUserSessionSerialized)
PEARL.EventProcessor:AddSafeEventHandler("ms_clientdisconnected", OnClientDisconnected)
PEARL.EventProcessor:AddSafeEventHandler("clientconnectionallowed", OnClientConnectionAllowed)

PEARL.AddWorldPostInit(function(world)
    -- Using this instead of NotifyPlayerPresence because that is really inaccurate.
    world:SafeListenForEvent("clocktick", OnWorldClockTick)

    world:SafeListenForEvent("ms_playerdespawnandmigrate", OnClientMigrating)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", OnClientAuthenticationComplete)

    world:ListenForEventDelayed("ms_playerdespawn", OnPlayerChanged)
    world:ListenForEventDelayed("ms_playerspawn", OnPlayerChanged)

    world:SafeListenForEvent("cycleschanged", OnCyclesChanged)

    for userid, _ in pairs(PEARL.ServerNetwork:GetLocalClientIDs()) do
        OnWorldLoadedForClient(userid)
    end
end)

local function OnFlagsModified(self)
    local userid = self:GetUserID()
    local player = LookupPlayerInstByUserID(userid)
    if player and TheWorld then
        OnPlayerChanged(TheWorld, player)
    end
end

-- These are not really "Classes" so just use the generic post-calls.
PEARL.AddFunctionPostCall("AddUserFlag", OnFlagsModified, Network)
PEARL.AddFunctionPostCall("RemoveUserFlag",OnFlagsModified, Network)

PEARL.AddPlayerPostInit(function(player)
    player:SafeListenForEvent("death", OnPlayerDied)
end)
