local ChatQueue = require("widgets/redux/chatqueue")

----------------------------------------------

local _PushMessage = ChatQueue.PushMessage
ChatQueue.PushMessage = function(self, ...)
    if self.toggled then
        return
    end

    return _PushMessage(self, ...)
end

local _RefreshWidgets = ChatQueue.RefreshWidgets
ChatQueue.RefreshWidgets = function(self, ...)
    if self.toggled then
        return
    end

    return _RefreshWidgets(self, ...)
end

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
