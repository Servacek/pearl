--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- So the main issue we are trying to solve here is changing the behaviour of
--- the Ban functions so they drop player's inventory upon being called.
--- We override the engine function itself to ensure all calls are handled this way.

if not TheNet then
    return -- There is nothing to be expanded.
end

--- @engine
--- @class TheNet
local __index = getmetatable(TheNet).__index
TheNet = TheNet --- @type TheNet

-- Provides access to the original functions
local __index_ORIGIN = shallowcopy(__index)


function __index:Say(message, ...)
    if type(message) == "string" then
        message = message:gsub(PEARL.CONSTS.HYBRID_EMOJI_PATTERN, function(emoji_id)
            if PEARL.EMOJIS.IsEmojiAvailable(emoji_id) then
                return PEARL.EMOJIS.ALL[emoji_id]
            end
        end)
    end

    local ClientEmojis = PEARL.loadfile("libraries/clientemojimanager")
    local needs_saving = false
    for match in message:gmatch(PEARL.CONSTS.UTF_EMOJI_PATTERN) do
        local emoji_name = PEARL.EMOJIS.UTF_TO_NAME[match]
        if emoji_name then
            ClientEmojis:OnEmojiUsed(emoji_name)
            needs_saving = true
        end
    end

    if needs_saving then
        ClientEmojis:SavePersistentData()

        PEARL.INST:PushEvent("emojis_used")
    end

    return __index_ORIGIN.Say(TheNet, message, ...)
end
