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
-- Declaration
----------------------------------

--- @class ClientNetwork
local ClientNetwork = {
    _disconnected = false
}

----------------------------------
-- Public
----------------------------------

function ClientNetwork:Disconnect(reason, from_server)
    if self._disconnected then
        return
    end

    self._disconnected = true
    PEARL.info("ClientNetwork:Disconnect", reason)

    if not from_server then
        -- Tell the server why we have been disconnected
        PEARL.SendRPCToServer(PEARL.RPCS.ClientForceDisconnected, reason)
    end

    PEARL.ClientLoader:CancelDelayedLoad()
    PEARL.ClientLoader:SetIsDisabled(true)

    staticScheduler:ExecuteInTime(0, function()
        TheNet:JoinServerResponse(true)
        TheNet:Disconnect(true)
        OnNetworkDisconnect(reason, true, false)
    end)
end

function ClientNetwork:SendPlayerReportToServer(message, ...)
    return PEARL.SendRPCToServer(PEARL.RPCS.PlayerReportMessage, message)
end

function ClientNetwork:IsDisconnected()
    return self._disconnected
end

----------------------------------
-- Return
----------------------------------

return ClientNetwork
