--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- Some attempts to optimize the Class function :P

require("class")

local IGNORE_LIST = {
    ["_"] = true,
    ["__proxy"] = true,
}

local CACHE_LIMIT = 512
local TOTAL_LIMIT = 512

local total_len = 0

local newproxy, pairs, getmetatable, next = newproxy, pairs, getmetatable, next

PEARL.OverrideReturnValue(_G, "Class", function(class, base, _ctor, props)
    if class then
        _ctor = class._ctor

        ClassRegistry[class] = nil

        local inst_pool = table.create(1000, 1000)
        local mt = getmetatable(class)
        mt.__call = function(self, ...)
            local _, inst = next(inst_pool)
            inst = inst or {}
            if props ~= nil then
                if not inst._ then
                    inst._ = {}
                end

                for k, v in pairs(props) do
                    inst._[k] = {nil, v}
                end
            end

            if not inst.__proxy then
                inst.__proxy = newproxy(true)
                getmetatable(inst.__proxy).__gc = function()
                    local index = #inst_pool + 1
                    if index >= CACHE_LIMIT or total_len >= TOTAL_LIMIT then
                        return
                    end

                    inst_pool[index] = inst

                    if inst._ then
                        for k, _ in pairs(inst._) do
                            rawset(inst._, k, nil)
                        end
                    end

                    -- for k, _ in pairs(inst) do
                    --     if not IGNORE_LIST[k] then
                    --         rawset(inst, k, nil)
                    --     end
                    -- end

                    total_len = total_len + 1
                    print(index)
                end
            end

            setmetatable(inst, class)

            if _ctor then
                _ctor(inst, ...)
            end

            return inst
        end
    end

    return class
end)
