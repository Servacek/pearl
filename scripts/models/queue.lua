--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--[[
    Efficient strict queue implementation.
--]]

-- Yes, this is REALLY required
require("metaclass")

local PEARL = PEARL
local math = math

local START_INDEX_FIRST = 1
local START_INDEX_LAST = 0

------------------------------

--- @class Queue
local Queue = MetaClass(function(self, max_size)
    self.list = {first = START_INDEX_FIRST, last = START_INDEX_LAST}
    self.max_size = max_size or -1
end)

------------------------------------------
-- [[ Meta Methods ]]
------------------------------------------

function Queue:__len()
    return math.max((self.list.last + 1) - self.list.first, 0)
end

-------------------------------

--- Checks if there are any elements stored in the queue or not.
--- @return boolean result Determines if the queue is empty or not.
function Queue:IsEmpty()
    -- Lists start with 1 in lua
    return self.list.first > self.list.last
end

--- Returns the first element in the queue.
--- @return any first The first element.
function Queue:First()
    return self.list[self.list.first]
end

--- Returns the last element in the queue.
--- @return any last The last element.
function Queue:Last()
    return self.list[self.list.last]
end

--- Pushes the given value to the end of the queue.
--- @param val any The value to push to the queue.
--- @return boolean success Whether it was possible to push the value to the queue or not.
function Queue:Push(val)
    -- If the queue is too big
    if #self >= self.max_size then
        PEARL.error("Tried to append to a full queue!", val)
        return false
    end

    local new_last = self.list.last + 1
    self.list.last = new_last
    self.list[new_last] = val

    return true
end

--- Removes the first element from the queue and returns it's value.
--- @return any value The value of the removed element.
function Queue:Take()
    if self:IsEmpty() then return end

    local first = self.list.first
    local value = self.list[first]

    self.list[first] = nil
    self.list.first = first + 1

    return value
end

function Queue:Iter()
    local i = self.list.first - 1
    local last = self.list.last

    return function()
        i = i + 1

        if i <= last then
            return self.list[i]
        end
    end
end

--- Clears the queue.
function Queue:Clear()
    for k, _ in pairs(self.list) do
        self.list[k] = nil
    end

    self.list.first = START_INDEX_FIRST
    self.list.last = START_INDEX_LAST
end

-------------------------

return Queue
