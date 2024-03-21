--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Class Delcaration ]]
--------------------------------

--- @class Memory
local Memory = Class(function(self, inst)
    self.inst = inst

    --- @type table
    self.data = nil
    self.ttls = nil
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

function Memory:SetLifetime(name, time)
    if not self.ttls then
        self.ttls = {}
    end

    self.ttls[name] = time

    if not table.empty(self.ttls) then
        self.inst:StartUpdatingComponent(self)
    end
end

function Memory:ForEach(fn, ...)
    if self.data then
        for name, value in pairs(self.data) do
            fn(name, value, ...)
        end
    end
end

function Memory:Set(key, value)
    if key == nil then
        PEARL.error("Invalid key provided!")
        return
    end

    if not self.data then
        self.data = {}
    end

    self.data[key] = value
end

function Memory:Remove(name)
    if self.data then
        self.data[name] = nil
    end

    if self.ttls then
        self.ttls[name] = nil
    end
end

function Memory:Clear()
    for name, _ in pairs(self.data) do
        self:Remove(name)
    end
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function Memory:Get(key)
    return self.data and self.data[key]
end

function Memory:Retrieve()
    return self.data
end

function Memory:SortedKeys(sortfn)
    if not self.data then
        return {}
    end

    local keys = table.keys(self.data)
    table.sort(keys, sortfn or function(name1, name2)
        return self.data[name1] and self.data[name2] and self.data[name1] < self.data[name2]
    end)

    return keys
end

--------------------------------
-- [[ Component Handlers ]]
--------------------------------

function Memory:OnSave()
    return {
        data = self.data,
        ttls = self.ttls,

        -- Custom flag to ensure this component
        add_component_if_missing = true,
    }
end

function Memory:OnLoad(data)
    self.data = data.data
    self.ttls = data.ttls
end

function Memory:OnUpdate(dt)
    if not self.ttls then
        return
    end

    for name, ttl in pairs(self.ttls) do
        if ttl <= 0 then
            self.ttls[name] = nil
        else
            self.ttls[name] = ttl - dt
        end
    end

    if table.empty(self.ttls) then
        self.inst:StopUpdatingComponent(self)
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return Memory
