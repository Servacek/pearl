
-----------------------------------
-- Hide Chat
-----------------------------------

local ChatQueue

TheInput:AddKeyDownHandler(PEARL.CONTROLS.TOGGLE_CHAT, function()
    if ChatQueue then
        ChatQueue:Toggle()
    end
end)

AddClassPostConstruct("widgets/redux/chatqueue", function(self)
    ChatQueue = self
end)

-----------------------------------
