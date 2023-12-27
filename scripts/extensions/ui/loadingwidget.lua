--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local MovieDialog = require("screens/moviedialog")

--- @class LoadingWidget
local LoadingWidget = require("widgets/redux/loadingwidget")

---------------------------
-- [[ Constants ]]
---------------------------

local LT_TYPES = PEARL.CONSTS.LT_TYPES
local DO_NOT_LOAD_TIPS = {
    [LT_TYPES.WELCOME] = true
}

--- @---------------------NOTE-----------------------
--- The element names in bg_loading_<name>.xml needs to be just <name> without the bg_loading part!
local CUSTOM_LOADING_IMAGES = {
    "space",
}

local CUSTOM_LOADING_TIPS = {}
local CUSTOM_DISCONNECT_TIPS = {
    ["ID_DST_SERVER_CRASHED"] = {STRINGS.PEARL.UI.LOADING_ERROR, LT_TYPES.CONTROLS},
}

local TEX_PATTERN = "%s.tex"
local XML_PATTERN = "images/bg_loading_%s.xml"

local MOVIE_PATH  = PEARL.MODROOT.."movies/"
local MOVIE_EXT   = ".ogv"

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

local function GetWelcomeLoadingTips()
    local tips = {}

    for i, lt in ipairs(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) do
        lt.type = lt.type and string.upper(lt.type)

        if lt.type == LT_TYPES.WELCOME then
            tips[#tips + 1] = lt
        end
    end

    return tips
end

-- Use our biased loading tip picker in override mode.
local function OverrideLoadingTipPicker(self)
    if Profile:GetLoadingTipsOption() == LOADING_SCREEN_TIP_OPTIONS.NONE then
        return
    end

    local tipids = {}
    for tipid, _ in pairs(CUSTOM_LOADING_TIPS) do
        -- The more the tip is shown the less priority it will have.
        tipids[tipid] = 1 / math.max(self.shownloadingtips[tipid] or 1, 1)
    end

    local tipid = weighted_random_choice(tipids)
    local tipcat = CUSTOM_LOADING_TIPS[tipid]
    local assets = LOADING_SCREEN_TIP_ICONS[tipcat] or LOADING_SCREEN_TIP_ICONS.SURVIVAL
    local lt_table = PEARL.CONSTS.LT_TYPE_TABLES[tipcat]

    return tipid ~= nil and tipcat ~= nil and {
        id      = tipid,
        atlas   = assets.atlas,
        icon    = assets.icon,
        text    = lt_table[tipid]
    } or nil
end

local function LoadCustomTips()
    PEARL.info("Loading custom loading tips ("..tostring(#PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA)..")...")
    for _, loadingtip in ipairs(PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA) do
        if DO_NOT_LOAD_TIPS[loadingtip.type] ~= true then
            local validtype = PEARL.CONSTS.LT_TYPE_TABLES[loadingtip.type] ~= nil
            local tbl = PEARL.CONSTS.LT_TYPE_TABLES[loadingtip.type] or PEARL.CONSTS.LT_TYPE_TABLES[LT_TYPES.OTHER]
            AddLoadingTip(tbl, loadingtip.name, loadingtip.text, loadingtip.data)

            CUSTOM_LOADING_TIPS[loadingtip.name] = validtype and loadingtip.type or LT_TYPES.OTHER
        end
    end
end

-- Load custom backgrounds before the LoadingWidget is initialized.
local loading_screen_keys
local custom_images = false
local function LoadCustomImages()
    Settings.loading_screen_keys = Settings.loading_screen_keys or {}
    loading_screen_keys = Settings.loading_screen_keys
    for _, image in ipairs(CUSTOM_LOADING_IMAGES) do
        Settings.loading_screen_keys[#Settings.loading_screen_keys + 1] = image
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

local function ShowCustomDisconnectTip(self, reason)
    local tip_data = CUSTOM_DISCONNECT_TIPS[reason]
    if type(tip_data) == "table" then
        self:SetLoadingTip(PEARL.unpack(tip_data))
    end
end

PEARL.AddClassFunctionPostCall("SetEnabled", function(self, enabled)
    if not enabled then
        return
    end

    if PEARL.ClientNetwork:IsDisconnected() then
        local reason = PEARL.ClientNetwork:GetDisconnectReason()
        if reason ~= nil then
            ShowCustomDisconnectTip(self, reason)
        end
    end
end, LoadingWidget)

local function SetupWrappers()
    PEARL.AddClassFunctionPreCall("SetEnabled", function(self, enabled)
        if enabled == true then
            return
        end

        -- Restore loading screen keys after first hide.
        if custom_images and PEARL.CONFIG.CUSTOM_LOADING_IMAGES then
            Settings.loading_screen_keys = loading_screen_keys
        end
    end, LoadingWidget)

    if PEARL.CONFIG.CUSTOM_LOADING_IMAGES then
        PEARL.AddUserDataFunctionPostCall("UnregisterAllPrefabs", function()
            PEARL.debug("TheSim:UnregisterAllPrefabs")
            PEARL.ENV.ReloadPreloadAssets()

            -- It looks like we have to register the assets manually after they are unregistered
            -- by the game logic.
            if global_loading_widget then
                ShowCustomImage(global_loading_widget)
            end
        end, TheSim)
    end
end

local function ShowIntroMovie(self, movie_path)
    local music_volume = TheMixer:GetLevel("set_music")

    -- Set music to 100% to ensure the audio will work.
    -- Ignore user's configuration.
    TheMixer:SetLevel("set_music", 1)

    local function OnIntroMovieDone()
        PEARL.ClientLoader:RemoveDeferant("intromovie")

        -- Restore users music volume configuration
        TheMixer:SetLevel("set_music", music_volume)
    end

    TheFrontEnd:FadeToScreen(self, function()
        local dialog = MovieDialog(movie_path, OnIntroMovieDone)
        dialog.OnControl = function(this, control, down)
            if MovieDialog._base.OnControl(this, control, down) then
                return true
            end

            if down and (control == KEY_ENTER or control == KEY_ESCAPE or control == CONTROL_ACCEPT) then
                this:Cancel()
                OnIntroMovieDone()

                return true
            end
        end

        return dialog
    end, nil)

    PEARL.ClientLoader:AddDeferant("intromovie")
end

PEARL.AddClassPreConstruct("widgets/redux/loadingwidget", nil, function(self, ...)
    if TheLoadingTips and PEARL.CONFIG.CUSTOM_LOADING_TIPS_DATA.override == true then
        PEARL.info("Overriding the loading tip picker...")
        PEARL.OverrideValue(TheLoadingTips, "PickLoadingTip", OverrideLoadingTipPicker)
    end
end)

--- We have some additional functionality here aside from the custom images
--- so this should be loaded always.
PEARL.AddClassPostConstruct("widgets/redux/loadingwidget", function(self, ...)
    -- Make sure we are visible right from the start.

    if PEARL.ClientNetwork:IsDisconnected() then
        return
    end

    self:SetEnabled(true)

    -- We should send CFD right from the start so this should be always true in this case.
    if PEARL.ClientNetwork:HasSentCFD() and PEARL.ClientNetwork:IsWaitingForResponse() then
        self:SetLoadingTip(STRINGS.PEARL.UI.LOADING_VERIFICATION, LT_TYPES.CONTROLS)

        -- Hide the loading label since it's not actually true.
        if self and self.loading_widget then
            self.loading_widget:Hide()
        end
    end

    if PEARL.CONFIG.CUSTOM_LOADING_IMAGES then
        ShowCustomImage(self)
    end
end)

PEARL.EventProcessor:AddSafeEventHandler("connection_allowed", function()
    --- @type LoadingWidget
    local self = global_loading_widget
    if self then
        -- This will refresh the loading tips
        self:Reload()

        if self.loading_widget then
            self.loading_widget:Show()
        end

        -- Show nice welcome loading tips for newcomers.
        if PEARL.ClientNetwork:JoinedFirstTime() then
            local welcome_tips = GetWelcomeLoadingTips()
            local loading_tip = welcome_tips[math.random(#welcome_tips)]
            if loading_tip then
                self:SetLoadingTip(loading_tip.text, loading_tip.type)
            end

            -- Also show our custom loading screen if provided
            if #CUSTOM_LOADING_IMAGES > 0 then
                -- Always show custom loading screen for novices.
                Settings.loading_screen_keys = shallowcopy(CUSTOM_LOADING_IMAGES)
                custom_images = true
            end

            local movie_filename = PEARL.CONFIG.INTRO_MOVIE_FILENAME
            if type(movie_filename) == "string" then
                local movie_path = MOVIE_PATH..movie_filename
                if not string.endswith(movie_path, MOVIE_EXT) then
                    movie_path = movie_path..MOVIE_EXT
                end

                if io.exists(movie_path) then
                    TheFrontEnd.gameinterface.SoundEmitter:SetMute(false)
                    ShowIntroMovie(self, movie_path)
                else
                    PEARL.error("Got invalid intro movie path from server's configuration.")
                end
            end
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

--- @TODO: Add custom loading tip category icons.
-- Custom Categories:
SetLoadingTipCategoryIcon(
    LT_TYPES.WELCOME, LOADING_SCREEN_TIP_ICONS.SURVIVAL.atlas, LOADING_SCREEN_TIP_ICONS.SURVIVAL.icon
)

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
    LoadCustomTips()
end
