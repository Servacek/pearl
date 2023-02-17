--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @TODO: Write some debug tests for this.
--[[
    Efficient strict queue implementation.
--]]

-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local table_create = table.create

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local START_INDEX_FIRST = 1
local START_INDEX_LAST = 0

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class Queue
local Queue = Class(function(self, max_size)
    self._max_size   = max_size or -1

    self._list       = table_create(max_size)
    self._list.n     = 0
    self._list.first = START_INDEX_FIRST
    self._list.last  = START_INDEX_LAST
end)

------------------------------------------

--- Checks if there are any elements stored in the queue or not.
--- @return boolean result Determines if the queue is empty or not.
function Queue:empty()
    return self._list.first > self._list.last
end

function Queue:full()
    return self._list.n >= self._max_size
end

function Queue:len()
    return self._list.n
end

--- Returns the first element in the queue.
--- @return any first The first element.
function Queue:first()
    return self._list[self._list.first]
end

--- Returns the last element in the queue.
--- @return any last The last element.
function Queue:last()
    return self._list[self._list.last]
end

--- Pushes the given value to the end of the queue.
--- @param val any The value to push to the queue.
--- @return boolean success Whether it was possible to push the value to the queue or not.
function Queue:push(val)
    -- If the queue is too big
    if self._list.n >= self._max_size then
        return false
    end

    local new_last = self._list.last + 1
    self._list.last = new_last
    self._list[new_last] = val
    self._list.n = self._list.n + 1

    return true
end

--- Removes the first element from the queue and returns it's value.
--- @return any value The value of the removed element.
function Queue:take()
    if self:empty() then
        return
    end

    local first = self._list.first
    local value = self._list[first]

    self._list[first] = nil
    self._list.first = first + 1
    self._list.n = self._list.n - 1

    return value
end

-- Returns an iterator function for the queue.
-- When this iterator is called it just returns the next element in the queue.
--
--- @return function iter
function Queue:iter()
    local i
    local last = self._list.last
    return function()
        i = i and i + 1 or self._list.first
        return i <= last and self._list[i] or nil
    end
end

--- Clears the queue.
function Queue:clear()
    for i = self._list.last, self._list.first, -1 do
        self._list[i] = nil
    end

    self._list.first    = START_INDEX_FIRST
    self._list.last     = START_INDEX_LAST
    self._list.n        = 0
end
-------------------------

return Queue
