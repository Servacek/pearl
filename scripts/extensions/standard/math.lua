
function math.round(num, dp)
    local mult = 10^(dp or 0)

    return math.floor((num * mult) + 0.5) / mult
end
