

function io.exits(fp)
    local f = io.open(fp, "r")
    return f and f:close()
end

function io.create(fp)
    local f = io.open(fp, "w")
    return f and f:close()
end
