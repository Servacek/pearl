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
-- [[ Class Declaration ]]
-------------------------------------

--- @TODO: Crash if an invalid option is provided.

--- @class ModConfig
local ModConfig = {}

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

local function GetGenericConfigData(opt_name, ...)
    -- Prioritize the CONFIG table because some configs can be changed during boot.
    return PEARL.CONFIG[opt_name] or PEARL.GetConfigData(opt_name, ...)
end

local function ParseFoldedConfigName(name, tbl)
    local level = PEARL.CONFIG
    for key in name:gmatch("[^%.]+") do
        level = level and level[key]
        if level ~= nil and not tbl[key] then
            tbl[key] = type(level) == "table" and {} or level
            tbl = tbl[key]
        end
    end
end

local function ParsePublicConfigOption(option, tbl)
    if option.public == true then
        tbl[option.name] = GetGenericConfigData(option.name, true)

        --- Do not ZIP the data in debug mode, clients can handle encoded as well as raw data.
        if option.zip == true and tbl[option.name] and not PEARL.CONFIG.DEBUG_MODE then
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

local function GetModConfigOverridesFor(modname, ...)
    local overrides = KnownModIndex:LoadModOverides(...)
    return overrides and overrides[modname] and overrides[modname].configuration_options
end

local function GetConfigOptionByName(options, optname)
    for _, option in ipairs(options) do
        if option.name == optname then
            return option
        end
    end
end

local function VerifyConfigOverridesForMod(modname)
    local overrides = GetModConfigOverridesFor(modname)
    if type(overrides) ~= "table" then
        return -- Mod has no overrides...
    end

    local mod = ModManager:GetMod(modname)
    if not mod then
        return PEARL.error("Invalid mod provided for config override verification...")
    end

    for name, _ in pairs(overrides) do
        ModConfig:VerifyConfig(name, mod.modinfo.configuration_options)
    end
end

-------------------------------------
-- [[ Public Functions ]]
-------------------------------------

function ModConfig:GetAllSelfConfigData()
    local config_data = {}
    for _, option in ipairs(PEARL.MOD_INFO.configuration_options) do
        if option.public then
            ParsePublicConfigOption(option, config_data)
        end
    end

    return config_data
end

function ModConfig:GetAllConfigDataForMod(modname)
    if modname == PEARL.MODNAME then
        return self:GetAllSelfConfigData()
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

function ModConfig:VerifyConfig(optname, options)
    options = options or PEARL.MOD_INFO.configuration_options
    local option = GetConfigOptionByName(options, optname)
    if type(option) ~= "table" or option.implicit == true then
        return error("Attempted to override an invalid option ("..optname..") in modoverrides.lua.")
    end
end

function ModConfig:GetEnabledServerModsConfigData()
    local mods_config_data = {}
	for _, modname in ipairs(ModManager:GetEnabledServerModNames()) do
		mods_config_data[modname] = ModConfig:GetAllConfigDataForMod(modname)
	end

    return mods_config_data
end

function ModConfig:GetEnabledServerModsConfigDataString()
    return DataDumper(self:GetEnabledServerModsConfigData(), nil, false)
end

-------------------------------------
-- [[ Function Overrides ]]
-------------------------------------

rawset(_G, "GetEnabledServerModsConfigData", function()
    -- Verify our configurations first.
    -- If there are some conflicts, it's better to crash before we sent them to the public.
    VerifyConfigOverridesForMod(PEARL.MODNAME)

    local data_str = ModConfig:GetEnabledServerModsConfigDataString()

    if PEARL.CONFIG.DEBUG_MODE then
        TheSim:LuaPrint("[PEARL] [Debug] PUBLIC SERVER CONFIG DATA:\n"..data_str)
    end

    return data_str
end)

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ModConfig
