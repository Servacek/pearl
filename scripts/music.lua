--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

-- Make sure the sound files do not exceed 100 MB


local function StartErrorMusic()
    PEARL.info("Starting to play the server error music!")

    local focal_emittor = (TheFocalPoint and TheFocalPoint.SoundEmitter)
    local fe_emittor = (TheFrontEnd and TheFrontEnd:GetSound())
    if focal_emittor then
        focal_emittor:KillAllSounds()
    end

    if fe_emittor then
        fe_emittor:KillAllSounds()
    end

    local emittor = focal_emittor or fe_emittor
    local music_volume = math.max(TheMixer:GetLevel("set_music"), 0.5)
    emittor:PlaySound("custom_music/misc/technical_difficulties", "music_server_error")
    emittor:SetVolume("music_server_error", music_volume)
    emittor:SetMute(false)

    -- Set music to 100% to ensure the audio will work.
    -- Ignore user's configuration.
    TheMixer:SetLevel("set_music", music_volume)
    TheMixer:SetLevel("set_music/soundtrack", music_volume)
    TheMixer:SetLevel("master", music_volume)
end

PEARL.EventProcessor:AddSafeEventHandler("clienterror", StartErrorMusic)
PEARL.EventProcessor:AddSafeEventHandler("connection_closed", function(reason)
    if reason == "ID_DST_SERVER_CRASHED" and TheMixer ~= nil then
        StartErrorMusic()
    end
end)
