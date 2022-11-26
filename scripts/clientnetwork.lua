
local PEARL = PEARL
local TheNet = TheNet

----------------------------------
-- Declaration
----------------------------------

PEARL.ClientNetwork = {
    _disconnected = false,
    _ready = false,
}

----------------------------------
-- Private
----------------------------------

----------------------------------
-- Public
----------------------------------

function PEARL.ClientNetwork:Disconnect(reason)
    PEARL.info("ClientNetwork:Disconnect", reason)

    PEARL.ClientLoader:CancelDelayedLoad()
    TheNet:JoinServerResponse(true)
    TheNet:Disconnect(true)
    OnNetworkDisconnect(reason, true, false)

    self._disconnected = true
end

function PEARL.ClientNetwork:IsDisconnected()
    return self._disconnected
end

function PEARL.ClientNetwork:IsReady()
    return self._ready
end

function PEARL.ClientNetwork:OnReady()
    PEARL.debug("OnReady", self._ready)
    if not self._ready then
        self._ready = true

        PEARL.SendRPCToServer(PEARL.RPCS.ClientModNetworkReady)
    end
end

----------------------------------
-- Handlers
----------------------------------

PEARL.AddGlobalFunctionPreCall("OnNetworkDisconnect", function()
    if PEARL.ClientNetwork:IsDisconnected() then
        PEARL.debug("OnNetworkDisconnect", "Already disconnected, returning...")

        return false
    end
end)

PEARL.AddClientPreLoad(function()
    PEARL.ClientNetwork:OnReady()
end)
