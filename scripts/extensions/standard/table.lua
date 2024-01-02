--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local TAB_SIZE = 4
local MAX_DUMP_LEVEL = 10
local MAX_RECURSIONS = 1000


local function default_cmp(a, b)
    return a > b
end

--------------------------

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
-- Returns a boolean whether the table you have provided is empty or not.
-- Returns nil if the provided table is not actually a table...
--- @return boolean? empty
function table:empty()
    if type(self) ~= "table" then
        return
    end

    return next(self) == nil
end

function table.create(size, narr)
    return createTable(size, narr)
end

-- Note: The proxy table returned by this doesn't support pairs/ipairs/next or the "#" operator.
function table.readonly(t)
    return setmetatable({}, {
        __index = t,
        __len = function() return #t end,
        __newindex = function()
            return error("Attempted to modify a read-only table."..CalledFrom())
        end,
        -- Prohibit changing this metatable
        __metatable = false,
    })
end

function table:iclear()
    for i = #self, 1, -1 do
        self[i] = nil
    end

    return self
end

function table:clear()
    for k, _ in pairs(self) do
        self[k] = nil
    end

    return self
end

--- Optimized version of table:getkey for true arrays.
--- @return integer? index
function table:index(value)
    for i = 1, #self do
        if self[i] == value then
            return i
        end
    end
end

--- Returns the first key for the specified value found in the the specified table.
--- @return key? any
function table:getkey(value)
    for k, v in pairs(self) do
        if v == value then
            return k
        end
    end
end

function table.rcontains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        elseif type(v) == "table" and table.rcontains(v, value) then
            return true
        end
    end

    return false
end

--- @param fn fun(v: any): result: table<any, any>
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

function table.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        keys[#keys + 1] = k
    end

    return keys
end

--- @return integer position The updated position of the item at t[i]. This can be unchanged.
function table.reorder(t, i, cmp)
    cmp = cmp or default_cmp
    local lstep = (t[i+1] ~= nil and cmp(t[i], t[i+1]) and 1) or 0
    local rstep = (lstep == 0 and t[i-1] ~= nil and cmp(t[i-1], t[i]) and -1) or 0
    local step = lstep + rstep
    while t[i+step] ~= nil and cmp(t[i+rstep], t[i+lstep]) do
        t[i+rstep], t[i+lstep] = t[i+lstep], t[i+rstep]
        i = i + step
    end

    return i
end

function table.insort(t, v, cmp)
    local i = #t+1
    t[i] = v
    --table.insert(t, i, v)

    return table.reorder(t, i, cmp)
end

function table.values(t)
    local values = {}
    for _, v in pairs(t) do
        values[#values + 1] = v
    end

    return values
end

-- For some reason this cannot be used as a method :/
function table.dump(t, _i, _r)
    if type(t) ~= "table" then
        return print("Invalid table")
    end

    -- if _r and _r >= MAX_RECURSIONS then
    --     return print("...")
    -- end

    if type(_i) ~= "number" then
        _i = nil
    end

    if not _i then
        print("{")
    end

    _i = _i or 1
    for k, v in pairs(t) do
        _r = (_r or 0) + 1
        local fm = string.rep(" ", _i * TAB_SIZE)..tostring(k).." = "
        if type(v) == "table" then
            print(fm.."{")
            if _i < MAX_DUMP_LEVEL then
                table.dump(v, _i + 1, _r)
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
