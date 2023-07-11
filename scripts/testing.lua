--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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
    tests = PEARL.loadfile("tests/"..testset_name, env)

    if IsTableEmpty(tests) then
        return PEARL.error("The specified test set does not contain any tests!")
    end

    if testname then
        return tests[testname]()
    end

    if tests.test_all then
        return tests.test_all()
    end

    for name, test in pairs(tests) do
        PEARL.info("Executing test", name)
        test()
    end
end
