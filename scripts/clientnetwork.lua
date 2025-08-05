--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


----------------------------------
-- Constants
----------------------------------

-- Give it a lot of time since we have the Steam profile checks now...
local TIMEOUT = 60 -- seconds

local DEFERANT = {
    VERIFICATION    = "verification",
    DISCONNECT      = "disconnect",
}

--- @type table<string, number>
local DISCONNECT_REASON_PRIORITIES = {
    -- Error reporting should have the highest priority,
    -- in case other more trivial disconnect reason pops up sooner.
    ["ID_DST_SERVER_CRASHED"] = math.huge,
}

----------------------------------
-- Netvars
----------------------------------

local _server_slots
PEARL.AddWorldNetworkPostInit(function(inst)
    if _server_slots == nil then
        _server_slots = net_byte(inst.GUID, "_server_slots")
        _server_slots:set_local(TheNet:GetServerMaxPlayers())
    end
end)

----------------------------------
-- Locals
----------------------------------

local _OnNetworkDisconnect = PEARL.GetGlobal("OnNetworkDisconnect")

local _disconnection_notified = false
local _disconnect_data = {}
--- @type string?
local _disconnect_reason = nil
local _disconnected = false
local _disconnected_by_server = false
local _force_disconnected = false
local _connection_allowed = false

--- @type table
local _connection_output_data = {}

local _hasrecord = false

--- @type Task?
local _timeout_task = nil

----------------------------------
-- Class Declaration
----------------------------------

--- @class ClientNetwork
local ClientNetwork = {}

----------------------------------
-- Local Functions
----------------------------------

local function OnSelfDisconnected(reason)
    return PEARL.SendRawRPCToServer(
        PEARL.RPC.ClientDisconnected, reason, _force_disconnected
    )
end

----------------------------------
-- Public
----------------------------------

function ClientNetwork:Disconnect(reason, from_server, immediate, reason_title)
    PEARL.info("ClientNetwork:Disconnect", reason, from_server)

    if self:IsDisconnected() then
        return PEARL.debug("Already disconnected...")
    end

    _disconnected_by_server = from_server == true or false
    _force_disconnected = true

    if not self:HasSentCFD() then
        -- In case we have been disconnected for invalid mods
        -- we still want to inform the server what mods did we used.
        -- We can't wait for FE here.
        self:SendCFDToServer()
    end

    self:CancelTimeout()
    -- This one should be actually permanent
    PEARL.ClientLoader:AddDeferant(DEFERANT.DISCONNECT)

    if type(reason_title) == "string" and type(reason) == "string" then
        local reason_body = reason
        reason = "ID_DST_DYNAMIC_REASON"

        STRINGS.UI.NETWORKDISCONNECT.TITLE[reason] = reason_title
        STRINGS.UI.NETWORKDISCONNECT.BODY[reason] = reason_body
    end

    -- Call this before the actual disconnecting so the RPCs can be sent.
    -- It should be safe to call it here because missing FE should be handled at this point.
    -- This should be the hooked up version.
    OnNetworkDisconnect(reason, true, immediate)

    TheNet:JoinServerResponse(true) -- true when disconnecting...
    TheNet:Disconnect(false)
end

function ClientNetwork:SendPlayerReportToServer(message, ...)
    PEARL.info("Sending player report to server...")
    return PEARL.SendRPCToServer(PEARL.RPC.PlayerReportMessage, message, ...)
end

--- @param traceback string?
--- @param catched boolean?
--- @param afflicter_modname strimg?
function ClientNetwork:SendErrorTracebackToServer(traceback, catched, afflicter_modname)
    PEARL.SendErrorTracebackToServer(traceback, catched, afflicter_modname)
end

--- CFD = Connection Filter Data = Client Filter Data
--- We are sending this data on the initial connection.
function ClientNetwork:SendCFDToServer()
    PEARL.info("Sending connection filter data to the server...")
    PEARL.SendRawRPCToServer(PEARL.RPC.ConnectionFilterData, ZipAndEncodeString(
        self:GetConnectionData()
    ))

    self:SetCFDSent(true)
    PEARL.ClientLoader:AddDeferant(DEFERANT.VERIFICATION)
    self:StartTimeout()
end

function ClientNetwork:GetConnectionData()
    return {
        enabled_mods    = KnownModIndex:GetModsReport(),
        locale          = TheNet:GetCountryCode(),
        username        = TheNet:GetLocalUserName(),
        platform        = PLATFORM,
    }
end

function ClientNetwork:NotifyNetworkDisconnect()
    PEARL.debug("ClientNetwork:NotifyNetworkDisconnect")
    _disconnection_notified = true

    -- Call the original non-hooked function to prevent any loops.
    return _OnNetworkDisconnect(unpack(_disconnect_data))
end

----------------------------------
-- Setters
----------------------------------

function ClientNetwork:SetCFDSent(sent)
    PEARL.GameInstParams:SetModParam("cfd_sent", sent)
end

function ClientNetwork:StartTimeout()
    if _timeout_task then
        return PEARL.debug("Timeout task already running!")
    end

    PEARL.debug("Starting timeout task!")
    _timeout_task = PEARL.StaticScheduler:ExecuteInTime(TIMEOUT,
        self.OnTimeout, nil, self
    )
end

function ClientNetwork:CancelTimeout()
    if _timeout_task ~= nil then
        _timeout_task:Cancel()
        _timeout_task = nil
    end
end

----------------------------------
-- Getters
----------------------------------

function ClientNetwork:IsWaitingForResponse()
    return _timeout_task ~= nil
end

function ClientNetwork:GetHostPerformance()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return (TheNet:GetClientTable() or {})[1].performance
end

function ClientNetwork:HasSentCFD()
    return PEARL.GameInstParams:GetCurrentModParam("cfd_sent") ~= nil
end

--- @return string?
function ClientNetwork:GetDisconnectReason()
    return _disconnect_reason
end

function ClientNetwork:IsDisconnected()
    return _disconnected or _disconnected_by_server or _force_disconnected
end

function ClientNetwork:JoinedFirstTime()
    if TheNet:GetIsServerAdmin() and not PEARL.CONFIG.DEBUG_MODE then
        return false
    end

    -- If agreement record exists for this player then it's definitely not a newcomer.
    if PEARL.AgreementManager:FileExists() and PEARL.AgreementManager:HasRecord() then
        return false
    end

    print("------------------------------------")
    print(_connection_output_data.first_time_joined, _connection_output_data.new_session_file)
    print("-----------------------------------")

    return _connection_output_data.first_time_joined == true and
           _connection_output_data.new_session_file == true
end

function ClientNetwork:JoinedFromLobby()
    return _connection_output_data.joined_from_lobby == true
end

----------------------------------
-- Handlers
----------------------------------

function ClientNetwork:OnTimeout()
    PEARL.info("ClientNetwork:OnTimeout")
    self:CancelTimeout()

    if _connection_allowed then
        return
    end

    PEARL.warn("Server response timed out!")
    if PEARL.CONFIG.FAIL_SAFE_NETWORK then
        return PEARL.info("Ignoring because of fail safe network configuration...")
    end

    -- Disconnect the client if we didn't get the response from the server in time.
    return self:Disconnect("ID_DST_SERVER_RESPONSE_TIMEOUT", false)
end

-- Note that it's common for servers to send multiple responses.
function ClientNetwork:OnConnectionAllowed(data)
    PEARL.info("ClientNetwork:OnConnectionAllowed", data)
    self:CancelTimeout()

    _connection_output_data = data

    if self:IsDisconnected() or _connection_allowed then
        return -- Server already responded - Ignore
    end

    _connection_allowed = true
    PEARL.EventProcessor:HandleEvent("connection_allowed", data)

    -- If the connection is allowed, remove the deferant
    -- potentially loading the client as well if we are the last one.
    return PEARL.ClientLoader:RemoveDeferant(DEFERANT.VERIFICATION)
end

----------------------------------
-- Pre/Post Call Handlers
----------------------------------

-- The widgets should be loaded at this point.
-- Call the defered OnNetworkDisconnect here!
PEARL.AddFrontEndPostInit(function(fe)
    -- All modules working with cfd should be loaded.
    if not ClientNetwork:HasSentCFD() then
        ClientNetwork:SendCFDToServer()
    end

    if table.empty(_disconnect_data) == false then
        return ClientNetwork:NotifyNetworkDisconnect()
    end
end)

PEARL.AddUserDataFunctionPreCall("Disconnect", function()
    _disconnected = true
end, TheNet)

-- Also try to let the server known why we have been disconnected.
-- In the tick this is being called, we should be able to still send some rpcs
-- if the server didn't kick our connetion already.
PEARL.OverrideGlobalVariable("OnNetworkDisconnect", function(reason, should_reset, immediate, ...)
    PEARL.debug("ClientNetwork: OnNetworkDisconnect")
    ClientNetwork:CancelTimeout()

    -- We have already showed a disconnection popup to the user
    -- Show only the first one.
    if _disconnection_notified then
        local old_reason_priority = tonumber(DISCONNECT_REASON_PRIORITIES[_disconnect_reason]) or 0
        local new_reason_priority = tonumber(DISCONNECT_REASON_PRIORITIES[reason]) or 0
        if old_reason_priority >= new_reason_priority then
            PEARL.debug("Already disconnected!")
            return false
        end
    end

    --- Only notify the server if he isn't the cause.
    if not _disconnected_by_server then
        OnSelfDisconnected(reason)
    end

    _disconnect_reason = reason
    _disconnect_data = {reason, should_reset, immediate, ...}

    -- If we have FE already loaded, there is nothing to wait for.
    -- Or if the restart should be immediate in which case we do not touch the FE at all.
    if (TheFrontEnd ~= nil or immediate) then
        ClientNetwork:NotifyNetworkDisconnect()
    else
        PEARL.debug("Deffering OnNetworkDisconnect until FE is ready...")
    end

    -- Call this after the potential popup is shown, so it can manage it.
    PEARL.EventProcessor:HandleEvent("connection_closed", reason)
end)

PEARL.OverrideUserdataFnReturn(TheNet, "GetServerMaxPlayers", function()
    local count =  tonumber(_server_slots and _server_slots:value() or nil)
    if type(count) == "number" and count > 0 then
        return count
    end

    -- Fallback to default if nil.
end, false, true)

----------------------------------
-- RPCs
----------------------------------

PEARL.RegisterRawServerRPC("ClientDisconnected")
PEARL.RegisterRawServerRPC("ConnectionFilterData")

----------------------------------
-- Game Instance Parameters
----------------------------------

-- Make the "waiting_for_response" flag persistent between instances,
-- in case the server restarts when someone just connects to it.
ClientNetwork:SetCFDSent(PEARL.GameInstParams:GetModParam("cfd_sent"))

----------------------------------
-- Return
----------------------------------

return ClientNetwork
