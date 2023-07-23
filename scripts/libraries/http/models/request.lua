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
local Class = Class
local string = string
local unpack = unpack
local tonumber = tonumber

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local DEFAULT_REQUEST_TIMEOUT   = 10
local TIMEOUT_RETRY_SECONDS     = 5
local MAX_TIMEOUT_RETRY_SECONDS = 30
local URL_HOST_PATTERN          = "%w+://([%w.]+)/?"
local REQUEST_FAILED_HEADER     = "(%s) [%d] Request Failed! Reason: %s"

--- @TODO: Implement specific error code handling.
-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------
--- @class Request
--- url and method params are required.
local Request = Class(function(self, url, method, proxy)
    assert(type(url) == "string", "Invalid request url supplied!")
    assert(PEARL.HTTPClient.METHODS[method], "Invalid request method supplied!")

    --- @type string
    self.url = url
    --- @type function?
    self.callbackfn = nil
    self.method = method
    --- @type string?
    self.data = nil
    self.timeout = DEFAULT_REQUEST_TIMEOUT
    --- Note: always a table if callback function is set.
    --- @type table?
    self.callbackfn_args = nil
    self.skipondeadline = true

    --- @type fun(result, http_code, request, ...)
    self.errfn = nil
    --- @type table<number, fun(result, request, ...)>
    self.rcode_handlers = {}

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
    --- @type table<string, any>
    self.params = nil
    --- @type table<string, any>
    self.headers = nil

    --- @type string?
    self.host = string.match(url, URL_HOST_PATTERN)
    if not self.host then
        PEARL.error("Couldn't fetch host from request url.")
    end
end)

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
    if tonumber(timeout) ~= "number" then
        --PEARL.error("Attempted to set an invalid request timeout!")
        return self
    end

    self.timeout = tonumber(timeout)

    return self
end

function Request:SetStatusCodeHandle(code, handler)
    if type(self.rcode_handlers[code]) ~= "table" then
        self.rcode_handlers[code] = {}
    end

    table.insert(self.rcode_handlers[code], handler)

    return self
end

function Request:SetErrorHandler(errfn)
    self.errfn = errfn

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

function Request:SetData(data)
    if type(data) ~= "string" then
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

function Request:SetCallbackFn(callbackfn, ...)
    self.callbackfn = callbackfn
    self.callbackfn_args = {...}

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

function Request:OnCompleted(response, is_successful, http_code)
    http_code = tonumber(http_code or 0)

    local raw_response = tostring(response or "")
    if #raw_response <= 1 then
        response = nil
    end

    if not self.raw and response then
        local decoded
        decoded, response = pcall(json.decode, raw_response)
        if not decoded or type(response) ~= "table" then
            PEARL.error("Failed to decode the request's response!", response, raw_response)
        end
    end

    if (is_successful and http_code < 400) == false then
        local reason
        if http_code == 0 then
            reason = "Operation timed out!"

            local retry_time = math.min(math.max(TIMEOUT_RETRY_SECONDS * self.retries, TIMEOUT_RETRY_SECONDS), MAX_TIMEOUT_RETRY_SECONDS)
            if self:IsRetryable() then
                PEARL.HTTPClient:RetryRequestAfter(self, retry_time)
            end
        else
            reason = (#raw_response > 1 and raw_response) or "Reason unknown."
        end

        -- Log only failed requests to reduce log spam
        PEARL.info(
            REQUEST_FAILED_HEADER:format(
                self.host or "unknown", http_code, reason
            ), tonumber(http_code or 0) > 0 and self.data
        )

        if type(self.errfn) == "function" then
            self.errfn(response, http_code, self, unpack(self.callbackfn_args))
        end

    -- Call the request's callback, if provided
    -- Only call the callback if we have successesed!
    elseif type(self.callbackfn) == "function" then
        self.callbackfn(
            response, self, unpack(self.callbackfn_args)
        )
    end

    -- Status Code Handlers
    local handlers = self.rcode_handlers[http_code]
    if type(handlers) == "table" and not table.empty(handlers) then
        for _, handle in ipairs(handlers) do
            handle(response, self, unpack(self.callbackfn_args))
        end
    end
end

return Request
