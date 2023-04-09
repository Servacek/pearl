--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



----------------------------------
-- Constants
----------------------------------

local TIMEOUT = 15 -- seconds

----------------------------------
-- Locals
----------------------------------

local _OnNetworkDisconnect = PEARL.GetGlobal("OnNetworkDisconnect")

local disconnection_notified = false
local disconnect_data = {}
local disconnected = false
local disconnected_by_server = false
local force_disconnected = false
local connection_allowed = false

local cfd = {}

--- @type Task?
local timeout_task = nil

----------------------------------
-- Class Declaration
----------------------------------

--- @class ClientNetwork
local ClientNetwork = {
    --- @type ClientLoader
    loader = PEARL.loadfile("clientloader")
}

----------------------------------
-- Public
----------------------------------

function ClientNetwork:Disconnect(reason, from_server, immediate)
    PEARL.info("ClientNetwork:Disconnect", reason, from_server)

    if self:IsDisconnected() then
        return PEARL.debug("Already disconnected...")
    end

    disconnected_by_server = from_server == true or false
    force_disconnected = true

    --self:SetIsWaitingForResponse(false)
    if not self:HasSentCFD() then
        -- In case we have been disconnected for invalid mods
        -- we still want to inform the server what mods did we used.
        -- We can't wait for FE here.
        self:SendCFDToServer()
    end

    self:CancelTimeout()
    self.loader:DefferLoad()

    -- Call this before the actual disconnecting so the RPCs can be sent.
    -- It should be safe to call it here because missing FE should be handled at this point.
    OnNetworkDisconnect(reason, true, immediate)

    TheNet:JoinServerResponse(true) -- true when disconnecting...
    TheNet:Disconnect(false)
end

function ClientNetwork:SendPlayerReportToServer(message, ...)
    PEARL.info("Sending player report to server...")
    return PEARL.SendRPCToServer(PEARL.RPC.PlayerReportMessage, message, ...)
end

function ClientNetwork:SendErrorTracebackToServer(traceback, ...)
    return PEARL.SendErrorTracebackToServer(traceback, ...)
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
    self.loader:DefferLoad()
    self:StartTimeout()
end

function ClientNetwork:BuildCFD()
    cleartable(cfd)

    cfd.enabled_mods    = KnownModIndex:GetModsReport()

    cfd.locale          = TheNet:GetCountryCode()
    cfd.username        = TheNet:GetLocalUserName()

    cfd.novice          = self:IsNovice()

    return cfd
end

function ClientNetwork:NotifyNetworkDisconnect()
    PEARL.debug("ClientNetwork:NotifyNetworkDisconnect")
    if not disconnection_notified then
        disconnection_notified = true

        -- Call the original non-hooked function to prevent any loops.
        return _OnNetworkDisconnect(unpack(disconnect_data))
    end
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

function ClientNetwork:GetHostPerformance()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return TheNet:GetClientTable()[1].performance
end

function ClientNetwork:HasSentCFD()
    return PEARL.GameInstParams:GetCurrentModParam("cfd_sent") ~= nil
end

function ClientNetwork:GetCFD()
    return cfd
end

-- function ClientNetwork:IsWaitingForResponse()
--     return PEARL.GameInstParams:GetCurrentModParam("waiting_for_response") == nil
-- end

function ClientNetwork:IsDisconnected()
    return disconnected or disconnected_by_server or force_disconnected
end

function ClientNetwork:IsNovice()
    if TheNet:GetIsServerAdmin() then
        return false
    end

    if PEARL.AgreementManager:FileExists() then
        if PEARL.AgreementManager:HasAnyRecords() then
            return not PEARL.AgreementManager:HasRecord()
        end

        -- If the file exists but it's empty, this is most likely not a novice.
        return false
    end

    return true
end

----------------------------------
-- Handlers
----------------------------------

function ClientNetwork:OnTimeout()
    PEARL.info("Server response timed out!")
    -- Disconnect the client if we didn't get the response from the server in time.
    return self:OnResponse(
        false, PEARL.CONFIG.FAIL_SAFE_NETWORK, "ID_DST_SERVER_RESPONSE_TIMEOUT"
    )
end

-- Note that it's common for servers to send multiple responses.
function ClientNetwork:OnResponse(from_server, allowed, reason, ...)
    PEARL.info("ClientNetwork:OnResponse", allowed)
    self:CancelTimeout()

    if self:IsDisconnected() or (allowed and self:IsConnectionAllowed()) then
        return -- Server already responded - Ignore
    end

    if allowed == true then
        self:SetIsConnectionAllowed(allowed)

        -- If the connection is allowed, then load the client I guess.
        self.loader:CancelDeffer()
        return self.loader:ForceLoad()
    end

    self:Disconnect(reason, from_server, ...)
end

function ClientNetwork:OnConnectionClosed(reason)
    return PEARL.SendRawRPCToServer(PEARL.RPC.ClientDisconnected, reason, force_disconnected)
end

----------------------------------
-- Pre/Post Call Handlers
----------------------------------

-- The widgets should be loaded at this point.
-- Call the defered OnNetworkDisconnect here!
-- Also all RPCS are loaded as well, so send the CFD too!
PEARL.AddFrontEndPostInit(function(fe)
    -- All modules working with cfd should be loaded.
    if PEARL.CONFIG.SERVER_REQUIRE_CFD and not ClientNetwork:HasSentCFD() then
        ClientNetwork:SendCFDToServer()
    end

    if not IsTableEmpty(disconnect_data) then
        return ClientNetwork:NotifyNetworkDisconnect()
    end
end)

PEARL.AddUserDataFunctionPreCall("Disconnect", function()
    disconnected = true
end, TheNet)

-- Also try to let the server known why we have been disconnected.
-- In the tick this is being called, we should be able to still send some rpcs
-- if the server didn't kick our connetion already.
PEARL.OverrideVariable("OnNetworkDisconnect", function(reason, should_reset, immediate, ...)
    ClientNetwork:CancelTimeout()

    -- We have already showed a disconnection popup to the user
    -- Show only the first one.
    if disconnection_notified then
        PEARL.debug("Already disconnected!")
        return false
    end

    --- Only notify the server if he isn't the cause.
    if not disconnected_by_server then
        ClientNetwork:OnConnectionClosed(reason)
    end

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
end, _G)

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
