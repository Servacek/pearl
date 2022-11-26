
function table:filter(checkfn)
    local result = {}
    for k, v in pairs(self) do
        if checkfn(k, v) then
            result[k] = v
        end
    end

    return result
end

function table:check(checkfn)
    for k, v in pairs(self) do
        if checkfn(k, v) then
            return true
        end
    end

    return false
end
