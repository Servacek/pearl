--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local ImageButton = require("widgets/imagebutton")

local TEMPLATES = require("widgets/redux/templates")


function TEMPLATES.LinkButton(link, hover_text, atlas, normal_tex, focus_tex, hover_under)
    local link_button = ImageButton(atlas, normal_tex, focus_tex, normal_tex, normal_tex, nil, { .4, .4 }, { 0, 0 })

    link_button:SetHoverText(hover_text, {
        font        = NEWFONT_OUTLINE,
        offset_x    = 0,
        offset_y    = hover_under and -38 or 38,
        colour      = WHITE,
    })
    link_button:SetOnClick(function()
        VisitURL(link)
    end)

    return link_button
end
