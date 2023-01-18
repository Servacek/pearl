--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- Keep in mind that only configuration is loaded at this point.
--- Also this is being loaded using 'require', so not mod environment as well.

--- Some mod debug utilities used by 'GetConfigData' require the presence of the mod's environment
--- in this file and since it's being loaded via 'require' we need to set it manually.
setfenv(1, PEARL.ENV)

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

local function GetGenericConfigData(opt_name, ...)
    return PEARL.GetConfigData(opt_name, ...) or PEARL.CONFIG[opt_name]
end

local function ParseFoldedConfigName(name, tbl)
    local level = PEARL.CONFIG
    local keys = name:split(".")
    for _, key in ipairs(keys) do
        level = level[key]
        if not tbl[key] then
            tbl[key] = type(level) == "table" and {} or level
            tbl = tbl[key]
        end
    end
end

local function ParsePublicConfigOption(option, tbl)
    if option.public == true then
        tbl[option.name] = GetGenericConfigData(option.name, true)
        return
    end

    if type(option.public) == "string" then
        ParseFoldedConfigName(option.public, tbl)
    end

    if type(option.public) == "table" then
        for _, pub_opt in ipairs(option.public) do
            ParseFoldedConfigName(pub_opt, tbl)
        end
    end
end

local function GetAllSelfConfigData()
    local config_data = {}
    for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
        if option.public then
            ParsePublicConfigOption(option, config_data)
        end
    end

    return config_data
end

local function GetAllConfigDataForMod(modname)
    if modname == PEARL.MODNAME then
        return GetAllSelfConfigData()
    end

    local config = KnownModIndex:LoadModConfigurationOptions(modname, false)
    if type(config) ~= "table" then
        return {}
    end

    local config_data = {}
    for _, v in ipairs(config) do
        config_data[v.name] = v.saved ~= nil and v.saved or v.default
    end

    return config_data
end

-------------------------------------
-- [[ Function Overrides ]]
-------------------------------------

rawset(_G, "GetEnabledServerModsConfigData", function()
    local mods_config_data = {}

	for _, modname in ipairs(ModManager:GetEnabledServerModNames()) do
		local modinfo = KnownModIndex:GetModInfo(modname)
		if modinfo ~= nil and modinfo.all_clients_require_mod then
			mods_config_data[modname] = GetAllConfigDataForMod(modname)
		end
	end

    if PEARL.CONFIG.DEBUG_MODE then
        print("[PEARL] [Debug] PUBLIC SERVER CONFIG DATA:\n", DataDumper(mods_config_data, nil, false))
    end

    return DataDumper(mods_config_data, nil, false)
end)

-- rawset(_G, "GetEnabledModsModInfoDetails", function()
--     local modinfo_details = {}

--     for _, mod_name in pairs(ModManager:GetEnabledServerModNames()) do
--         local modinfo = KnownModIndex:GetModInfo(mod_name)
--         -- If there is a space between the prefix and the ID then
--         -- the TheSim:QueueDownloadTempMod will be able to recognize it
--         -- but the url will be invalid.
--         local info_name
--         if mod_name == PEARL.MODNAME then
--             info_name = nil
--         end

--         table.insert(modinfo_details, {
--             name = mod_name,
--             info_name = info_name or modinfo ~= nil and modinfo.name or mod_name,
--             version = modinfo ~= nil and modinfo.version or "",
--             version_compatible = modinfo ~= nil and modinfo.version_compatible or "",
--             all_clients_require_mod = modinfo ~= nil and modinfo.all_clients_require_mod == true,
--         })
--     end

--     return modinfo_details
-- end)
