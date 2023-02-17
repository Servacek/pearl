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


--- @TODO: Load the RPCs somewhere here.
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

local waiting_for_response = false
local cfd_sent = false
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

function ClientNetwork:Disconnect(reason, from_server, immediate)
    PEARL.info("ClientNetwork:Disconnect", reason, from_server)

    self:CancelTimeout()

    if self:IsDisconnected() then
        return PEARL.debug("Already disconnected...")
    end

    disconnected_by_server = from_server == true or false
    force_disconnected = true

    if PEARL.CONFIG.SERVER_REQUIRE_CFD and not self:HasSentCFD() then
        -- In case we have been disconnected for invalid mods
        -- we still want to inform the server what mods did we used.
        -- This should be improved I guess
        self:SendCFDToServer()
    end

    -- Call this before the actual disconnecting so the RPCs can be sent.
    -- It should be safe to call it here because missing FE should be handled at this point.
    OnNetworkDisconnect(reason, true, immediate)

    -- Give a tick to the RPCs in case the frontend was already loaded and we
    PEARL.StaticScheduler:ExecuteInTime(1, function()
        TheNet:JoinServerResponse(true) -- true when disconnecting...
        TheNet:Disconnect(false)
    end)

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
function ClientNetwork:SendCFDToServer()
    if TheNet:GetIsServer() or type(cfd) ~= "table" or IsTableEmpty(cfd) then
        return
    end

    PEARL.info("Sending connection filter data to the server...")
    PEARL.SendRPCToServer(PEARL.RPCS.ConnectionFilterData, ZipAndEncodeString(cfd))
    self:SetCFDSent(true)

    if self:IsJoiningServer() then
        self:SetIsWaitingForResponse(true)
        self:StartTimeout()
    end
end

function ClientNetwork:LoadDefaultCFD()
    cfd.locale      = TheNet:GetCountryCode()
    cfd.ping        = TheNet:GetPing()
    cfd.username    = TheNet:GetLocalUserName()

    cfd.novice      = self:IsNovice()
    cfd.joining     = self:IsJoiningServer()

    return cfd
end

function ClientNetwork:NotifyNetworkDisconnect()
    disconnection_notified = true

    -- Call the original non-hooked function to prevent any loops.
    return _OnNetworkDisconnect(unpack(disconnect_data))
end

----------------------------------
-- Setters
----------------------------------

function ClientNetwork:SetIsWaitingForResponse(waiting)
    waiting_for_response = waiting
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

function ClientNetwork:HasSentCFD()
    return cfd_sent
end

function ClientNetwork:GetCFD()
    return cfd
end

function ClientNetwork:IsWaitingForResponse()
    return waiting_for_response
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

function ClientNetwork:IsJoiningServer()
    -- last_reset_action should be nil only if we are joining the server for the first time.
    return PEARL.GameInstParams:GetParam("last_reset_action") == nil
end

function ClientNetwork:IsNovice()
    return not io.exists(PEARL.CONSTS.AGREEMENT_FILE_PATH)
end

----------------------------------
-- Handlers
----------------------------------

function ClientNetwork:OnTimeout()
    PEARL.info("Server response timed out!")
    self:CancelTimeout()
    self:SetIsWaitingForResponse(false)

    if PEARL.CONFIG.FAIL_SAFE_NETWORK then
        return PEARL.ClientLoader:ForceLoad()
    end

    -- Disconnect the client if we didn't get the response from the server in time.
    self:Disconnect("ID_DST_SERVER_RESPONSE_TIMEOUT")
end

function ClientNetwork:OnConnectionAllowed()
    if self:IsWaitingForResponse() then
        PEARL.info("Got connection allowed from the server!")

        self:SetIsWaitingForResponse(false)

        self:CancelTimeout()
        PEARL.ClientLoader:ForceLoad()
    end
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
PEARL.AddGlobalFunctionPreCall("OnNetworkDisconnect", function(reason, should_reset, immediate, ...)
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
    if TheFrontEnd ~= nil or immediate then
        PEARL.debug("Calling OnNetworkDisconnect")
        ClientNetwork:NotifyNetworkDisconnect()
        return
    end

    -- If we have no FE then do not execute this yet.
    -- It would cause a crash...
    PEARL.debug("Deffering OnNetworkDisconnect")
    return false
end)

-- These do not work on client
-- PEARL.AddGlobalFunctionPreCall("OnSimPaused", function()
--     PEARL.debug("OnSimPaused")
--     sim_paused = true
-- end)

-- PEARL.AddGlobalFunctionPreCall("OnSimUnpaused", function()
--     PEARL.debug("OnSimUnpaused")
--     sim_paused = false
-- end)

----------------------------------
-- Return
----------------------------------

return ClientNetwork
