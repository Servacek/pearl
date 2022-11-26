
local Message = require("libraries/discordapi/models/message")

local PEARL = PEARL
local os, math = os, math

------------------------------------------
-- [[ Private ]]
------------------------------------------

local function on_messagepostconstruct(message, force, wrapper)
    if force then
        return wrapper:Wrap()
    end

    if wrapper and wrapper:GetActiveMessage() == message then
        wrapper:StartWrapTimeout()
    end
end

------------------------------------------
-- [[ Definition ]]
------------------------------------------

--- @class MessageWrapper
local MessageWrapper = Class(function(self)
    self._message = nil
    self._task = nil
    self._period = 0
    self._appending_mode = true

    self._onwrapfn = nil
    self._onwrapfn_args = nil
end)

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function MessageWrapper:HasActiveMessage()
    return self._message ~= nil
end

function MessageWrapper:IsWrapping()
    return self:HasActiveMessage() and self._task ~= nil and self._task.limit and self._task.limit > 0
end

function MessageWrapper:IsDisabled()
    return self._period <= 0
end

function MessageWrapper:IsAppendingModeEnabled()
    return self._appending_mode
end

function MessageWrapper:GetActiveMessage()
    return self._message
end

function MessageWrapper:CreateTimestamp()
    return PEARL.ToISO8601(os.time())
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

function MessageWrapper:SetOnWrapFn(fn, ...)
    if type(fn) == "function" then
        PEARL.debug("Setting the onwrap callback to", fn)
        if self._onwrapfn ~= nil and self._onwrapfn ~= fn then
            PEARL.warn("Overriding _onwrapfn!")
        end

        self._onwrapfn = fn
        self._onwrapfn_args = ...
    end
end

function MessageWrapper:SetPeriod(period)
    self._period = math.max(period or 0, 0)

    if self:IsDisabled() then
        PEARL.warn("MessageWrapper", "Wrapping was disabled!")
    end
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

function MessageWrapper:EnsureActiveMesage()
    if not self._message then
        self._message = Message()
            :SetPostConstructFn(on_messagepostconstruct, self)
    end
end

function MessageWrapper:AppendLogLine(logline)
    if logline then
        -- If the current message does not accept new log lines (means it's full)
        -- force wrap it and create a new one.
        if self._message and not self._message:AcceptsLogLines() then
            self:Wrap()
        end

        self:EnsureActiveMesage()
        self:AppendLogLine(logline)
    end

    return self._message
end

function MessageWrapper:AppendEmbed(embed)
    if embed then
        -- If the current message does not accept new embeds (means it's full)
        -- force wrap it and create a new one.
        if self._message and not self._message:AcceptsEmbeds() then
            self:Wrap()
        end

        self:EnsureActiveMesage()
        self._message:AddEmbed(embed
            :SetTimestamp(os.time())
        )
    end

    return self._message
end

function MessageWrapper:Wrap()
    assert(type(self._onwrapfn) == "function", "MessageWrapper: Invalid onwrapfn!")

    self._onwrapfn(self._message, self._onwrapfn_args)
    self._message = nil
end

function MessageWrapper:StartWrapTimeout()
    if self._message and not self:IsWrapping() then
        PEARL.debug("Wrap timeout has started!")

        self._task = PEARL.Scheduler:ExecuteInTime(
            self._period, self.OnWrapTimeout, nil, self
        )
    end
end

------------------------------------------
-- [[ Handlers ]]
------------------------------------------

function MessageWrapper:OnWrapTimeout()
    if self._task then
        self._task:Cancel()
        self._task = nil
    end

    PEARL.debug("Wrap timeout has ended!")
    self:Wrap()
end

return MessageWrapper
