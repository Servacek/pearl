--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local ImageButton = require("widgets/imagebutton")
local Button = require("widgets/button")
local Image = require("widgets/image")
local Text = require("widgets/text")

--- @class TEMPLATES
local TEMPLATES = require("widgets/redux/templates")

-------------------------------
-- [[ Constants ]]
-------------------------------

local SOCIAL_BUTTONS_DEFAULT_TEXTURE = PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.DISCORD

-- Default to discord if texture not found.
-- Weird but still better than just crashing...
local SOCIAL_BUTTONS_ATLAS = PEARL.ASSETS.SOCIAL_BUTTONS.ATLAS

local LINKS = PEARL.CONFIG.SOCIAL_LINKS or {}

-------------------------------
-- [[ Public Functions ]]
-------------------------------

function TEMPLATES.LinkButton(link, hover_text, atlas, normal_tex, focus_tex, hover_under)
    local link_button = ImageButton(atlas, normal_tex, focus_tex, normal_tex, normal_tex, normal_tex, { .4, .4 }, { 0, 0 })

    if hover_text ~= nil then
        link_button.hover_data = {
            font        = NEWFONT_OUTLINE,
            offset_x    = 0,
            offset_y    = hover_under == true and -38 or 38,
            colour      = WHITE,
        }
        link_button:SetHoverText(hover_text, link_button.hover_data)
    end

    if type(link) == "string" and #link > 1 then
        link_button:SetOnClick(function()
            VisitURL(link)
        end)
    end

    return link_button
end

function TEMPLATES.AddSocialButton(widget, link, hover, normal, focus, ...)
    normal = normal or SOCIAL_BUTTONS_DEFAULT_TEXTURE
    focus = focus or io.noext(normal).."_hover.tex"

    return widget:AddChild(TEMPLATES.LinkButton(
        link, hover, SOCIAL_BUTTONS_ATLAS, normal, focus, ...
    ))
end

function TEMPLATES.GetSocialLinkButtons(widget, hover_under)
    local site_buttons = {}

    if LINKS.DISCORD then
        site_buttons[#site_buttons+1] = TEMPLATES.AddSocialButton(widget,
            LINKS.DISCORD, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.DISCORD,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.DISCORD, nil, hover_under
        )
    end

    if LINKS.YOUTUBE then
        site_buttons[#site_buttons+1] = TEMPLATES.AddSocialButton(widget,
            LINKS.YOUTUBE, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.YOUTUBE,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.YOUTUBE, nil, hover_under
        )
    end

    if LINKS.TWITCH then
        site_buttons[#site_buttons+1] = TEMPLATES.AddSocialButton(widget,
            LINKS.TWITCH, STRINGS.PEARL.UI.SOCIAL_LINK_BUTTON_HOVERS.TWITCH,
            PEARL.ASSETS.SOCIAL_BUTTONS.TEXTURES.TWITCH, nil, hover_under
        )
    end

    return site_buttons
end

local SPACING = 7
function TEMPLATES.EmojiButton(size, dynamic_bg, bg_margin)
    local btn = Button()

    btn.bg = btn:AddChild(Image("images/global.xml", "square.tex"))
    btn.bg:ScaleToSize(size + (bg_margin or SPACING), size + (bg_margin or SPACING))
    btn.bg:SetTint(0, 0, 0, 0)
    btn.bg:MoveToBack()

    btn.locked_overlay = btn:AddChild(Image("images/global.xml", "square.tex"))
    btn.locked_overlay:ScaleToSize(size, size)
    btn.locked_overlay:SetTint(0, 0, 0, .6)
    btn.locked_overlay:MoveToFront()
    btn.locked_overlay:Hide()

    local crafting_menu_atlas = resolvefilepath(CRAFTING_ATLAS)
    btn.locked_overlay.lock_icon = btn.locked_overlay:AddChild(Image(crafting_menu_atlas, "pinslot_fg_lock.tex"))
    btn.locked_overlay.lock_icon:SetScale(.7)

    btn.new_tag_image = btn:AddChild(Image("images/global_redux.xml", "motd_sale_tag.tex"))
    btn.new_tag_image:SetScale(.2)
    btn.new_tag_image:SetRotation(-90)
    btn.new_tag_image:SetPosition(-7, 7)

    btn.new_tag_image.text = btn.new_tag_image:AddChild(Text(HEADERFONT, 52, STRINGS.PEARL.UI.EMOJI_MENU.NEW, UICOLOURS.BLACK))
    btn.new_tag_image.text:SetPosition(20, 20)
    btn.new_tag_image.text:SetRotation(45)
    btn.new_tag_image:Hide()

    btn.text:SetHAlign(ANCHOR_MIDDLE)
    btn.text:SetVAlign(ANCHOR_MIDDLE)

    if dynamic_bg then
        PEARL.AddClassFunctionPostCall("SetTextSize",
        PEARL.AddClassFunctionPostCall("SetText", function()
            local w, h = btn.text:GetRegionSize()
            btn.bg:ScaleToSize(w + (bg_margin or SPACING), h + (bg_margin or SPACING))
        end, btn), btn)
    end

    btn:SetTextSize(size)
    btn:SetControl(CONTROL_PRIMARY)

    -- btn.ongainfocus = function()
    --     if scale_on_focus == true then
    --         btn:SetTextSize(size + 7)
    --     end
    -- end

    -- btn.onlosefocus = function()
    --     if scale_on_focus == true then
    --         btn:SetTextSize(size)
    --     end
    -- end

    -------------
    -- Public functions
    btn.SetOnLoseFocus = function(self, fn)
        btn.onlosefocus = btn.onlosefocus or function() end
        PEARL.AddFunctionPostCall("onlosefocus", fn, btn)
    end
    btn.SetOnGainFocus = function(self, fn)
        btn.ongainfocus = btn.ongainfocus or function() end
        PEARL.AddFunctionPostCall("ongainfocus", fn, btn)
    end

    btn.ShowHover = function(self)
        return btn.hovertext_root and (btn.hovertext_root._Show or btn.hovertext_root.Show)(btn.hovertext_root)
    end

    btn.HideHover = function(self)
        return btn.hovertext_root and (btn.hovertext_root._Hide or btn.hovertext_root.Hide)(btn.hovertext_root)
    end

    btn.Lock = function(self)
        btn:Disable()
        btn.locked_overlay:Show()
    end

    btn.Unlock = function(self)
        btn.locked_overlay:Hide()
        btn:Enable()
    end

    btn.AddHoverText = function()
        if btn.hovertext_root then
            return
        end

        btn:SetHoverText(" ", {offset_y = 45})
    end

    PEARL.AddClassFunctionPostCall("OnHide", function()
        btn:HideHover()
    end, btn)

    -------------------------

    return btn
end
