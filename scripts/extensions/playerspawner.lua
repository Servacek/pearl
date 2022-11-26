
-- local PlayerSpawner = require("components/playerspawner")

local PEARL = PEARL

------------------------------------------

--- @TODO find a better place for pushing this event.
PEARL.AddGlobalFunctionPostCall("DisableLoadingProtection", function(self, guid)
    print("LOADED", CalledFrom())
    local player = Ents[guid]
    if player then
        player:PushEvent("playerloaded")
    end
end)
