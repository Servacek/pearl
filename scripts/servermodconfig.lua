
local PEARL = PEARL

-------------------------------------
-- [[ Private Functions ]]
-------------------------------------

local function GetAllSelfConfigData()
    local config_data = {}
    for name, value in pairs(PEARL.CONFIG.PUBLIC) do
        if value == true then
            config_data[name] = PEARL.GetConfigData(name) or PEARL.CONFIG[name]
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

PEARL.OverrideGlobal("GetEnabledServerModsConfigData", function()
    local mods_config_data = {}

	for _, modname in ipairs(ModManager:GetEnabledServerModNames()) do
		local modinfo = KnownModIndex:GetModInfo(modname)
		if modinfo ~= nil and modinfo.all_clients_require_mod then
			mods_config_data[modname] = GetAllConfigDataForMod(modname)
		end
	end

    return DataDumper(mods_config_data, nil, false)
end)

-- PEARL.OverrideGlobal("GetEnabledModsModInfoDetails", function()
--     local modinfo_details = {}

--     for k,mod_name in pairs(ModManager:GetEnabledServerModNames()) do
--         local modinfo = KnownModIndex:GetModInfo(mod_name)
--         if mod_name == "workshop-2189004162" then
--             mod_name = "workshop-         2189004162"
--         end

--         table.insert(modinfo_details, {
--             name = mod_name,
--             info_name = modinfo ~= nil and modinfo.name or mod_name,
--             version = modinfo ~= nil and modinfo.version or "",
--             version_compatible = modinfo ~= nil and modinfo.version_compatible or "",
--             all_clients_require_mod = modinfo ~= nil and modinfo.all_clients_require_mod == true,
--         })
--     end

--     return modinfo_details
-- end)
