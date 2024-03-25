--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local PEARL = PEARL

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local LICENCE_FILENAME = MODROOT.."LICENSE"
local CACHED_USERID_FILENAME = "cached_userid"
local LICENCE_OWNERS = {
    ["KU_NujB7r1v"] = true,
    ["KU_ZC24p91Q"] = true,
    ["KU_C3RCBdQs"] = true,
}

--------------------------------------
-- [[ Local Variables ]]
--------------------------------------

local cached_userid

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function HasServerOwnerLicense()
    return LICENCE_OWNERS[TheNet:GetUserID()] == true or LICENCE_OWNERS[cached_userid] == true
end

local function VerifyLicenceFile()
    if not io.exists(LICENCE_FILENAME) then
        return error("The licence file is invalid or missing!")
    end
end

local function Load()
    --Loading cached userid for offline servers
    TheSim:GetPersistentString(CACHED_USERID_FILENAME, function(load_success, str)
        cached_userid = load_success and str

        VerifyLicenceFile()

        if not HasServerOwnerLicense() then
            return error(TheNet:GetUserID().." missing licence for private mod "..PEARL.MOD_INFO.name..". For more informations, please try to contact the author.")
        end

        PEARL.info("Licence valid.")
    end)
end

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

-- For offline servers
Load()
