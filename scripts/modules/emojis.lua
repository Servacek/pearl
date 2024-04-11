--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


require("fonthelper")

local Emoji = require("util/emoji")
local WordPredictor = require("util/wordpredictor")
local TEMPLATES = require("widgets/redux/templates")
local UIAnim = require("widgets/uianim")
--local Text = require("widgets/text")

local ClientEmojis = PEARL.loadfile("libraries/clientemojimanager")

--------------------------------
-- [[ Constants ]]
--------------------------------

local DELIM = PEARL.CONSTS.DELIMS.EMOJI
local PATTERN = DELIM.."([%S]+)"..DELIM

local DISCORD_EMOJIS = PEARL.FONTS.CUSTOM.NAMES.DISCORD_EMOJIS

local EMOJI_FONT_FILES = {
    [DISCORD_EMOJIS] = PEARL.MODROOT.."fonts/discord_emojis.zip"
}

--------------------------------
-- [[ Assets ]]
--------------------------------

for name, filepath in pairs(EMOJI_FONT_FILES) do
    table.insert(PEARL.ENV.Assets, Asset("FONT", filepath))

    table.insert(GLOBAL.FONTS, {filename = filepath, alias = name, disable_color = true})
end

--------------------------------
-- [[ Setup ]]
--------------------------------

-- Handle duplicates
for _, data in pairs(EMOJI_ITEMS) do
    local name = data.input_name
    while PEARL.EMOJIS.DISCORD[name] ~= nil do
        name = name.."_"
    end

    PEARL.EMOJIS.DISCORD[name] = PEARL.EMOJIS.DISCORD[data.input_name]
    PEARL.EMOJIS.DISCORD[data.input_name] = nil
end

--- This should work after the beta is released.
if (tonumber(APP_VERSION) or 0) >= 597344 then
    AddSimPostInit(function()
        --- Insert only right before the fonts are loaded so the fallbacks cannot be used unloaded.
        table.insert(DEFAULT_FALLBACK_TABLE, 1, DISCORD_EMOJIS)
        table.insert(DEFAULT_FALLBACK_TABLE_OUTLINE, 1, DISCORD_EMOJIS)

        LoadFonts()
    end)
end

--------------------------------
-- [[ Autocomplete ]]
--------------------------------

local function EmojifyString(s)
    return s:gsub(PATTERN, PEARL.EMOJIS.DISCORD)
end

PEARL.OverrideReturnValue(Emoji, "GetWordPredictionDictionary", function(data)
    for name, _ in pairs(PEARL.EMOJIS.DISCORD) do
        table.insert(data.words, name)
    end

    local _GetDisplayString
    _GetDisplayString = PEARL.OverrideValue(data, "GetDisplayString", function(word, ...)
        local custom_emote = PEARL.EMOJIS.DISCORD[word]
        if custom_emote then
            return custom_emote.." "..data.delim..word..data.postfix
        else
            return _GetDisplayString(word, ...)
        end
    end)

    return data
end)

local _Say
_Say = PEARL.OverrideUserdataValue("Say", function(self, message, ...)
    if type(message) == "string" then
        message = EmojifyString(message)
    end

    local needs_saving = false
    for match in message:gmatch(PEARL.CONSTS.UTF_EMOJI_PATTERN) do
        local emoji_name = PEARL.EMOJIS.UTF_TO_NAME[match]
        if emoji_name then
            ClientEmojis:OnEmojiUsed(match, emoji_name)
            needs_saving = true
        end
    end

    if needs_saving then
        ClientEmojis:SavePersistentData()

        PEARL.INST:PushEvent("emojis_used")
    end

    return _Say(self, message, ...)
end, TheNet)

-- local TextEdit = require("widgets/textedit")
-- PEARL.AddClassFunctionPreCall("SetString", function(self, text)
--     print("SET STRING")
--     if text then
--         print(self:GetRegionSize(), self:GetStringSize(text))

--         text:gsub(PEARL.CONSTS.UTF_EMOJI_PATTERN, function(char)
--             if char == "󰃙" then
--                 print("ADDING VIBING CAT!!")
--                 self.btn = self:AddChild(TEMPLATES.EmojiButton(35, false))
--                 self.btn.text:Hide()

--                 self.btn.anim = self.btn:AddChild(UIAnim())
--                 self.btn.anim:SetScale(.7)
--                 self.btn.anim:MoveToBack()
--                 self.btn.anim:SetPosition(self:GetPositionXYZ())
--                 self.btn.anim:Show()

--                 self.btn.anim:GetAnimState():SetBuild("vibing_cat")
--                 self.btn.anim:GetAnimState():SetBank("vibing_cat")
--                 self.btn.anim:GetAnimState():PlayAnimation("default", true)
--             end
--         end)
--     end
-- end, TextEdit)

--     if self.chat_edit.prediction_widget then
--         PEARL.AddClassFunctionPostCall("ResolvePrediction", function(res)
--             local new_text = res[1]
--             if new_text then
--                 res[1] = EmojifyString(new_text)
--             end
--         end, self.chat_edit.prediction_widget, true)
--     end
-- end)
