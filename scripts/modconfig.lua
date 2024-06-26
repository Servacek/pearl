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
        tbl[option.name] = PEARL.CONFIG[option.name]

        --- Do not ZIP the data in debug mode, clients can handle encoded as well as raw data.
        if option.zip == true and tbl[option.name] ~= nil then --and not PEARL.CONFIG.DEBUG_MODE then
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
    options = options or PEARL.MOD_INFO.configuration_options
    local option = GetConfigOptionByName(options, optname)
    if type(option) ~= "table" or (option.implicit == true and TheNet:IsDedicated()) then
        return error("Attempted to override an invalid or implicit option ("..optname..") in modoverrides.lua.")
    end
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
    local config_str = PEARL.ClusterPersistence:GetFileContent(PEARL.COMMONCONFIG_PATH, true)
    if type(config_str) ~= "string" then
        return error("Failed to load common config!")
    end

    local fn, message = loadstring(config_str)
    if type(fn) ~= "function" then
        return error("Failed to load common config string! Reason: " .. tostring(message))
    end

    local success, config = RunInEnvironment(fn, {})
    if not success or type(config) ~= "table" then
        return PEARL.warn("No common configurations set.")
    end

    return config
end

function ModConfig:TryUnzipAndDecodeOption(option)
    local config_data = PEARL.GetModConfigData(option.name)
    print("Received", config_data, "from GetModConfigData")
    if type(config_data) ~= "string" then
        print(option.name, "not a string so returning", config_data)
        return config_data -- There is nothing to be unzipped or decoded.
    end

    --- This returns an empty string on failure.
    local unzipped, unzipped_str = pcall(TheSim.DecodeAndUnzipString, TheSim, config_data)
    if unzipped ~= true or unzipped_str == nil or unzipped_str == "" then
        unzipped_str = config_data -- Unzipping failed, try to use the raw zipped? string.

        -- Even options marked as zipped may not be zipped.
        -- if option.zip then
        --     PEARL.error("Failed to unzip configuration option", option.name, "using the unzipped form instead.")
        -- end
    end

    if unzipped_str then
        if option.type == "string" then
            return unzipped_str
        elseif option.type == "table" then
            -- Deconding for JSON strings
            local decoded, decoded_data = pcall(json.decode, unzipped_str) --- @type boolean?, any
            if decoded == true and type(decoded_data) == "table" then
                return decoded_data
            end

            -- Decoding for Lua strings (from DataDumper)
            decoded, decoded_data = RunInSandboxSafe(unzipped_str)
            if decoded == true and type(decoded_data) == "table" then
                return decoded_data
            end

            PEARL.error("Decoding configuration option", option.name, "failed! Returning default value...")
            return option.default
        end
    end

    return config_data -- Else return the default value (e. g. for table types)
end

--- @param name string|number
--- @param value string|number|table
function ModConfig:ApplyConfig(name, value)
    if value == nil or PEARL.CONFIG[name] == value then
        return -- We are just extending the configuration, so no erasing.
    end

    if PEARL.DEFAULT_CONFIG[name] ~= nil and type(PEARL.DEFAULT_CONFIG[name]) ~= type(value) then
        return error("Attempted to override option ("..name..") with an invalid value "..string.raw(tostring(value)))
    end

    -- Currently we are only supporting verification on the first layer.
    PEARL.ModConfig:VerifyConfig(name)
    if type(value) == "table" then
        local invalid_key = table.update(PEARL.CONFIG[name], value)
        if invalid_key then
            return error("Attempted to override an invalid key ("..invalid_key..") for option ("..name..")!")
        end
    else
        PEARL.CONFIG[name] = value
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

--- If we provide invalid data it will just fail, see networking.lua:354
rawset(_G, "GetEnabledServerModsConfigData", function()
    -- Verify our configurations first.
    -- If there are some conflicts, it's better to crash before we sent them to the public.
    VerifyConfigOverridesForMod(PEARL.MODNAME)

    local data = ModConfig:GetEnabledServerModsConfigData(PEARL.CONFIG.HIDE_SERVER_ONLY_MODS)
    local data_str = DataDumper(data, nil, false)

    --if PEARL.CONFIG.DEBUG_MODE then
        TheSim:LuaPrint("[PEARL] [Debug] PUBLIC SERVER CONFIG DATA:")
        for _, line in pairs(data_str:split("\n")) do
            print(line)
        end
    --end

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
