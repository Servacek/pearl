
local AgreementScreen = require("screens/agreementscreen")
local PopupDialogScreen = require("screens/redux/popupdialog")

local _agreement_displayed = false

local function OnPlayerEnteredGame()
    if not _agreement_displayed then
        _agreement_displayed = true

        TheFrontEnd:PushScreen(PopupDialogScreen("Československý Server", "Úvodný text...", {
            {text = "Pokračovať", cb = function()
                TheFrontEnd:PopScreen()
                TheFrontEnd:PushScreen(AgreementScreen())
            end}
        }))
    end
end

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("playeractivated", OnPlayerEnteredGame)

    -- This is an lobby alternative for playeractivated
    world:ListenForEvent("entercharacterselect", OnPlayerEnteredGame)
end)
