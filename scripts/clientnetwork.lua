
local PEARL = PEARL
local TheNet = TheNet

----------------------------------
-- Declaration
----------------------------------
--- @class ClientNetwork
local ClientNetwork = {}

----------------------------------
-- Public
----------------------------------

function ClientNetwork:Disconnect(reason)
    PEARL.info("ClientNetwork:Disconnect", reason)

    PEARL.ClientLoader:CancelDelayedLoad()
    TheNet:JoinServerResponse(true)
    TheNet:Disconnect(true)
    OnNetworkDisconnect(reason, true, false)
end

return ClientNetwork
