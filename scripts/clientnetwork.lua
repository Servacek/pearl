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
    _server_slots = net_byte(inst.GUID, "_server_slots")
    _server_slots:set_local(TheNet:GetServerMaxPlayers())
end)

----------------------------------
-- Locals
----------------------------------

local _OnNetworkDisconnect = PEARL.GetGlobal("OnNetworkDisconnect")

local disconnection_notified = false
local disconnect_data = {}
local disconnect_reason = nil
local disconnected = false
local disconnected_by_server = false
local force_disconnected = false
local connection_allowed = false

local _hasrecord = false

local cfd = {}

--- @type Task?
local timeout_task = nil

----------------------------------
-- Class Declaration
----------------------------------

--- @class ClientNetwork
local ClientNetwork = {}

----------------------------------
-- Public
----------------------------------

function ClientNetwork:Disconnect(reason, from_server, immediate, reason_title)
    PEARL.info("ClientNetwork:Disconnect", reason, from_server)

    if self:IsDisconnected() then
        return PEARL.debug("Already disconnected...")
    end

    disconnected_by_server = from_server == true or false
    force_disconnected = true

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
    if type(cfd) ~= "table" then
        return PEARL.error("Attempted to send invalid CFD data to server!")
    end

    self:BuildCFD()
    PEARL.info("Sending connection filter data to the server...")
    PEARL.SendRawRPCToServer(PEARL.RPC.ConnectionFilterData, ZipAndEncodeString(cfd))

    self:SetCFDSent(true)
    PEARL.ClientLoader:AddDeferant(DEFERANT.VERIFICATION)
    self:StartTimeout()
end

function ClientNetwork:SendAgreementData(agreed, datacollection, agreedintime, version)
    PEARL.SendRPCToServer(
        PEARL.RPC.AgreementDataReceived, agreed, datacollection, agreedintime, version
    )
end

function ClientNetwork:BuildCFD()
    cleartable(cfd)

    cfd.enabled_mods    = KnownModIndex:GetModsReport()

    cfd.locale          = TheNet:GetCountryCode()
    cfd.username        = TheNet:GetLocalUserName()

    cfd.platform        = PLATFORM

    return cfd
end

function ClientNetwork:NotifyNetworkDisconnect()
    PEARL.debug("ClientNetwork:NotifyNetworkDisconnect")
    disconnection_notified = true

    -- Call the original non-hooked function to prevent any loops.
    return _OnNetworkDisconnect(unpack(disconnect_data))
end

----------------------------------
-- Setters
----------------------------------

-- function ClientNetwork:SetIsWaitingForResponse(waiting)
--     PEARL.GameInstParams:SetModParam("waiting_for_response", waiting)
-- end

function ClientNetwork:SetIsConnectionAllowed(allowed)
    connection_allowed = allowed
end

function ClientNetwork:SetCFDSent(sent)
    PEARL.GameInstParams:SetModParam("cfd_sent", sent)
end

function ClientNetwork:SetDisconnectionData(data)
    disconnect_data = data
end

function ClientNetwork:SetDisconnectioReason(reason)
    disconnect_reason = reason
end

function ClientNetwork:StartTimeout()
    if timeout_task then
        return PEARL.debug("Timeout task already running!")
    end

    PEARL.debug("Starting timeout task!")
    timeout_task = PEARL.StaticScheduler:ExecuteInTime(TIMEOUT,
        self.OnTimeout, nil, self
    )
end

function ClientNetwork:CancelTimeout()
    if timeout_task ~= nil then
        timeout_task:Cancel()
        timeout_task = nil
    end
end

----------------------------------
-- Getters
----------------------------------
function ClientNetwork:IsConnectionAllowed()
    return connection_allowed
end

function ClientNetwork:IsWaitingForResponse()
    return timeout_task ~= nil
end

function ClientNetwork:GetHostPerformance()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return TheNet:GetClientTable()[1].performance
end

function ClientNetwork:HasSentCFD()
    return PEARL.GameInstParams:GetCurrentModParam("cfd_sent") ~= nil
end

--- @return string?
function ClientNetwork:GetDisconnectReason()
    return disconnect_reason
end

function ClientNetwork:IsDisconnected()
    return disconnected or disconnected_by_server or force_disconnected
end

function ClientNetwork:JoinedFirstTime()
    if TheNet:GetIsServerAdmin() and not PEARL.CONFIG.DEBUG_MODE then
        return false
    end

    -- If agreement record exists for this player then it's definitely not a newcomer.
    if PEARL.AgreementManager:FileExists() and PEARL.AgreementManager:HasRecord() then
        return false
    end

    return _hasrecord
end

----------------------------------
-- Handlers
----------------------------------

function ClientNetwork:OnTimeout()
    PEARL.info("ClientNetwork:OnTimeout")
    self:CancelTimeout()

    if self:IsConnectionAllowed() then
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
function ClientNetwork:OnConnectionAllowed(initial)
    PEARL.info("ClientNetwork:OnConnectionAllowed", initial)
    self:CancelTimeout()

    -- This is for backwards compatibility when the database
    -- doesn't have a record yet but we have already agreed to the agreement.
    _hasrecord = initial == false
    if initial == true and PEARL.AgreementManager:HasRecord() then
        local version = PEARL.AgreementManager:GetLocalVersion()
        self:SendAgreementData(true, true, nil, version)
    end

    if self:IsDisconnected() or self:IsConnectionAllowed() then
        return -- Server already responded - Ignore
    end

    self:SetIsConnectionAllowed(true)
    PEARL.EventProcessor:HandleEvent("connection_allowed", initial)

    -- If the connection is allowed, remove the deferant
    -- potentially loading the client as well if we are the last one.
    return PEARL.ClientLoader:RemoveDeferant(DEFERANT.VERIFICATION)
end

function ClientNetwork:OnConnectionClosed(reason)
    return PEARL.SendRawRPCToServer(PEARL.RPC.ClientDisconnected, reason, force_disconnected)
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

    if table.empty(disconnect_data) == false then
        return ClientNetwork:NotifyNetworkDisconnect()
    end
end)

PEARL.AddUserDataFunctionPreCall("Disconnect", function()
    disconnected = true
end, TheNet)

-- Also try to let the server known why we have been disconnected.
-- In the tick this is being called, we should be able to still send some rpcs
-- if the server didn't kick our connetion already.
PEARL.OverrideGlobalVariable("OnNetworkDisconnect", function(reason, should_reset, immediate, ...)
    PEARL.debug("ClientNetwork: OnNetworkDisconnect")
    ClientNetwork:CancelTimeout()

    -- We have already showed a disconnection popup to the user
    -- Show only the first one.
    if disconnection_notified then
        local old_reason_priority = tonumber(DISCONNECT_REASON_PRIORITIES[disconnect_reason]) or 0
        local new_reason_priority = tonumber(DISCONNECT_REASON_PRIORITIES[reason]) or 0
        if old_reason_priority >= new_reason_priority then
            PEARL.debug("Already disconnected!")
            return false
        end
    end

    --- Only notify the server if he isn't the cause.
    if not disconnected_by_server then
        ClientNetwork:OnConnectionClosed(reason)
    end

    ClientNetwork:SetDisconnectioReason(reason)
    -- Record only the first disconnection
    ClientNetwork:SetDisconnectionData({
        reason, should_reset, immediate, ...
    })

    -- If we have FE already loaded, there is nothing to wait for.
    -- Or if the restart should be immediate in which case we do not touch the FE at all.
    -- Show only the first popup.
    if (TheFrontEnd ~= nil or immediate) then
        return ClientNetwork:NotifyNetworkDisconnect()
    end

    -- If we have no FE then do not execute this yet.
    -- It would cause a crash...
    PEARL.debug("Deffering OnNetworkDisconnect")
end)

PEARL.OverrideUserdataFnReturn(TheNet, "GetServerMaxPlayers", function()
    local count =  tonumber(_server_slots and _server_slots:value())
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
