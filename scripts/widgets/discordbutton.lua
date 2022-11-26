
if not PEARL.CONFIG.DISCORD_INVITE then
    return print("Warning: DISCORD_INVITE not provided!")
end

local ImageButton = require("widgets/imagebutton")

-- Add discord button to server menu
AddClassPostConstruct("screens/playerstatusscreen", function(self)
    local _DoInit = self.DoInit

    self.DoInit = function(self, ...)
        local result
        if _DoInit then
            result = _DoInit(self, ...)
        end

        if not self.viewdiscord_button then
            self.viewdiscord_button = self.root:AddChild(ImageButton("images/dcbutton.xml", "dcbutton.tex", "dcbutton_hover.tex", "dcbutton.tex", "dcbutton.tex", nil, { .4, .4 }, { 0, 0 }))
            self.viewdiscord_button:SetHoverText("View Discord", { font = NEWFONT_OUTLINE, offset_x = 0, offset_y = 38, colour = WHITE })
            self.viewdiscord_button:SetOnClick(function()
				VisitURL(PEARL.CONFIG.DISCORD_INVITE)
            end)

            self.servermenunumbtns = self.servermenunumbtns + 1

            local offset_y = 2
            local servermenux = -330
            local servermenuy = 200 - offset_y
            local servermenubtnoffs = 24
            self.viewdiscord_button:SetPosition(servermenux + (self.servermenunumbtns * servermenubtnoffs), servermenuy)
        end

        return result
    end
end)
