--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Message = PEARL.loadfile("libraries/discordapi/models/message")

-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local iclear = table.iclear

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local LOGLINE_ALLOC = 10
local EMBED_ALLOC = PEARL.CONSTS.MAX_EMBED_COUNT

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class BufferedMessage: Message
local BufferedMessage = Class(Message, function(self)
    Message._ctor(self)

    self._timeout = 0
    --- @type Task?
    self._task = nil

    --- @type function?
    self._ontimeout = nil

    -- Pre-Allocation
    self._loglines = table.create(LOGLINE_ALLOC)
    self._embeds = table.create(EMBED_ALLOC)

    --- @type integer?
    self._flags = nil
end)

-------------------------------------
-- [[ Setters ]]
-------------------------------------

function BufferedMessage:SetTimeout(timeout)
    self._timeout = timeout
end

function BufferedMessage:SetOnTimeout(ontimeout, ...)
    self._ontimeout = ontimeout
    self._ontimeout_args = toarrayornil(...)
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function BufferedMessage:IsBuffering()
    return self._task and self._task.running == true
end

-------------------------------------
-- [[ Public ]]
-------------------------------------

function BufferedMessage:Timeout()
    self:Stop()

    if type(self._ontimeout) ~= "function" then
        PEARL.error("OnTimeout not set!")
    else
        if self._ontimeout_args then
            self._ontimeout(unpack(self._ontimeout_args))
        else
            self._ontimeout()
        end
    end

    -- Clear the buffer when we are done
    self:Clear()
end

function BufferedMessage:Start()
    if self._timeout <= 0 then
        return self:Timeout()
    end

    if self._task then
        --PEARL.debug("Restarting the buffer task!")
        return self._task:restart()
    end

    --PEARL.debug("Starting the buffer task!")
    self._task = PEARL.WallScheduler:ExecutePeriodic(
        self._timeout, self.Timeout, nil, nil, nil, self
    )
end

function BufferedMessage:Stop()
    if self._task and self._task.running then
        return self._task:stop()
    end
end

function BufferedMessage:Clear()
    self._flags = nil
    self._content = nil

    if self._loglines then
        iclear(self._loglines)
    end

    if self._embeds then
        iclear(self._embeds)
    end

    if self._allowed_mentions then
        table.clear(self._allowed_mentions)
    end

    if self._default_table then
        table.clear(self._default_table)
    end
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return BufferedMessage
