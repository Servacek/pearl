
local PEARL = PEARL
local SetSimPause = SetSimPause

--------------------------------
-- [[ Sim Callbacks ]]
--------------------------------
-- Note:
-- These handlers also restore the old
-- IsSimPaused check function from the
-- singleplayer Don't Starve.

PEARL.AddGlobalFunctionPreCall("OnSimUnpaused", function(...)
    -- TheWorld:PushEvent("ms_simunpaused") is already being called here by the game

    SetSimPause(false)
end)

PEARL.AddGlobalFunctionPreCall("OnSimPaused", function(...)
    if TheWorld ~= nil then
        TheWorld:PushEvent("ms_simpaused")
    end

    SetSimPause(true)
end)
