--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local GRACEFULL_DISCONNECT_REASON = {
    ["ID_DST_DISCONNECT_REQUESTED"] = true
}

----------------------------------
-- Network Callbacks
----------------------------------
-- Returning false here will cause the client to be disconnected immediately.
-- The "Slots Reserved" popup will be displayed.
-- Start the timeout here since we are sure that this is being only called when joining.
-- After this is called, the OnClientDisconnected event will ALWAYS follow.
--
-- Always called ONLY on the MASTER shard.
PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid, ...)
    PEARL.debug("JoinServerFilter", userid, ...)

    if PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        return -- If the user is already connected then ignore this call.
    end

    local passed = PEARL.ServerNetwork:RunJoinServerFiltersFor(userid)
    if passed == false then
        return false -- Prevent client from joining. Displaying the "not whitelisted" popup.
    end

    PEARL.ServerNetwork:OnClientJoining(userid)

    -- Let the default callback to handle this case.
end)

-- Used by the engine to notify lua on the master shard
-- that a secondary shard has changed it's state. This also notifies the shard itself.
PEARL.AddGlobalFunctionPreCall("Shard_UpdateWorldState", function(world_id, state, ...)
    PEARL.EventProcessor:HandleEvent(
        state == REMOTESHARDSTATE.READY and "shard_connected" or "shard_disconnected", world_id, ...
    )

    PEARL.EventProcessor:HandleEvent("shard_stateupdate", world_id, state, ...)
end)

PEARL.EventProcessor:AddSafeEventHandler("quit", function()
    PEARL.ServerNetwork:OnQuit()
end)

-- Filter out prohibited commands recevied by the server.
PEARL.AddGlobalFunctionPreCall("Networking_SlashCmd", function(guid, userid, cmd)
    -- Returning false means the command will be skipped.
    return PEARL.ServerNetwork:IsAdmin(userid) or PEARL.CONFIG.COMMAND_BLOCKLIST[cmd] ~= true
end)

PEARL.AddUserDataFunctionPostCall("SetDefaultMaxPlayers", function(self, value)
    local slots = tonumber(TheNet:GetDefaultMaxPlayers() or nil)
    if slots then
        PEARL.ServerNetwork:SetClientSlots(slots)
    end
end, TheNet)

PEARL.AddUserDataFunctionPreCall("SerializeUserSession", function(self, userid)
    PEARL.debug("Serializing user session for", userid)

    PEARL.EventProcessor:HandleEvent("seriliaze_user_session", userid)
end, TheNet)

-- PEARL.AddUserDataFunctionPreCall("DeserializeUserSession", function(self, userid)
--     PEARL.debug("Deserializing user session for", userid)
-- end, TheNet)

-- We want to have full control over this function on servers.
PEARL.OverrideVariable("ExecuteConsoleCommand", function(fnstr, guid, x, z)
    local saved_ThePlayer
    if guid ~= nil then
        saved_ThePlayer = ThePlayer
        ThePlayer = guid ~= nil and Ents[guid] or nil
    end
    TheInput.overridepos = (x ~= nil and z ~= nil and Vector3(x, 0, z)) or nil

    local success = false
    local fn, response = loadstring(fnstr)
    if fn then
        success, response = pcall(fn)
    end

    if success == true then
        local doer = Ents[guid]
        if doer then
            doer:PushModEvent("ms_commandexecuted", fnstr)
        end
    else
        nolineprint(response)
    end

    if guid ~= nil then
        ThePlayer = saved_ThePlayer
    end
    TheInput.overridepos = nil
end)

----------------------------------
-- World Network Events
----------------------------------

-- TheWorld is still nil when this is called.
PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    world:SafeListenForEvent("ms_save", function(...)
        PEARL.EventProcessor:HandleEvent("save", ...)
    end)

    -- This actually runs after we enter the game world, not lobby.
    world:SafeListenForEvent("ms_playerjoined", function(self, player)
        if player and player.userid then
            PEARL.ServerNetwork:OnClientJoined(player.userid)
        end
    end)

    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(self, data)
        if data and data.userid then
            PEARL.debug("OnClientAuthenticationComplete", data.userid)

            PEARL.ServerNetwork:OnClientAuthenticationComplete(data.userid)
        end

        PEARL.EventProcessor:HandleEvent("ms_clientauthenticationcomplete", data.userid)
    end)

    -- Called everytime even when banned but with no info.
    world:SafeListenForEvent("ms_clientdisconnected", function(self, data)
        -- data.expected is not supplied by the game, we use for testing.
        PEARL.debug("ClientOnDisconnected", data.userid, data.expected)

        if data and data.userid then
            print("CONNECTED", PEARL.ServerNetwork:IsClientConnected(data.userid))
            if PEARL.ServerNetwork:IsClientConnected(data.userid) then
                data.expected = false
            end

            PEARL.ServerNetwork:OnClientDisconnectedLocally(data.userid)
            PEARL.EventProcessor:HandleEvent("ms_clientdisconnected", data.userid, data.expected)
        end
    end)

    world:SafeListenForEvent("ms_playerdisconnected", function(self, data)
        -- This seems to be always false...
        PEARL.debug("ms_playerdisconnected", data.player, data.wasExpected)
    end)

    world:SafeListenForEvent("invalidrpc", function(self, data)
        PEARL.ServerNetwork:OnInvalidRPCFromClient(data.rpc_name, data.userid)
    end)

    world:SafeListenForEvent("ms_playerdespawnandmigrate", function(world, data)
        local userid = data and data.player and data.player.userid
        if userid then
            PEARL.ServerNetwork:OnClientDisconnectedLocally(userid)
        end
    end)

    local was_paused_by = nil
    world:SafeListenForEvent("serverpauseddirty", function(self, data)
        if table.empty(data) == false then
            if not was_paused_by and data.pause then
                PEARL.EventProcessor:HandleEvent("server_paused", data.source)
            elseif was_paused_by and not data.pause then
                PEARL.EventProcessor:HandleEvent("server_unpaused", was_paused_by)
            end

            was_paused_by = not tostring(data.source):empty() and data.source or nil
        end
    end)

    ---------------------------
    -- Mod Events
    ---------------------------

    world:ListenForModEvent("clientconnectionclosed", function(self, data)
        PEARL.debug("clientconnectionclosed", data.userid, data.reason)

        if not data and not data.userid then
            return
        end

        PEARL.ServerNetwork:OnClientDisconnectedLocally(data.userid)
        PEARL.EventProcessor:HandleEvent("clientconnectionclosed", data.userid, data.reason)
    end)
end)

--- @NOTE when connecting directly, make sure the server is fully loaded before clients can connect.
-- TheNet:SetAllowIncomingConnections(false)
-- PEARL.AddSimPostInit(function()
--     TheNet:SetAllowIncomingConnections(true)
-- end)

----------------------------------
-- RPC Handlers
----------------------------------

PEARL.AddRawServerUseridRPCHandler("ClientDisconnected", function(userid, reason, force)
    PEARL.debug("RPC: ClientDisconnected", userid, reason, force)
    if not (optstring(reason) and optbool(force)) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ClientDisconnected", userid)
    end

    if GRACEFULL_DISCONNECT_REASON[reason] then
        return PEARL.ServerNetwork:OnClientDisconnectedLocally(userid)
    end

    PEARL.debug("RPC: ClientDisconnected", reason, force)
    if not PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        return PEARL.debug("Already disconnected...")
    end

    PEARL.EventProcessor:HandleEvent("clientconnectionclosed", userid, reason, force)
end)

--- Since the players are always only on one shard,
--- we load the db record only on the active shard and unload it everywhere else.
--- This way there are no conflicts and the DB is accessible from any shard.
PEARL.AddRawServerUseridRPCHandler("ConnectionFilterData", function(userid, data)
    if not checkstring(data) then
        return PEARL.ServerNetwork:OnInvalidRPCFromClient("ConnectionFilterData", userid)
    end

    return PEARL.ServerNetwork:OnRawConnectionData(userid, data)
end)
