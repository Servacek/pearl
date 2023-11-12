--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Global Localization ]]
-------------------------------------

local PEARL = PEARL
local string = string

local tostring = tostring
local tonumber = tonumber
local type = type

local toarrayornil = toarrayornil

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local DEFAULT_REQUEST_TIMEOUT   = 10
local TIMEOUT_RETRY_SECONDS     = 5
local MAX_TIMEOUT_RETRY_SECONDS = 60
local URL_HOST_PATTERN          = "%w+://([%w.]+)/?"
local REQUEST_FAILED_HEADER     = "(%s) [%d] Request Failed! Reason: %s"

--- The time until the request should be sent.
local REQUEST_SEND_TIMEOUT      = 5

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------

--- @class Request
--- url and method params are required.
local Request = Class(function(self, url, method, proxy)
    assert(type(url) == "string", "Invalid request url supplied!")
    assert(PEARL.HTTPClient.METHODS[method], "Invalid request method supplied!")

    -- Lazy load all the tables!

    --- @type string
    self.url = url
    --- @type string
    self.method = method
    --- @type string?
    self.data = nil
    --- @type number?
    self.timeout = DEFAULT_REQUEST_TIMEOUT
    --- @type number
    self.retry_timeout = TIMEOUT_RETRY_SECONDS

    --- @type boolean
    self.sent = false

    --- @type boolean
    self.completed = false

    --- @type fun(response: table|string, self: Request, ...: any)
    self.onsuccessfn = nil
    --- @type table<number, any>?
    self.onsuccessfn_args = nil

    --- @type fun(response: table|string, success: boolean, code: number, self: Request, ...: any)
    self.oncompletefn = nil
    --- @type table<number, any>?
    self.oncompletefn_args = nil

    --- @type fun(result, http_code, request, ...)?
    self.errfn = nil
    --- @type table<number, any>?
    self.errfn_args = nil

    --- @type table<number, fun(result, request, ...)>?
    self.rcode_handlers = nil

    --- @type number
    self.retries = 0
    --- @type number
    self.maxretries = PEARL.CONSTS.MAX_REQUEST_RETRIES

    --- @type boolean
    self.raw = false

    --- @type boolean
    self.proxy = proxy or false

    --- @type table?
    self.proxydata = self.proxy and {} or nil

    --- Proxy Only
    --- @type table<string, any>?
    self.params = nil
    --- @type table<string, any>?
    self.headers = nil

    --- @type string?
    self.host = string.match(url, URL_HOST_PATTERN)
    if not self.host then
        PEARL.error("Couldn't fetch host from request url.", url)
    end

    PEARL.WallScheduler:ExecuteInTime(REQUEST_SEND_TIMEOUT, function()
        if self:WasSentAny() then
            return
        end

        PEARL.error("Request was created but not sent!")
    end)
end)

-------------------------------------
-- [[ Static ]]
-------------------------------------

--- @TODO: This should be configurable and request specific
Request.RETRY_CODES = {
    [0] = true,
}

-------------------------------------
-- [[ Meta Methods ]]
-------------------------------------

function Request:__tostring()
    return string.format("Request(%s)", tostring(self.host))
end

-------------------------------------
-- [[ Setters ]]
-------------------------------------
-- Note: Always return 'self' in these setters so we can chain them

--- @param field string
--- @param value any?
--- @param tp string?
--- @param optional boolean?
--- @param static boolean?
--- @param proxy boolean?
--- @return Request request
function Request:_SetField(field, value, tp, optional, static, proxy)
    if type(field) ~= "string" then
        PEARL.error("Invalid field provided!", field)
        return self
    end

    if tp ~= nil and type(value) ~= tp and (not optional or value ~= nil) then
        PEARL.error("Attempted to set", field, "to an invalid value!", value)
        return self
    end

    if proxy == true and not self:IsProxied() then
        PEARL.error("Attempted to set", field, "for a non-proxy request!")
        return self
    end

    -- If the request is sent at least once, prohibit all changes.
    if static and self:WasSentAny() then
        PEARL.error("Attempted to set a static field", field, "after the request was already sent!")
        return self
    end

    if not static and self:WasCompletedAny() then
        PEARL.error("Attempted to set a dynamic field", field, "after the request was already completed!")
        return self
    end

    local map = proxy and self.proxydata or self
    map[field] = value

    return self
end

--- @param timeout number?
--- @return Request
function Request:SetTimeout(timeout)
    return self:_SetField("timeout", timeout, "number", true, true)
end

function Request:SetTimeBetweenRetries(time)
    return self:_SetField("retry_timeout", time, "number", false, false)
end

--- @param code number The status code number.
--- @param handler fun(response: table|string, request: Request, ...)?
--- @return Request self
function Request:SetStatusCodeHandle(code, handler)
    if self:WasCompletedAny() then
        PEARL.error("Attempted to set status code handler for an already completed request!")
        return self
    end

    if type(self.rcode_handlers) ~= "table" then
        self.rcode_handlers = {}
    end

    if type(self.rcode_handlers[code]) ~= "table" then
        self.rcode_handlers[code] = {}
    end

    table.insert(self.rcode_handlers[code], handler or function() end)

    return self
end

--- @param errfn? fun(response: table|string, code: number, request: Request, ...)
--- @return Request self
function Request:SetOnError(errfn, ...)
    self:_SetField("errfn", errfn, "function", true, false)
    self:_SetField("errfn_args", toarrayornil(...), "table", true, false)

    return self
end

--- @param raw boolean
--- @return Request
function Request:SetIsRaw(raw)
    return self:_SetField("raw", raw or false, "boolean", false, true)
end

--- @param maxretries number
--- @return Request
function Request:SetMaxRetries(maxretries)
    return self:_SetField("maxretries", maxretries, "number", false, false)
end

--- @proxy
--- @param params table?
--- @return Request
function Request:SetParameters(params)
    return self:_SetField("params", params, "table", true, true, true)
end

--- @proxy
--- @param headers table?
--- @return Request
function Request:SetHeaders(headers)
    return self:_SetField("headers", headers, "table", true, true, true)
end

--- @param data string|table?
--- @return Request
function Request:SetData(data)
    --- @type string?
    local datastr = type(data) == "string" and data or nil

    if data ~= nil and type(data) ~= "string" then
        if type(data) == "table" then
            local success
            success, datastr = pcall(json.encode_compliant, data)
            if not success or type(datastr) ~= "string" then
                PEARL.error("Failed to encode the given table to JSON!")
                return self
            end
        else
            PEARL.error("Attempted to set an invalid request data!")
            return self
        end
    end

    -- Do not allow setting this field for a proxy request.
    if self:IsProxied() then
        PEARL.error("Attempted to send encoded data using a proxy request!")
        return self
    end

    return self:_SetField("data", datastr, "string", true, true)
end

--- @proxy
--- @param proxydata table?
--- @return Request
function Request:SetProxyData(proxydata)
    return self:_SetField("proxydata", proxydata, PEARL.LUATYPES.TABLE, true, true, false)
end

--- @param onsuccessfn? fun(response: table|string, self: Request, ...: any)
--- @param ... any
--- @return Request
function Request:SetOnSuccess(onsuccessfn, ...)
    self:_SetField("onsuccessfn", onsuccessfn, PEARL.LUATYPES.FUNCTION, true, false)
    self:_SetField("onsuccessfn_args", toarrayornil(...), PEARL.LUATYPES.TABLE, true, false)

    return self
end

--- @param oncompletefn? fun(response: table|string, self: Request, ...: any)
--- @param ... any
--- @return Request
function Request:SetOnComplete(oncompletefn, ...)
    self:_SetField("oncompletefn", oncompletefn, PEARL.LUATYPES.FUNCTION, true, false)
    self:_SetField("oncompletefn_args", toarrayornil(...), PEARL.LUATYPES.TABLE, true, false)

    return self
end

--- @param method string
--- @return Request
function Request:SetMethod(method)
    return self:_SetField("method", method, PEARL.LUATYPES.STRING, false, true)
end

function Request:SetIsRetryable(retryable)
    if self:IsRetryable() == retryable then
        return
    end

    self.retries = retryable and 0 or self.maxretries
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function Request:IsProxied()
    return self.proxy == true
end

function Request:WasRetried()
    return self.retries and self.retries > 0
end

function Request:WasSentAny()
    return self:WasRetried() or self.sent == true
end

function Request:WasSent()
    return self.sent == true
end

function Request:WasCompletedAny()
    return self:WasRetried() or self.completed == true
end

function Request:WasCompleted()
    return self:WasSent() and self.completed == true
end

--- If this is true then we can guarantee that the request was
--- sent and completed at least once.
function Request:IsRetryable()
    return self.maxretries and self.retries and self.maxretries > self.retries
end

function Request:GetData()
    if self:IsProxied() then
        local success, datastr = pcall(json.encode_compliant, self.proxydata)
        if not success or type(datastr) ~= "string" then
            return
        end

        return datastr
    end

    return self.data
end

-------------------------------------
-- [[ Finalizers ]]
-------------------------------------

--- @return Request self, boolean success
function Request:Send()
    if self:WasSent() then
        PEARL.error("Attempted to send an already sent request!")
        return self, false
    end

    return self, PEARL.HTTPClient:SendRequest(self) or false
end

-------------------------------------
-- [[ Handlers ]]
-------------------------------------

--- Called when the request gets successfully sent.
function Request:OnSend()
    self.sent = true
end

function Request:OnCantRetry()
    PEARL.info("Received a non-retryable status code.")

    self:SetIsRetryable(false)
end

--- Called before an re-sending attempt after the previous returned an error.
function Request:OnRetry()
    self.retries    = (tonumber(self.retries) or 0) + 1

    self.completed  = false
    self.sent       = false
end

--- @param datastr string?
--- @param success boolean?
--- @param code number?
function Request:OnCompleted(datastr, success, code)
    if self:WasCompleted() then
        PEARL.error("Request already completed!", datastr)
    end

    self.completed = true

    code = tonumber(code or 0)
    datastr = datastr or ""

    --- @type string|table?
    local response = datastr
    if type(datastr) ~= "string" or datastr == "" then
        response = self.raw and "" or {}
    end

    if not self.raw and type(response) ~= "table" then
        local decoded, datatbl = pcall(json.decode, datastr)
        if not decoded then
            PEARL.error("Failed to decode the request's response!", datastr)
        end

        response = type(datatbl) == "table" and datatbl or {}
    end

    -- OnComplete handler gets called no matter if we succeeded or not.
    if type(self.oncompletefn) == "function" then
        self.oncompletefn(response, success, code, self, PEARL.unpack(self.oncompletefn_args))
    end

    -- Handlers For Specific Status Codes
    local handlers = self.rcode_handlers and self.rcode_handlers[code]
    if type(handlers) == "table" and #handlers > 0 then
        for i = 1, #handlers do
            handlers[i](response, self)
        end

        return -- If custom handlers exist, do not call the default callbacks.
    end

    if (success ~= true or code >= 400) and code ~= 200 then
        local retryable_code = Request.RETRY_CODES[code] == true
        if not retryable_code then
            self:OnCantRetry()
        end

        if type(self.errfn) == "function" then
            self.errfn(response, code, self, PEARL.unpack(self.errfn_args))
        end

        local reason
        if retryable_code then
            if code == 0 then
                reason = "Operation timed out!"
            end

            if self:IsRetryable() then
                PEARL.HTTPClient:RetryRequestAfter(
                    self, math.min(math.max(self.retry_timeout * (self.retries + 1), self.retry_timeout), MAX_TIMEOUT_RETRY_SECONDS)
                )
            end
        else
            reason = (#datastr > 1 and datastr) or "Reason unknown."
        end

        -- Log only failed requests to reduce log spam
        PEARL.warn(
            REQUEST_FAILED_HEADER:format(
                self.host or "unknown", code, reason
            ), tonumber(code or 0) > 0 and self.data
        )
    -- Call the request's callback, if provided
    -- Only call the callback if we have successesed!
    elseif type(self.onsuccessfn) == "function" then
        self.onsuccessfn(
            response, self, PEARL.unpack(self.onsuccessfn_args)
        )
    end
end

----------------------------------
-- Return
----------------------------------

return Request
