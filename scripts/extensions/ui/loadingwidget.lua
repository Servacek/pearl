--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @class LoadingWidget
local LoadingWidget = require("widgets/redux/loadingwidget")

local LT_TYPES = PEARL.CONSTS.LT_TYPES

---------------------------
-- [[ Loading Images ]]
---------------------------

--- @---------------------NOTE-----------------------
--- The element names in bg_loading_<name>.xml needs to be just <name> without the bg_loading part!
local CUSTOM_LOADING_IMAGES = {
    "space",
}

local TEX_PATTERN = "%s.tex"
local XML_PATTERN = "images/bg_loading_%s.xml"

Settings.loading_screen_keys = Settings.loading_screen_keys or {}
for _, image in ipairs(CUSTOM_LOADING_IMAGES) do
    Settings.loading_screen_keys[#Settings.loading_screen_keys+1] = image
end

local function ShowCustomImage(self)
    if not self.selected_key or not table.contains(CUSTOM_LOADING_IMAGES, self.selected_key) then
        return
    end

    if self.bg and self.is_enabled then
        local atlas, tex = XML_PATTERN:format(
            self.selected_key
        ), TEX_PATTERN:format(self.selected_key)
        self.bg:SetTexture(atlas, tex)
    end
end

PEARL.AddClassPostConstruct("widgets/redux/loadingwidget", function(self, ...)
    -- Make sure we are visible right from the start.
    if TheFrontEnd then
        TheFrontEnd:SetFadeLevel(1)
    end

    self:SetEnabled(true)
    ShowCustomImage(self)
end)

PEARL.AddUserDataFunctionPostCall("UnregisterAllPrefabs", function()
    PEARL.ENV.ReloadPreloadAssets()

    -- It looks like we have to register the assets manually after they are unregistered
    -- by the game logic.
    if global_loading_widget then
        ShowCustomImage(global_loading_widget)
    end
end, TheSim)

---------------------------
-- [[ Loading Tips ]]
---------------------------

--[[
    <string_table> can be one of the following:
    LOADING_SCREEN_SURVIVAL_TIPS
    LOADING_SCREEN_LORE_TIPS
    LOADING_SCREEN_CONTROL_TIPS
    LOADING_SCREEN_CONTROL_TIPS_CONSOLE
    LOADING_SCREEN_CONTROL_TIPS_NOT_CONSOLE
    STRINGS.UI.LOADING_SCREEN_OTHER_TIPS (It is recommended to use this table as it is reserved for custom loading tips.)
    <tip_id> must be a unique ID name.
    <tip_string> is the actual tip string to be displayed.
    <controltipdata> is a table containing input control bindings to be used in the tip string. Refer to LOADING_SCREEN_CONTROL_TIP_KEYS in constants.lua and LOADING_SCREEN_CONTROL_TIPS in strings.lua for an example usage.
]]
-- Loading screen tips setup
if type(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) == "table" and #PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA > 0 then
    local default_removed = false
    local function RemoveDefaultLoadingTips()
        if PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA.override ~= true then
            return
        end

        if not default_removed then
            PEARL.info("Removing default loading tips...")
            PEARL.RemoveAllLoadingTips()
        end

        default_removed = true
    end

    local novice = PEARL.ClientNetwork:IsNovice()
    local function OptionalAddLoadingTip(name, lt)
        local type = PEARL.CONSTS.LT_TYPE_TABLES[lt.type] or PEARL.CONSTS.LT_TYPE_TABLES[LT_TYPES.OTHER]

        if novice then
            if lt.type ~= LT_TYPES.WELCOME then
                return
            else
                -- For novices keep default loading tips
                -- until some welcome tip is found.
                -- So when no welcome tips are set,
                -- the default ones will stay.
                RemoveDefaultLoadingTips()
                type = PEARL.CONSTS.LT_TYPE_TABLES["survival"]
            end
        end

        AddLoadingTip(type, name, lt.text, lt.data)
    end

    if not novice then
        RemoveDefaultLoadingTips()
    end

    PEARL.info("Loading custom loading tips ("..tostring(#PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA)..")...")

    for i, lt in ipairs(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) do
        local name = string.upper(lt.name or PEARL.MODNAME.."_TIP_"..tostring(i))
        OptionalAddLoadingTip(name, lt)
    end
end
