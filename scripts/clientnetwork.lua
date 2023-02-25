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
local disconnecting = false
local disconnect_data = {}
local disconnected_by_server = false
local force_disconnected = false

local cfd = {}
local cfd_sent = false
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

    if PEARL.CONFIG.SERVER_REQUIRE_CFD and not self:HasSentCFD() then
        -- In case we have been disconnected for invalid mods
        -- we still want to inform the server what mods did we used.
        -- We can't wait for FE here.
        self:SendCFDToServer()
    end

    self:CancelTimeout()
    self:SetIsWaitingForResponse(false)
    self.loader:DefferLoad()

    -- Call this before the actual disconnecting so the RPCs can be sent.
    -- It should be safe to call it here because missing FE should be handled at this point.
    OnNetworkDisconnect(reason, true, immediate)

    TheNet:JoinServerResponse(true) -- true when disconnecting...
    TheNet:Disconnect(false)

    DisableRPCSending()
    SetPause(true)

    disconnecting = true
end

function ClientNetwork:SendPlayerReportToServer(message, ...)
    return PEARL.SendRPCToServer(PEARL.RPCS.PlayerReportMessage, message)
end

function ClientNetwork:SendErrorTracebackToServer(traceback, ...)
    PEARL.info("Sending the error traceback to the server...")

    PEARL.SendRPCToServer(PEARL.RPCS.ClientError, TheSim:ZipAndEncodeString(traceback), ...)
end

--- CFD = Connection Filter Data = Client Filter Data
--- We are sending this data after every FE post init.
function ClientNetwork:SendCFDToServer()
    if TheNet:GetIsServer() or type(cfd) ~= "table" or IsTableEmpty(cfd) then
        return
    end

    PEARL.info("Sending connection filter data to the server...")
    PEARL.SendRPCToServer(PEARL.RPCS.ConnectionFilterData, ZipAndEncodeString(cfd))
    self:SetCFDSent(true)

    if self:IsWaitingForResponse() then
        self.loader:DefferLoad()
        self:StartTimeout()
    end
end

function ClientNetwork:LoadDefaultCFD()
    cfd.locale      = TheNet:GetCountryCode()
    cfd.ping        = TheNet:GetPing()
    cfd.performance = self:GetHostPerformance()
    cfd.username    = TheNet:GetLocalUserName()

    cfd.novice      = self:IsNovice()
    cfd.waiting     = self:IsWaitingForResponse()

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

function ClientNetwork:SetIsWaitingForResponse(waiting)
    PEARL.GameInstParams:SetModParam("waiting_for_response", waiting)
end

function ClientNetwork:SetCFDSent(sent)
    cfd_sent = sent
end

function ClientNetwork:SetCFDField(key, value)
    if cfd[key] ~= nil then
        PEARL.warn("Overriding CFD field", key, "with value", value)
    end

    cfd[key] = value

    return cfd
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

function ClientNetwork:GetHostPerformance()
    -- For dedicated servers the first index is reserved for the "host" machine.
    return TheNet:GetClientTable()[1].performance
end

function ClientNetwork:HasSentCFD()
    return cfd_sent
end

function ClientNetwork:GetCFD()
    return cfd
end

function ClientNetwork:IsWaitingForResponse()
    return PEARL.GameInstParams:GetCurrentModParam("waiting_for_response") == true
end

function ClientNetwork:IsDisconnected()
    return disconnection_notified
end

function ClientNetwork:IsDisconnecting()
    return disconnecting
end

--- Whether the server has closed the connection or not.
function ClientNetwork:WasDisconnectedByServer()
    return disconnected_by_server
end

function ClientNetwork:WasForceDisconnected()
    return force_disconnected
end

function ClientNetwork:IsPaused()
    return TheNet:IsServerPaused()
end

function ClientNetwork:IsNovice()
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

function ClientNetwork:OnResponse(from_server, allowed, reason, ...)
    if not self:IsWaitingForResponse() then
        return -- Ignore
    end

    PEARL.info("ClientNetwork:OnResponse", allowed)
    self:SetIsWaitingForResponse(false)
    self:CancelTimeout()

    if allowed == true then
        -- If the connection is allowed, then load the client I guess.
        self.loader:CancelDeffer()
        return self.loader:ForceLoad()
    end

    self:Disconnect(reason, from_server, ...)
end

function ClientNetwork:OnConnectionClosed(reason)
    return PEARL.SendRPCToServer(PEARL.RPCS.ClientDisconnected, reason, force_disconnected)
end

----------------------------------
-- Pre/Post Call Handlers
----------------------------------

-- The widgets should be loaded at this point.
-- Call the defered OnNetworkDisconnect here!
PEARL.AddFrontEndPostInit(function(fe)
    -- All modules working with cfd should be loaded.
    if PEARL.CONFIG.SERVER_REQUIRE_CFD and not ClientNetwork:HasSentCFD() then
        ClientNetwork:SendCFDToServer()
    end

    if ClientNetwork:IsDisconnecting() then
        return ClientNetwork:NotifyNetworkDisconnect()
    end
end)

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

    if not ClientNetwork:WasDisconnectedByServer() then
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
-- Game Instance Parameters
----------------------------------

-- Make the "waiting_for_response" flag persistent between instances,
-- in case the server restarts when someone just connects to it.
if PEARL.GameInstParams:GetModParam("waiting_for_response") ~= false then
    ClientNetwork:SetIsWaitingForResponse(true)
end

----------------------------------
-- Return
----------------------------------

return ClientNetwork
