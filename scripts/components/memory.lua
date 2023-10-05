
--------------------------------
-- [[ Class Delcaration ]]
--------------------------------

--- @class Memory
local Memory = Class(function(self, inst)
    self.inst = inst

    --- @type table
    self.data = nil
    self.ttls = nil
    self.keys = {}
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

function Memory:SetLifetime(name, time)
    print("Memory:SetLifetime", name, time)
    if not self.ttls then
        self.ttls = {}
    end

    self.ttls[name] = time

    print("EntityScript:StartUpdatingComponent")
    self.inst:StartUpdatingComponent(self)
end

function Memory:ForEach(fn, ...)
    if self.data then
        for userid, damage in pairs(self.data) do
            fn(userid, damage, self.data, ...)
        end
    end
end

function Memory:Add(key, value)
    if not self.data then
        self.data = {}
    end

    self.keys[#self.keys+1] = key
    self.data[key] = value
end

function Memory:Remove(name)
    local value
    if self.data then
        value = self.data[name]
        self.data[name] = nil
    end

    if self.ttls then
        self.ttls[name] = nil
    end

    return value
end

function Memory:Clear()
    for i = #self.keys, 1, -1 do
        local key = self.keys[i]
        self:Remove(key)
        self.keys[key] = nil
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

function Memory:Sorted(sortfn)
    if self.data then
        table.sort(table.keys(self.data), sortfn or function(name1, name2)
            return self.data[name1] and self.data[name2] and self.data[name1] < self.data[name2]
        end)
    end

    return self.data
end

--------------------------------
-- [[ Component Handlers ]]
--------------------------------

function Memory:OnSave()
    return {
        data = self.data,
        ttls = self.ttls,
    }
end

function Memory:OnLoad(data)
    self.data = data.data
    self.ttls = data.ttls
    self.keys = table.keys(data.data or data.ttls or {})
end

function Memory:OnUpdate(dt)
    if not self.ttls then
        return
    end

    for i = 1, #self.keys do
        local name = self.keys[i]
        if name then
            local ttl = self.ttls[name]
            if ttl == nil or ttl <= 0 then
                print("REMOVING ATTACKER! EXPIRED: ", name)
                self.ttls[name] = nil
            end

            self.ttls[name] = ttl - dt
        end
    end

    if #self.ttls <= 0 then
        print("EntityScript:StopUpdatingComponent")
        self.inst:StopUpdatingComponent(self)
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return Memory
