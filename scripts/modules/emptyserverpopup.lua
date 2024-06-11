--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @FE


-- Use the redux version instead of the default on since this is newer
local PopupDialogScreen = require("screens/redux/popupdialog")


----------------------------------
-- Handlers
----------------------------------

local OnPlayerEnteredLobby
OnPlayerEnteredLobby = function(world, player)
    local connection_output_data = PEARL.ClientNetwork:GetConnectionOutputData()
    if #GetPlayerClientTable() > 1 or connection_output_data.new_session_file ~= true then
        return
    end

    -- So this is called only once per each simulation instance.
    world:RemoveEventCallback("entercharacterselect", OnPlayerEnteredLobby)

    local popup
    local discord_url = PEARL.CONFIG.SOCIAL_LINKS.DISCORD
    local buttons = {
        { -- Every popup needs o close or continue button
            text = STRINGS.PEARL.UI.EMPTY_SERVER_POPUP.CONTINUE,
            cb = function()
                -- Just close the popup
                TheFrontEnd:PopScreen(popup)
            end
        }
    }

    local body = STRINGS.PEARL.UI.EMPTY_SERVER_POPUP.BODY
    if PEARL.isvisiblestring(discord_url) then
        body = STRINGS.PEARL.UI.EMPTY_SERVER_POPUP.BODY_DISCORD

        table.insert(buttons, 1,  {
            text = STRINGS.PEARL.UI.EMPTY_SERVER_POPUP.VISIT_DISCORD_BUTTON,
            cb = function()
                VisitURL(discord_url)

                TheFrontEnd:PopScreen(popup)
            end
        })
    end

    popup = PopupDialogScreen(
        STRINGS.PEARL.UI.EMPTY_SERVER_POPUP.TITLE, body, buttons, nil, nil, "dark_wide"
    )

    -- Inform the player that some of his mods were blocked by the server
    TheFrontEnd:PushScreen(popup)
end

----------------------------------
-- Listeners
----------------------------------

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("entercharacterselect", OnPlayerEnteredLobby)
end)
