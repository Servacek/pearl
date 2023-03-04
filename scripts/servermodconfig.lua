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
    -- Prioritize the CONFIG table because some configs can be changed during boot.
    return PEARL.CONFIG[opt_name] or PEARL.GetConfigData(opt_name, ...)
end

--- @TODO: Does not handle cases where the configuration doesn't exist.
local function ParseFoldedConfigName(name, tbl)
    local level = PEARL.CONFIG
    local keys = name:split(".")
    for _, key in ipairs(keys) do
        level = level and level[key]
        if not tbl[key] then
            tbl[key] = type(level) == "table" and {} or level
            tbl = tbl[key]
        end
    end
end

local function ParsePublicConfigOption(option, tbl)
    if option.public == true then
        tbl[option.name] = GetGenericConfigData(option.name, true)

        --- @TODO: Add zip support for more specific public options.
        if option.zip == true and tbl[option.name] then
            local value = tbl[option.name]
            local type = type(value)
            if type == "string" then
                -- Do not zip empty strings.
                if #value <= 0 then
                    tbl[option.name] = nil
                    return
                end

                tbl[option.name] = TheNet:ZipAndEncodeString(value)
            elseif type == "table" then
                -- Do not zip empty tables
                if IsTableEmpty(value) then
                    tbl[option.name] = nil
                    return
                end

                tbl[option.name] = ZipAndEncodeString(value)
            else
                return print("[PEARL] [Error] Failed to zip and encode type", type)
            end
        end

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
		mods_config_data[modname] = GetAllConfigDataForMod(modname)
	end

    if PEARL.CONFIG.DEBUG_MODE then
        print("[PEARL] [Debug] PUBLIC SERVER CONFIG DATA:\n", DataDumper(mods_config_data, nil, false))
    end

    return DataDumper(mods_config_data, nil, false)
end)
