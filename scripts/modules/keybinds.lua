--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd
--- @TODO: Think about some way how to notify the user that the queue was toggled.

-----------------------------------
-- Hide Chat
-----------------------------------

local ChatQueue

TheInput:AddKeyDownHandler(PEARL.CONTROLS.TOGGLE_CHAT, function()
    if ChatQueue then
        ChatQueue:Toggle()
    end
end)

PEARL.AddClassPostConstruct("widgets/redux/chatqueue", function(self)
    ChatQueue = self
end)

-----------------------------------
