--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


PEARL.EventProcessor:AddSafeEventHandler("connection_closed", function(reason)
    if reason == "ID_DST_SERVER_CRASHED" and TheMixer ~= nil then
        PEARL.info("Starting to play the server error music!")

        local emittor = (TheFocalPoint and TheFocalPoint.SoundEmitter) or (TheFrontEnd and TheFrontEnd:GetSound())
        local music_volume = math.max(TheMixer:GetLevel("set_music"), 0.5)
        emittor:KillAllSounds()
        emittor:PlaySound("custom_music/misc/technical_difficulties", "music_server_error")
        emittor:SetVolume("music_server_error", music_volume)
        emittor:SetMute(false)

        -- Set music to 100% to ensure the audio will work.
        -- Ignore user's configuration.
        TheMixer:SetLevel("set_music", music_volume)
        TheMixer:SetLevel("set_music/soundtrack", music_volume)
        TheMixer:SetLevel("master", music_volume)

        -- local active_screen = TheFrontEnd and TheFrontEnd:GetActiveScreen()
        -- if active_screen and active_screen.buttons and active_screen.buttons[1] then
        --     print(active_screen.buttons[1])
        --     PEARL.AddClassFunctionPreCall("cb", function()
        --         emittor:KillSound("music_server_error")
        --     end, active_screen.buttons[1])
        -- end
    end
end)

-- Make sure the sound files do not exceed 100 MB
-- local GAME_MODES = GLOBAL.GAME_MODES
-- if GAME_MODES.survival then
--     GAME_MODES.survival.override_lobby_music = "custom_music/misc/vltava"
-- end
