--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local TextEdit = require("widgets/textedit")

local Emoji = require("util/emoji")
local WordPredictionWidget = require("widgets/wordpredictionwidget")

--------------------------------
-- [[ Autocomplete ]]
--------------------------------

--- @TODO: Discord like emoji autocomplete?
-- if self.chat_edit.prediction_widget then
--         PEARL.AddClassFunctionPostCall("ResolvePrediction", function(res)
--             local new_text = res[1]
--             if new_text then
--                 res[1] = EmojifyString(new_text)
--             end
--         end, self.chat_edit.prediction_widget, true)
--     end
-- end)

-- local _SetString
-- _SetString = PEARL.OverrideValue(TextEdit, "SetString", function(self, text, ...)
--     _SetString(self, PEARL.EMOJIS.EmojifyGameString(text), ...)
-- end, true)
