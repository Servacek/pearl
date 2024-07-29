--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


PEARL.AddClassPreConstruct("widgets/scripterrorwidget", function(self, title, text, buttons)
    table.clear(buttons)

    table.update(buttons, {
        {text=STRINGS.PEARL.UI.SCRIPTERRORWIDGET.REJOIN, cb = function()
            TheSim:ResetError()
            PEARL.Rejoin()
        end},
        {text=STRINGS.PEARL.UI.SCRIPTERRORWIDGET.BACK, cb = function()
            TheSim:ResetError()
            SimReset()
        end},
        {text=STRINGS.PEARL.UI.SCRIPTERRORWIDGET.QUIT, cb = function()
            TheSim:ForceAbort()
        end},
    })

    -- Only admins can do server wide restarts!
    if BRANCH == "dev" and TheNet:GetIsServerAdmin() then
        table.insert(buttons, 2, {
            text=STRINGS.PEARL.UI.SCRIPTERRORWIDGET.RELOAD, cb = function()
                TheSim:ResetError()
                c_reset()
            end
        })
    end

    -- Only makes sense to display the "Disable Mods" button when we actually have some mods to disable.
    if (KnownModIndex:GetAllEnabledModsCount() - 1) > 0 then
        table.insert(buttons, #buttons - 1, {
            text=STRINGS.PEARL.UI.SCRIPTERRORWIDGET.DISABLE_MODS, cb = function()
                TheSim:ResetError()
                KnownModIndex:DisableAllMods()
                ForceAssetReset()
                KnownModIndex:Save(function() SimReset() end)
            end
        })
    end
end)

PEARL.AddClassPostConstruct("widgets/scripterrorwidget", function(self)
    if self.additionaltext then
        local str = ""
        if (KnownModIndex:GetAllEnabledModsCount() - 1) > 0 then
            str = self.additionaltext:GetString()
        end

        local additionaltext =STRINGS.PEARL.UI.CLIENTERROR_DETAIL
        if KnownModIndex:IsModKnownBad(PEARL.MODNAME) then
            additionaltext = STRINGS.PEARL.UI.CLIENTERROR_DETAIL_SELF
        end

        self.additionaltext:SetString(additionaltext.."\n"..(str or ""))
    end
end)
