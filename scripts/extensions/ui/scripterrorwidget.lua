--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


PEARL.AddClassPreConstruct("widgets/scripterrorwidget", function(self, title, text, buttons)
    print("PRE CONSTRUCT")
    for _, button in pairs(buttons) do
        if button.text == STRINGS.UI.MAINSCREEN.SCRIPTERRORRESTART then
            button.cb = function()
                local listing = TheNet:GetServerListing()

                TheSim:ResetError()
                MigrateToServer(listing.ip, listing.port, listing.netid)
            end
        end
    end
end)

PEARL.AddClassPostConstruct("widgets/scripterrorwidget", function(self)
    print("POST CONSTRUCT")
end)
