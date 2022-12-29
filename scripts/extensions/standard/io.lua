

function io.exists(fp)
    local f = io.open(fp, "r")
    return f and f:close()
end

function io.create(fp)
    local f = io.open(fp, "w")
    return f and f:close()
end

function io.line(fp)
    local f = io.open(fp, "r")
    local line = f and f:read("*l")
    return f and f:close() and line
end
