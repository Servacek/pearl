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
-- [[ Constants ]]
---------------------------

--- @---------------------NOTE-----------------------
--- The element names in bg_loading_<name>.xml needs to be just <name> without the bg_loading part!
local CUSTOM_LOADING_IMAGES = {
    "space",
}

local TEX_PATTERN = "%s.tex"
local XML_PATTERN = "images/bg_loading_%s.xml"

---------------------------
-- [[ Public Methods ]]
---------------------------

function LoadingWidget:Reload()
    self.is_enabled = false
    self:SetEnabled(true)
end

function LoadingWidget:SetLoadingTip(text, type)
    if self.loading_tip_text then
        self.loading_tip_text:SetString(text)
    end

    if self.loading_tip_icon then
        local assets = LOADING_SCREEN_TIP_ICONS[string.upper(type)]
        self.loading_tip_icon:SetTexture(assets.atlas, assets.icon)
    end
end

---------------------------
-- [[ Local Functions ]]
---------------------------

local loading_screen_tips
local custom_images = false
local function LoadCustomImages()
    Settings.loading_screen_keys = Settings.loading_screen_keys or {}
    loading_screen_tips = Settings.loading_screen_keys
    for _, image in ipairs(CUSTOM_LOADING_IMAGES) do
        Settings.loading_screen_keys[#Settings.loading_screen_keys + 1] = image
    end

    custom_images = false
    if PEARL.ClientNetwork:IsNovice() and #CUSTOM_LOADING_IMAGES > 0 then
        -- Always show custom loading screen for novices.
        Settings.loading_screen_keys = shallowcopy(CUSTOM_LOADING_IMAGES)

        custom_images = true
    end
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

local function SetupWrappers()
    PEARL.AddClassFunctionPreCall("SetEnabled", function(self, enabled)
        if enabled == true then
            return
        end

        -- Restore loading screen keys after first hide.
        if custom_images then
            Settings.loading_screen_keys = loading_screen_tips
        end
    end, LoadingWidget)

    PEARL.AddUserDataFunctionPostCall("UnregisterAllPrefabs", function()
        PEARL.ENV.ReloadPreloadAssets()

        -- It looks like we have to register the assets manually after they are unregistered
        -- by the game logic.
        if global_loading_widget then
            ShowCustomImage(global_loading_widget)
        end
    end, TheSim)
end

--- We have some additional functionality here aside from the custom images
--- so this should be loaded always.
PEARL.AddClassPostConstruct("widgets/redux/loadingwidget", function(self, ...)
    -- Make sure we are visible right from the start.

    -- Just not for novices, because of the welcome screen and additional checks.
    if PEARL.ClientNetwork:IsNovice() then
        return
    end

    if TheFrontEnd then
        TheFrontEnd:SetFadeLevel(1)
    end

    self:SetEnabled(true)

    -- We should send CFD right from the start so this should be always true in this case.
    if PEARL.ClientNetwork:HasSentCFD() and PEARL.ClientNetwork:IsWaitingForResponse() then
        self:SetLoadingTip(STRINGS.PEARL.UI.LOADING_VERIFICATION, "CONTROLS")

        -- Hide the loading label since it's not actually true.
        if self and self.loading_widget then
            self.loading_widget:Hide()
        end
    end

    if PEARL.CONFIG.CUSTOM_LOADING_IMAGES then
        ShowCustomImage(self)
    end
end)

PEARL.EventProcessor:AddSafeEventHandler("connection_allowed", function(from_server)
    if global_loading_widget and from_server then
        -- This will refresh the loading tips
        global_loading_widget:Reload()

        if global_loading_widget.loading_widget then
            global_loading_widget.loading_widget:Show()
        end
    end
end)

if PEARL.CONFIG.CUSTOM_LOADING_IMAGES then
    LoadCustomImages()
    SetupWrappers()
end

---------------------------
-- [[ Loading Tips ]]
---------------------------

local welcome_loading_tips = {}

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

        if novice and lt.type == LT_TYPES.WELCOME then
            table.insert(welcome_loading_tips, {
                type = string.upper(LT_TYPES.SURVIVAL),
                text = lt.text,
                name = name,
            })

            return -- Do not add this tip to the list of regular ones.
        end

        AddLoadingTip(type, name, lt.text, lt.data)
    end

    RemoveDefaultLoadingTips()

    PEARL.info("Loading custom loading tips ("..tostring(#PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA)..")...")

    for i, lt in ipairs(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) do
        local name = string.upper(lt.name or PEARL.MODNAME.."_TIP_"..tostring(i))
        OptionalAddLoadingTip(name, lt)
    end
end

if PEARL.ClientNetwork:IsNovice() and #welcome_loading_tips > 0 then
    local welcome_tip_shown = false

    --- @class LoadingTipsData
    local LoadingTipsData = require("loadingtipsdata")
    PEARL.OverrideReturnValue(LoadingTipsData, "PickLoadingTip", function(data)
        if welcome_tip_shown then
            return data
        end

        welcome_tip_shown = true

        local loading_tip = welcome_loading_tips[math.random(#welcome_loading_tips)]
        if loading_tip then
            data.text   = loading_tip.text
            data.id     = loading_tip.name

            data.atlas   = LOADING_SCREEN_TIP_ICONS[loading_tip.type].atlas
            data.icon   = LOADING_SCREEN_TIP_ICONS[loading_tip.type].icon
        end

        return data
    end)
end
