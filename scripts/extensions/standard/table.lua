--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local TAB_SIZE = 4
local MAX_DUMP_RECURSIONS = 10


function table:filter(checkfn)
    local result = {}
    for k, v in pairs(self) do
        if checkfn(k, v) then
            result[k] = v
        end
    end

    return result
end

function table.size(t)
    local size = 0
    for _, _ in pairs(t) do
        size = size + 1
    end

    return size
end

function table:find(checkfn, count)
    count = count or 1
    for k, v in pairs(self) do
        if checkfn(k, v) then
            count = count - 1
            if count <= 0 then
                return true, count
            end
        end
    end

    return false, count
end

-- Fancy Table Concatenation
function table:fconcat()
    return #self > 1 and STRINGS.PEARL.LOGS.AND:format(
        table.concat(self, ", ", 1, #self - 1), self[#self]
    ) or table.concat(self, ", ")
end

-- This is a safe alternative to IsTableEmpty
function table:empty()
    return self and next(self) == nil
end

function table.create(size, narr)
    return createTable(size, narr)
end

function table:iclear()
    for i = #self, 1, -1 do
        self[i] = nil
    end
end

--- @param fn fun(k: any, v: any): result: any
function table:map(fn)
    local t = {}
    for k, v in pairs(self) do
        t[k] = fn(v)
    end

    return t
end

function table.sum(t)
    local sum = 0
    for _, value in pairs(t) do
        sum = sum + value
    end

    return sum
end

function table.average(t)
    return table.sum(t) / table.size(t)
end

function table.max(t)
    local maxk
    local maxv = 0
    for k, v in pairs(t) do
        if v > maxv then
            maxk = k
            maxv = v
        end
    end

    return maxk, maxv
end

-- For some reason this cannot be used as a method :/
function table.dump(t, _i)
    if type(t) ~= "table" then
        return print("Invalid table")
    end

    if type(_i) ~= "number" then
        _i = nil
    end

    if not _i then
        print("{")
    end

    _i = _i or 1
    for k, v in pairs(t) do

        local fm = string.rep(" ", _i * TAB_SIZE)..tostring(k).." = "
        if type(v) == "table" then
            print(fm.."{")
            if _i < MAX_DUMP_RECURSIONS then
                table.dump(v, _i + 1)
            else
                print("...")
            end
        elseif type(v) == "string" then
            print(fm..string.format("%q", v)..",")
        else
            print(fm..tostring(v)..",")
        end
    end

    print(string.rep(" ", _i * TAB_SIZE - TAB_SIZE).."},")
end
