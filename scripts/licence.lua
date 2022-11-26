
-- Care about licence only on servers
if TheNet:GetIsClient() then
    return
end

local PEARL = PEARL

--------------------------------------
-- [[ Contants ]]
--------------------------------------

local LICENSE_OWNERS = {
    ["KU_NujB7r1v"] = true,
    ["KU_ZC24p91Q"] = true,
}

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function HasServerOwnerLicense()
    return LICENSE_OWNERS[TheNet:GetUserID()] == true
end

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

-- Called after the server owner userid is received in the first instance.
PEARL.AddGlobalFunctionPreCall("StartDedicatedServer", function(...)
    if not HasServerOwnerLicense() then
        return error(TheNet:GetUserID().." missing licence for private mod "..PEARL.MOD_INFO.name..". For more informations, please try to contact the author.")
    end

    PEARL.info("License valid.")
end)
