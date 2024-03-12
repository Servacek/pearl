--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

local ENV = getmetatable(PEARL.ENV)

function PEARL.EXT(testset_name, testname)
    local tests = {}
    local env = setmetatable({}, {
        __index = ENV.__index,
        __newindex = function(self, index, value)
            tests[index] = value
        end
    })

    -- Reload the file each time for easier changes.
    local result = PEARL.loadfile("tests/"..testset_name, env, true)
    if type(result) == "table" then
        tests = MergeMaps(tests, result)
    end

    if table.empty(tests) then
        return PEARL.error("The specified test set does not contain any tests!")
    end

    if testname then
        if PEARL.SafeRun(tests.test_all) then
            PEARL.info("Test", testname, "ran successfully!")
        end

        return
    end

    if tests.test_all then
        if PEARL.SafeRun(tests.test_all) then
            PEARL.info("All tests ran successfully!")
        end

        return
    end

    local success_count = 0
    for name, test in pairs(tests) do
        print(string.rep("-", 30))

        PEARL.info("Executing test", name)
        local success, errmsg = pcall(test)
        if success == true then
            PEARL.info("Test succeeded!")
            success_count = success_count + 1
        else
            PEARL.info("Test", name, "failed! Reason:\n", errmsg)
            StackTraceToLog()
        end

        print(string.rep("-", 30))
    end

    PEARL.info(string.format("%d of %d tests", success_count, table.size(tests)), "succeeded!")
end
