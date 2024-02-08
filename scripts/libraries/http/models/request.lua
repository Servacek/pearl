--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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
--- @alias _StatusCodeHandle fun(response: table|string, request: Request)

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
    --- @type integer?
    self.timeout = DEFAULT_REQUEST_TIMEOUT

    --- @type integer
    self.retry_timeout = TIMEOUT_RETRY_SECONDS

    --- @type boolean
    self.sent = false

    --- @type boolean
    self.completed = false

    -- --- @type fun(response: table|string, self: Request, ...: any)
    -- self.onsuccessfn = nil
    -- --- @type table<string, any>?
    -- self.onsuccessfn_args = nil

    -- --- @type fun(response: table|string, success: boolean, code: string, self: Request, ...: any)
    -- self.oncompletefn = nil
    -- --- @type table<string, any>?
    -- self.oncompletefn_args = nil

    -- --- @type fun(result, http_code, request, ...)?
    -- self.errfn = nil
    -- --- @type table<string, any>?
    -- self.errfn_args = nil

    --- @type table<string, fun(result, request, ...)>?
    self.rcode_handlers = nil

    --- @type integer
    self.retries = 0
    --- @type integer
    self.maxretries = PEARL.CONSTS.MAX_REQUEST_RETRIES

    --- @type boolean
    self.decode_response = true

    --- @type boolean
    self.proxy = proxy or false

    --- @type table?
    self.proxydata = self.proxy and {} or nil

    --- Proxy Only
    --- @type table<string, any>?
    self.params = nil
    --- @type table<string, any>?
    self.headers = nil

    --- @TODO: Maybe move this to some HTTPResponse class
    self.code = nil
    self.ok = nil

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

--- @see RestAPI.STATUS_CODES
--- @enum RETRY_CODES
Request.RETRY_CODES = {
    [0] = true,
    [100] = true,
    [502] = true,
}

--- @enum GENERIC_CODES
Request.GENERIC_CODES = {
    COMPLETE            = .3,
    SUCCESS             = .2,
    ANY                 = .1,
    ERROR               = -.1,
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

--- @param timeout integer?
--- @return Request
function Request:SetTimeout(timeout)
    if timeout == nil then
        PEARL.warn("Setting timeout to nil is not recommended! It may hang the program.")
    end

    return self:_SetField("timeout", timeout, "number", true, true)
end

--- @param time number
--- @return Request
function Request:SetTimeBetweenRetries(time)
    return self:_SetField("retry_timeout", time, "number", false, false)
end

--- Whether the response should be decoded or not (defaults to true)
--- @param decode boolean
--- @return Request
function Request:SetDecodeResponse(decode)
    return self:_SetField("decode_response", decode or false, "boolean", false, true)
end

--- @param maxretries integer
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

--- @return Request
function Request:SetIsRetryable(retryable)
    if self:IsRetryable() ~= retryable then
        self.retries = retryable and 0 or self.maxretries
    end

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

--- @return boolean
function Request:IsProxied()
    return self.proxy == true
end

--- @return boolean
function Request:WasRetried()
    return self.retries and self.retries > 0
end

--- @return boolean
function Request:WasSentAny()
    return self:WasRetried() or self.sent == true
end

--- @return boolean
function Request:WasSent()
    return self.sent == true
end

--- @return boolean
function Request:WasCompletedAny()
    return self:WasRetried() or self.completed == true
end

--- @return boolean
function Request:WasCompleted()
    return self:WasSent() and self.completed == true
end

--- If this is true then we can guarantee that the request was
--- sent and completed at least once.
--- @return boolean
function Request:IsRetryable()
    return self.maxretries and self.retries and self.maxretries > self.retries
end

--- @return string?
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
-- [[ Public Functions ]]
-------------------------------------

--- @param code integer The status code number.
--- @param fn? _StatusCodeHandle
--- @return Request self
function Request:AddStatusCodeHandle(code, fn)
    if type(fn) ~= "function" then
        --PEARL.error("Attempted to add an invalid handle for status code", code, fn)
        return self
    end

    if self:WasCompletedAny() then
        PEARL.error("Attempted to set status code handler for an already completed request!")
        return self
    end

    self.rcode_handlers = self.rcode_handlers or {}
    self.rcode_handlers[code] = self.rcode_handlers[code] or {}

    table.insert(self.rcode_handlers[code], fn)

    return self
end

--- @param fn? _StatusCodeHandle
--- @return Request
function Request:AddOnComplete(fn)
    -- self:_SetField("oncompletefn", oncompletefn, PEARL.LUATYPES.FUNCTION, true, false)
    -- self:_SetField("oncompletefn_args", toarrayornil(...), PEARL.LUATYPES.TABLE, true, false)

    self:AddStatusCodeHandle(Request.GENERIC_CODES.COMPLETE, fn)

    return self
end

--- @param fn? _StatusCodeHandle
--- @return Request
function Request:AddOnSuccess(fn)
    -- self:_SetField("onsuccessfn", onsuccessfn, PEARL.LUATYPES.FUNCTION, true, false)
    -- self:_SetField("onsuccessfn_args", toarrayornil(...), PEARL.LUATYPES.TABLE, true, false)

    self:AddStatusCodeHandle(Request.GENERIC_CODES.SUCCESS, fn)

    return self
end

--- @param fn? _StatusCodeHandle
--- @return Request self
function Request:AddOnError(fn)
    -- self:_SetField("errfn", errfn, "function", true, false)
    -- self:_SetField("errfn_args", toarrayornil(...), "table", true, false)

    self:AddStatusCodeHandle(Request.GENERIC_CODES.ERROR, fn)

    return self
end

--- @return Request self, boolean success
function Request:Send()
    if self:WasSent() then
        PEARL.error("Attempted to send an already sent request!")
        return self, false
    end

    return self, PEARL.HTTPClient:SendRequest(self) or false
end

-------------------------------------
-- [[ Private ]]
-------------------------------------

--- @param rstr string?
--- @return table
function Request:_DecodeResponse(rstr)
    local decoded, datatbl = pcall(json.decode, rstr)
    if not decoded then
        PEARL.error("Failed to decode the request's response!", string.raw(tostring(rstr)))
    end

    return type(datatbl) == "table" and datatbl or {}
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

    self.code       = nil
    self.ok         = nil
end

function Request:OnStatusCode(code, response)
    local handlers = self.rcode_handlers and self.rcode_handlers[code]
    if table.empty(handlers) == false then
        for i = 1, #handlers do
            handlers[i](response, self)
        end

        return true
    end

    return false
end

function Request:OnSuccess(response)
    self:OnStatusCode(Request.GENERIC_CODES.SUCCESS, response)
end

function Request:OnErrorResponse(code, response, reason)
    local retryable_code = Request.RETRY_CODES[code] == true
    if not retryable_code then
        self:OnCantRetry()
    end

    self:OnStatusCode(Request.GENERIC_CODES.ERROR, response)

    -- Log only failed requests to reduce log spam
    PEARL.warn(REQUEST_FAILED_HEADER:format(self.host or "unknown", code, reason or "Reason unknown"))

    if self:IsRetryable() and retryable_code then
        PEARL.HTTPClient:RetryRequestAfter(
            self, math.min(math.max(self.retry_timeout * (self.retries + 1), self.retry_timeout), MAX_TIMEOUT_RETRY_SECONDS)
        )
    elseif self:WasRetried() then
        PEARL.error("No retrying for this request anymore...")
    end
end

--- @param datastr string?
--- @param success boolean?
--- @param code integer?
function Request:OnCompleted(datastr, success, code)
    --PEARL.debug("Request:OnCompleted",code, datastr)

    if self:WasCompleted() then
        PEARL.error("Request already completed!", datastr)
        return
    end

    self.completed = true
    self.code = tonumber(code) or 0
    self.ok = success == true and self.code < 300 or false

    --- @type string|table
    local response = datastr or ""
    if not response:empty() and self.decode_response == true then
        response = self:_DecodeResponse(datastr)
    end

    self:OnStatusCode(Request.GENERIC_CODES.COMPLETE, response)

    -- Handlers For Specific Status Codes
    if self:OnStatusCode(self.code, response) then
        return -- If custom handlers exist, do not call the default callbacks.
    end

    if success == true then
        return self:OnSuccess(response)
    end

    local reason = (datastr and #datastr > 1) and datastr or "Reason unknown."
    if self.code == 0 then
        reason = "Operation timed out!"
    end

    return self:OnErrorResponse(self.code, response, reason)
end

----------------------------------
-- Return
----------------------------------

return Request
