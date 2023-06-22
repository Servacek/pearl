--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local tests = {}

function tests.test_onopen()
    if TheShard:IsMaster() then
        return
    end

    PEARL._sdc.onopenfn()
    assert()
    PEARL.Scheduler:ExecuteInTime(1, function()
    end)
end

function tests.test_onclose()
    if TheShard:IsMaster() then
        return
    end

    PEARL._sdc.onclose()
    assert()
end

return tests
