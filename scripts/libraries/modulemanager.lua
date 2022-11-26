
------------------------------------------
-- [[ Setup ]]
------------------------------------------

local PEARL = PEARL
local WDIR = PEARL.SOURCE_DIR_NAME.."/"..PEARL.MODULES_DIR_NAME

local _modules = {}

------------------------------------------
-- [[ Helpers ]]
------------------------------------------

local function GetModulePath(module)
    return WDIR.."/"..module
end

local function SetModuleEnabled(module, enabled)
    if _modules then
        _modules[module] = enabled
    end
end

------------------------------------------
-- [[ Exposed Functions ]]
------------------------------------------

local function AddModule(module, enabled)
    _modules[module] = enabled or false
end

local function LoadModule(module)
    PEARL.ENV.modimport(GetModulePath(module))

    -- Disable all the loaded modules to prevent them from loading again
    SetModuleEnabled(module, false)
end

local function LoadAllModules()
    for module, enabled in pairs(_modules) do
        if enabled then
            LoadModule(module)
        end
    end
end

return {
    AddModule = AddModule,
    LoadModule = LoadModule,
    LoadAllModules = LoadAllModules,
}
