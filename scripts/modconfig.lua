--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- Keep in mind that only configuration is loaded at this point.
--- Also this is being loaded using 'require', so not mod environment as well.

--- Some mod debug utilities used by 'GetConfigData' require the presence of the mod's environment
--- in this file and since it's being loaded via 'require' we need to set it manually.
---@diagnostic disable-next-line: param-type-mismatch
setfenv(1, PEARL.ENV)

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local WORKSHOP_MOD_PREFIX = "workshop-"

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

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

                tbl[option.name] = TheSim:ZipAndEncodeString(value)
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
    -- options = options or PEARL.MOD_INFO.configuration_options
    -- local option = GetConfigOptionByName(options, optname)
    -- if type(option) ~= "table" or (option.implicit == true and TheNet:IsDedicated()) then
    --     if PEARL.CONFIG.DEBUG_MODE then
    --         return print("[PEARL] [Warn] Overriding an invalid or implicit option ("..optname..").")
    --     else
    --         return error("Attempted to override an invalid or implicit option ("..optname..").")
    --     end
    -- end
end

function ModConfig:GetEnabledServerModsConfigData(client_only)
    local mods_config_data = {}
	for _, modname in ipairs(ModManager:GetEnabledServerModNames()) do
        local hidden = false
        if client_only then
            local mod = ModManager:GetMod(modname)
            if mod.modinfo.all_clients_require_mod == true then
                hidden = true
            end
        end

        if not hidden then
		    mods_config_data[modname] = ModConfig:GetAllConfigDataForMod(modname)
        end
	end

    return mods_config_data
end

function ModConfig:GetEnabledServerModsConfigDataString(client_only)
    return DataDumper(self:GetEnabledServerModsConfigData(client_only), nil, false)
end

--- Push mod config warnings only for the server owner to see.
function ModConfig:LoadBackendOverride(option)
    if option.saved ~= nil then
        if option.master_only and TheShard:IsSecondary() then
            PEARL.warn("Option", option.name, "is only available for the master shard!")
        end

        if option.caves_only and TheShard:IsMaster() then
            PEARL.warn("Option", option.name, "is only available for the secondary shard!")
        end

        if type(option.type) == "string" and option.type:match(type(option.saved)) == nil then
            local log = "Option "..tostring(option.name).." has incorrect type!"
            if PEARL.CONFIG.DEBUG_MODE then
                error(log)
            else
                PEARL.warn(log)
            end
        end
    end

    --- @TODO: Do these checks somewhere else so it counts with commonconfig.lua overrides.
    -- If it's a required option then check if we have configured it.
    -- if option.warn == true and option.saved == nil then
    --     PEARL.warn("Option", option.name, "is not configured! Some functionality may not work.")
    -- end

    if option.experimental == true and (
            option.saved == true or
            (type(option.saved) == "table" and option.saved.ENABLED == true)
        ) then
        PEARL.warn("Experimental feature", option.name, "is enabled!")
    end

    -- Set this even for implicit configurations
    -- since they will override it later.
    self:ApplyConfig(option.name, option.saved)
end

function ModConfig:LoadCommmonConfig()
    -- !![modmain.lua:259]!!
    if not PEARL.ModPersistance:FileExists(PEARL.COMMONCONFIG_PATH) then
        return error(
            "Common config file does not exist at '"..
            tostring(PEARL.COMMONCONFIG_PATH).."'."
        )
    end

    local success, config_str, read_error = PEARL.ModPersistance:GetFileContent(PEARL.COMMONCONFIG_PATH, true)
    if not success or type(config_str) ~= "string" then
        return error(
            "Failed to read common config at '"..
            tostring(PEARL.COMMONCONFIG_PATH)..
            "'. The file exists, but could not be read. Reason: "..
            tostring(read_error or "TheSim did not provide a read error.")
        )
    end

    local fn, message = loadstring(config_str)
    if type(fn) ~= "function" then
        return error(
            "Common config syntax error in '"..
            tostring(PEARL.COMMONCONFIG_PATH)..
            "': "..
            tostring(message)
        )
    end

    setfenv(fn, PEARL.ENV)
    local success, config_or_error = pcall(fn)
    if not success then
        return error(
            "Common config execution failed in '"..
            tostring(PEARL.COMMONCONFIG_PATH)..
            "': "..
            tostring(config_or_error)
        )
    end

    if type(config_or_error) ~= "table" then
        return error(
            "Common config in '"..
            tostring(PEARL.COMMONCONFIG_PATH)..
            "' executed successfully but returned "..type(config_or_error)..
            " instead of a table."
        )
    end

    return config_or_error
end

--- @param name string|number
--- @param value string|number|table
function ModConfig:ApplyConfig(name, value, _loaded)
    if value == nil then
        return -- We are just extending the configuration, so no erasing.
    end

    _loaded = _loaded or PEARL.CONFIG

    -- Currently we are only supporting verification on the first layer.
    if _loaded == PEARL.CONFIG then
        PEARL.ModConfig:VerifyConfig(name)
    end

    if type(value) == "table" and _loaded[name] ~= nil then
        table.update(_loaded[name], value)
        -- for sub_name, sub_value in pairs(value) do
        --     self:ApplyConfig(sub_name, sub_value, _loaded[name])
        -- end
    else
        _loaded[name] = deepcopy(value)
    end
end

function ModConfig:ApplyConfigs(configs)
    for name, value in pairs(configs) do
        self:ApplyConfig(name, value)
    end
end

-------------------------------------
-- [[ Function Overrides ]]
-------------------------------------

rawset(_G, "GetEnabledServerModsConfigData", function()
    -- Verify our configurations first.
    -- If there are some conflicts, it's better to crash before we sent them to the public.
    VerifyConfigOverridesForMod(PEARL.MODNAME)

    local data = ModConfig:GetEnabledServerModsConfigData(PEARL.CONFIG.HIDE_SERVER_ONLY_MODS)
    local data_str = DataDumper(data, nil, false)

    if PEARL.CONFIG.DEBUG_MODE then
        TheSim:LuaPrint("[PEARL] [Debug] PUBLIC SERVER CONFIG DATA:")
        for _, line in pairs(data_str:split("\n")) do
            TheSim:LuaPrint(line)
        end
    end

    return data_str
end)

local _GetEnabledModsModInfoDetails = rawget(_G, "GetEnabledModsModInfoDetails")
rawset(_G, "GetEnabledModsModInfoDetails", function(...)
    local details = _GetEnabledModsModInfoDetails(...)

    for _, modid in ipairs(PEARL.CONFIG.REQUIRED_CLIENT_MODS) do
        local modname = WORKSHOP_MOD_PREFIX..modid
        local modinfo = KnownModIndex:GetModInfo(modname)
        if not modinfo then
            -- We need to know the version and the name of the mod on the Steam workshop, so
            -- the mods needs to be downloaded (query wouldn't work here).
            return error("Required client mod is unknown!\nPlease add \"ServerModSetup(\""..tostring(modid).."\")\" to \"dedicated_server_mods_setup.lua\" :)")
        end

        details[#details + 1] = {
            name = modname,
            info_name = modinfo ~= nil and modinfo.name or modname,
            version = modinfo ~= nil and modinfo.version or "",
            version_compatible = modinfo ~= nil and modinfo.version_compatible or "",

            all_clients_require_mod = true, -- Always true for required mods.
        }
    end

    return details
end)

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ModConfig
