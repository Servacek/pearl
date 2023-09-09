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
local MAX_TIMEOUT_RETRY_SECONDS = 30
local URL_HOST_PATTERN          = "%w+://([%w.]+)/?"
local REQUEST_FAILED_HEADER     = "(%s) [%d] Request Failed! Reason: %s"

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
    self.timeout = DEFAULT_REQUEST_TIMEOUT

    --- @type boolean
    self.skipondeadline = true

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
end)

-------------------------------------
-- [[ Static ]]
-------------------------------------

Request.NO_RETRY_CODES = {
    [429] = true,
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

function Request:SetTimeout(timeout)
    if type(timeout) ~= "number" then
        --PEARL.error("Attempted to set an invalid request timeout!")
        return self
    end

    self.timeout = timeout

    return self
end

--- @param code number The status code number.
--- @param handler fun(response: table|string, request: Request, ...)?
--- @return Request self
function Request:SetStatusCodeHandle(code, handler)
    if type(self.rcode_handlers) ~= "table" then
        self.rcode_handlers = {}
    end

    if type(self.rcode_handlers[code]) ~= "table" then
        self.rcode_handlers[code] = {}
    end

    table.insert(self.rcode_handlers[code], handler or function() end)

    return self
end

--- @param errfn fun(response: table|string, code: number, request: Request, ...)
--- @return Request self
function Request:SetErrorHandler(errfn, ...)
    self.errfn = errfn
    self.errfn_args = toarrayornil(...)

    return self
end

function Request:SetIsRaw(raw)
    self.raw = raw or false

    return self
end

function Request:SetMaxRetries(retries)
    self.maxretries = retries

    return self
end

function Request:SetParameters(params)
    if not self:IsProxied() then
        PEARL.error("Attempted to set query string parameters for a non-proxied request!")
    else
        self.proxydata.params = params
    end

    return self
end

function Request:SetHeaders(headers)
        if not self:IsProxied() then
        PEARL.error("Attempted to set headers fo a non-proxied request!")
    else
        self.proxydata.headers = headers
    end

    return self
end

--- @param data string|table?
function Request:SetData(data)
    if data ~= nil and type(data) ~= "string" then
        if type(data) == "table" then
            local success
            success, data = pcall(json.encode_compliant, data)
            if not success or type(data) ~= "string" then
                PEARL.error("Failed to encode the given table to JSON!")
                return self
            end
        else
            PEARL.error("Attempted to set an invalid request data!")
            return self
        end
    end

    if self:IsProxied() then
        PEARL.error("Attempted to send encoded data using a proxy request!")
        return self
    end

    self.data = data

    return self
end

function Request:SetProxyData(proxydata)
    self.proxydata = proxydata

    return self
end

--- @param onsuccessfn fun(response: table|string, self: Request, ...: any)
--- @param ... any
function Request:SetOnSuccess(onsuccessfn, ...)
    self.onsuccessfn = onsuccessfn
    self.onsuccessfn_args = toarrayornil(...)

    return self
end

function Request:SetOnComplete(oncompletefn, ...)
    self.oncompletefn = oncompletefn
    self.oncompletefn_args = {...}

    return self
end

function Request:SetSkipOnDeadline(skipondeadline)
    self.skipondeadline = skipondeadline

    return self
end

function Request:SetMethod(method)
    if type(method) ~= "string" then
        PEARL.error("Attempted to set an invalid request method!")
        return self
    end

    self.method = method

    return self
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function Request:CanSkipOnDeadline()
    return self.skipondeadline
end

function Request:IsProxied()
    return self.proxy
end

function Request:IsRetryable()
    return self.maxretries > self.retries
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

function Request:Send(force)
    if force then
        PEARL.HTTPClient:ForceSend(self)
    else
        PEARL.HTTPClient:HandleRequest(self)
    end

    return self
end

-------------------------------------
-- [[ Handlers ]]
-------------------------------------

--- @param datastr string?
--- @param success boolean?
--- @param code number?
function Request:OnCompleted(datastr, success, code)
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

    -- OnComplete handler gets called no matter if we successeded or not.
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

    if success ~= true or code >= 400 then
        if type(self.errfn) == "function" then
            self.errfn(response, code, self, PEARL.unpack(self.errfn_args))
        end

        local reason
        if code == 0 then
            reason = "Operation timed out!"

            if self:IsRetryable() and Request.NO_RETRY_CODES[code] == nil then
                PEARL.HTTPClient:RetryRequestAfter(
                    self, math.min(math.max(TIMEOUT_RETRY_SECONDS * self.retries, TIMEOUT_RETRY_SECONDS), MAX_TIMEOUT_RETRY_SECONDS)
                )
            end
        else
            reason = (#datastr > 1 and datastr) or "Reason unknown."
        end

        -- Log only failed requests to reduce log spam
        PEARL.error(
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

return Request
