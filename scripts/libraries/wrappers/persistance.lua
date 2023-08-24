--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-- Registered as global for now.

function PEARL.PersistentStringExists(fp)
    local file_exists = false
    TheSim:CheckPersistentStringExists(fp, function(exists)
        file_exists = exists
    end)

    return file_exists
end

function PEARL.CreatePersistentString(fp)
    return PEARL.SetPersistentString(fp, "")
end

function PEARL.EnsurePersistentString(fp)
    if not PEARL.PersistentStringExists(fp) then
        if not PEARL.CreatePersistentString(fp) then
            PEARL.error("Failed to create file", fp)
            return false
        end
    end

    return true
end

function PEARL.GetPersistentString(fp, ensure)
    if ensure and not PEARL.EnsurePersistentString(fp) then
        return false
    end

    local result, success
    TheSim:GetPersistentString(fp, function(successfull, str)
        success = successfull
        result = str
    end)

    return success, result
end

-- This runs synchronously actually.
function PEARL.GetPersistentStringByLines(fp, fn, ensure)
    if PEARL.PersistentStringExists(fp) ~= true then
        if ensure == true then
            PEARL.info("Creating file", fp)

            return PEARL.CreatePersistentString(fp)
        end

        return PEARL.error("File not found!")
    end

    return TheSim:GetPersistentString(fp, function(success, str)
        if not success or type(str) ~= "string" then
            return PEARL.error("Failed to load the file!", fp)
        end

        local prefix = string.strip(PEARL.CONSTS.KLEI_DATA_PREFIX)
        for _, line in ipairs(str:split("\n")) do
            if string.strip(line) ~= prefix then
                fn(line)
            end
        end
    end)
end

function PEARL.GetAllPersistentStringLines(fp, ensure, strip)
    local lines = {}
    PEARL.GetPersistentStringByLines(fp, function(line)
        if strip == true then
            local stripped = string.strip(line)
            if #stripped > 0 then
                lines[#lines + 1] = stripped
            end
        else
            lines[#lines + 1] = line
        end
    end, ensure)

    return lines
end

-- This will create the file if needed.
function PEARL.SetPersistentStringLines(fp, lines, encode)
    return PEARL.SetPersistentString(fp, table.concat(lines, "\n"), encode)
end

-- This will create the file if needed.
function PEARL.SetPersistentString(fp, str, encode)
    encode = encode or false

    local s = false
    TheSim:SetPersistentString(fp, str, encode, function(success)
        s = success
    end)

    return s
end

function PEARL.LoadPersistentLuaString(fp, ensure, env)
    if ensure and not PEARL.EnsurePersistentString(fp) then
        return false, PEARL.error("Failed to create the file!")
    end

    local success, lua_str = PEARL.GetPersistentString(fp, ensure)
    if not success or type(lua_str) ~= "string" then
        return false, PEARL.error("Failed to load the given lua file!")
    end

    if type(env) == "table" then
        return RunInEnvironmentSafe(function()
            return loadstring(lua_str)()
        end, env)
    end

    return RunInSandboxSafe(lua_str)
end
