--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


------------------------------------------
-- [[ Localization ]]
------------------------------------------

local unpack = unpack

------------------------------------------
-- [[ Extended Builtins  ]]
------------------------------------------

--- Same as the default unpack but supports nil as an argument for cleaner syntax.
--- @param t table<T>?
--- @return ...<T>
PEARL.unpack = function(t, ...)
    if t == nil then
        return t
    end

    return unpack(t, ...)
end

local function __genOrderedIndexSafe(t)
    local orderedIndex = {}
    for key in pairs(t) do
        -- Make sure the items in the list are of the same type because of the sorting.
        orderedIndex[#orderedIndex + 1] = tostring(key)
    end

    table.sort(orderedIndex)
    return orderedIndex
end

PEARL.opairs = function(t)
    return function(_, state)
        local key = nil
        if state == nil then
            -- the first time, generate the index
            t.__orderedIndex = __genOrderedIndexSafe(t)
            key = t.__orderedIndex[1]
        else
            -- fetch the next value
            for i = 1, #t.__orderedIndex do
                if t.__orderedIndex[i] == state then
                    key = t.__orderedIndex[i+1]
                end
            end
        end

        if key then
            return key, t[key]
        end

        -- no more value to return, cleanup
        t.__orderedIndex = nil
    end, t, nil
end
