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

------------------------------------------
-- [[ Locals ]]
------------------------------------------

--- @type table<string, boolean>
local _modules = {}

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @singleton
--- @class ModuleManager
local ModuleManager = {
    loader = PEARL.ENV.modimport,
    wdir = PEARL.SOURCE_DIR_NAME.."/"..PEARL.MODULES_DIR_NAME,
}

------------------------------------------
-- [[ Local Functions ]]
------------------------------------------

local function get_module_path(module)
    return tostring(ModuleManager.wdir).."/"..module
end

------------------------------------------
-- [[ Exposed Functions ]]
------------------------------------------

--- Set the function used to load the modules.
--- @param loader function The loader function used to load the modules.
---
--- @return nil
function ModuleManager:SetLoader(loader)
    self.loader = loader
end

--- Sets the module directory from which we load all the modules.
--- @param dir string The path to the modules directory depending on the loader.
---
--- @return nil
function ModuleManager:SetModuleDirectory(dir)
    self.wdir = dir
end

--- Adds the given module to the cache.
--- @param md_name string Name of the module file stored in the 'modules' folder (without the '.lua' postfix)
--- @param enabled boolean|table|string? Whether it should be loaded by LoadAllModules or not.
--- If this is a table then the return value of table.empty is used instead.
--- If this is a number then everything above 0 is considered true and everything below is false.
--- If this is a string then it's reversed emptiness is considered.
--- Otherwise any non-null value is considered true.
---
--- @return nil
function ModuleManager:AddModule(md_name, enabled)
    if type(enabled) == "table" then
        enabled = table.empty(enabled) == false
    end

    if type(enabled) == "number" then
        enabled = enabled > 0
    end

    if type(enabled) == "string" then
        enabled = #enabled > 0
    end

    _modules[md_name] = enabled ~= nil and enabled ~= false or false
end

--- Loads the given module file from the mod's modules folder and returns it's results.
--- @param md_name string Name of the module file stored in the 'modules' folder (without the '.lua' postfix)
---
--- @return any results Any results returned by the module file.
function ModuleManager:LoadModule(md_name)
    -- Add the module to the module cache and set is as disabled so it doesn't load again.
    self:AddModule(md_name)

    return self.loader(get_module_path(md_name))
end

--- Loads all enabled modules stored in the cache and disables them afterward.
---
--- @return nil
function ModuleManager:LoadAllModules()
    for module, enabled in pairs(_modules) do
        if enabled == true then
            self:LoadModule(module)
        end
    end
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return ModuleManager
