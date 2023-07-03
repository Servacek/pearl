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
local URL_HOST_PATTERN          = "%w+://([%w.]+)/?"
local REQUEST_FAILED_HEADER     = "(%s) [%d] Request Failed! Reason: %s"

-------------------------------------
-- [[ Class Declarations ]]
-------------------------------------
--- @class Request
--- url and method params are required.
local Request = Class(function(self, url, method)
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
    self.callbackfn_inst = nil
    --- @type table?
    self.callbackfn_args = nil
    self.skipondeadline = true

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

    self.data = data

    return self
end

function Request:SetCallbackFn(callbackfn, ...)
    self.callbackfn = callbackfn
    self.callbackfn_args = {...}

    return self
end

function Request:SetCallbackFnInst(inst)
    self.callbackfn_inst = inst

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

-------------------------------------
-- [[ Finalizers ]]
-------------------------------------

function Request:Send(force)
    if force then
        return PEARL.HTTPClient:ForceSend(self)
    end

    PEARL.HTTPClient:ProcessRequest(self)
end

-------------------------------------
-- [[ Handlers ]]
-------------------------------------

function Request:OnCompleted(result, is_successful, http_code)
    local success = is_successful and http_code < 400

    -- Call the request's callback, if provided
    if self.callbackfn then
        if self.callbackfn_inst then
            self.callbackfn(
                self.callbackfn_inst, result, success, http_code, self, unpack(self.callbackfn_args)
            )
        else
            self.callbackfn(
                result, success, http_code, self, unpack(self.callbackfn_args)
            )
        end
    end

    --- @TODO: We should retry the request when it fails on timeout - bad connection.
    -- If we have no http_code it's most likely a timeout.
    local reason = (tonumber(http_code or 0) == 0 and "Operation timed out!") or result or "Reason unknown."

    -- Log only failed requests to reduce log spam
    if not success then
        PEARL.info(
            REQUEST_FAILED_HEADER:format(
                self.host or "unknown", http_code, reason
            ), tonumber(http_code or 0) > 0 and self.data
        )
    end
end

return Request
