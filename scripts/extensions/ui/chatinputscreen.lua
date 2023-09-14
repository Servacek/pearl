

--- @class ChatInputScreen
local ChatInputScreen = require("screens/chatinputscreen")
local Text = require("widgets/text")

---------------------------
-- [[ Constants ]]
---------------------------

local WARN_TEXT_SIZE = 16
local WARN_TEXT_COLOUR = RED

---------------------------
-- [[ Local Functions ]]
---------------------------

local function AddWhisperWarning()
    PEARL.AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
        if whisper and PEARL.CONFIG.WHISPER_WARNING then
            local whisper_warn_label = self.root:AddChild(Text(TALKINGFONT, WARN_TEXT_SIZE))
            whisper_warn_label:SetPosition(0, -200, 0)
            whisper_warn_label:SetHAlign(ANCHOR_RIGHT)
            whisper_warn_label:SetString(STRINGS.PEARL.UI.WHISPER_WARNING_TEXT)
            whisper_warn_label:SetColor(WARN_TEXT_COLOUR)
        end
    end)
end

---------------------------
-- [[ Setup ]]
---------------------------

if PEARL.CONFIG.WHISPER_WARNING == true then
    AddWhisperWarning()
end
