
function table:filter(checkfn)
    local result = {}
    for k, v in pairs(self) do
        if checkfn(k, v) then
            result[k] = v
        end
    end

    return result
end

function table:find(checkfn)
    for k, v in pairs(self) do
        if checkfn(k, v) then
            return true
        end
    end

    return false
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
