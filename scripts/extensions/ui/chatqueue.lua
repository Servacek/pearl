--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local ChatQueue = require("widgets/redux/chatqueue")

local ForceRefreshWidgets = ChatQueue.RefreshWidgets

-------------------------------
-- [[ Function Overrides ]]
-------------------------------

-- Let the message be added to the queue
-- PEARL.AddClassFunctionPreCall("PushMessage", function(self)
--     return not self.toggled
-- end, ChatQueue)


PEARL.AddClassFunctionPreCall("RefreshWidgets", function(self)
    return not self.toggled
end, ChatQueue)

-------------------------------
-- [[ Additional Functions ]]
-------------------------------

function ChatQueue:Clear()
    if self.chat_queue_data then
        for k, _ in pairs(self.chat_queue_data) do
            self.chat_queue_data[k] = nil
        end
    end

    if self.widget_rows then
        for i = 1, #self.widget_rows do
            self.widget_rows[i]:SetChatData(ChatTypes.Message, 0)
        end
    end
end

function ChatQueue:Toggle()
    self.toggled = not self.toggled
    if self.toggled then
        -- self:Clear()
        self:Hide()
        ForceRefreshWidgets(self, true)
    else
        self:Show()
    end

    return self.toggled
end

-------------------------------
-- [[ Post Constructor ]]
-------------------------------

PEARL.AddClassPostConstruct("widgets/redux/chatqueue", function(self)
    PEARL.AddClassFunctionPostCall("chat_listener", function(chat_message)
        PEARL.debug(chat_message, chat_message.type)
        -- Display command responses
        if chat_message.type == ChatTypes.CommandResponse then
            ForceRefreshWidgets(self, true)
        end
    end, self)
end)
