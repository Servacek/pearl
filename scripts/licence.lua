--[[
Copyright (c) 2023 Fi7iP
The Czechoslovakian Don't Starve Together Game Comunity
<https://discord.gg/RHzJxut>

This file is part of the 'Pearl'.

The source code of this program and all its parts are shared under
the RECEX SHARED SOURCE LICENSE (version 1.0).
This is NOT Free and Open Source software, and the code is
NOT redistributable without permission of the author(s).
The source code licensed under this license is shared "as is" and does
not come with any warranty including the implied warranty of merchandise.
Read the RECEX SHARED SOURCE LICENSE for details.

You should have received a copy of the RECEX SHARED SOURCE LICENSE
in the form of a LICENSE file in the root of the source directory.
If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>

You can contact the author(s) at
<https://steamcommunity.com/profiles/76561198339302667/>
--]]



local PEARL = PEARL

--------------------------------------
-- [[ Contants ]]
--------------------------------------

local LICENCE_FILENAME = PEARL.ROOTDIR.."LICENSE"
local CACHED_USERID_FILENAME = "cached_userid"
local LICENCE_OWNERS = {
    ["KU_NujB7r1v"] = true,
    ["KU_ZC24p91Q"] = true,
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
