

local ChatQueue = require("widgets/redux/chatqueue")

-------------------------------
-- [[ Function Overrides ]]
-------------------------------

PEARL.AddClassFunctionPreCall("PushMessage", function(self)
    return not self.toggled
end, ChatQueue)


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
        for i, _ in ipairs(self.widget_rows) do
            self.widget_rows[i]:SetChatData(ChatTypes.Message, 0)
        end
    end
end

function ChatQueue:Toggle()
    if not self.toggled then
        self.toggled = true
        self:Clear()
        self:Hide()
    else
        self.toggled = false
        self:RefreshWidgets()
    end

    return self.toggled
end
