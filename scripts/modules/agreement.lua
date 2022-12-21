--[[
    @TODOS:
    - Make the screen/popup title and body configurable.
    - Save a cache file when the player agrees to the rules,
      so the popup will not show again.
--]]

-- We have already agreed to the agreement.
if io.exits(PEARL.CONSTS.AGREEMENT_FILE_PATH) then
    return
end

local AgreementScreen = require("screens/agreementscreen")
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local _agreement_displayed = false

local function OnPlayerFinishedAgreement(self, agreed)
    self:Close()

    if not agreed then
        return DoRestart(true)
    end

    if not io.create(PEARL.CONSTS.AGREEMENT_FILE_PATH) then
        PEARL.error("Failed to create the agreement cache file!")
    end
end

local function OnPlayerEnteredGame()
    if _agreement_displayed then
        return
    end

    TheFrontEnd:PushScreen(PopupDialogScreen(PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].title, PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].description, {
        {text = STRINGS.PEARL.UI.INTRO_POPUP_BUTTON_CONTINUE, cb = function()
            local agreement_screen = AgreementScreen()
            agreement_screen:SetOnContinue(OnPlayerFinishedAgreement)

            TheFrontEnd:PopScreen()
            TheFrontEnd:PushScreen(agreement_screen)
        end}
    }))

    -- We should not get here if the agreement was not accepted
    _agreement_displayed = true
end

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("playeractivated", OnPlayerEnteredGame)

    -- This is an lobby alternative for playeractivated
    world:ListenForEvent("entercharacterselect", OnPlayerEnteredGame)
end)
