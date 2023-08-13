--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--- @TODOS: Add support for non-waiting requests (these will return 201)


--- @type Request
local Request = PEARL.loadfile("libraries/http/models/request")

--------------------------------
-- [[ Constants ]]
--------------------------------

local PROXY_REQUEST_TIMEOUT = 10
local MAX_TIMEOUTS_IN_ROW   = 3

--------------------------------
-- [[ Local ]]
--------------------------------

local _timeouts_in_row = 0
local _reported = false

local function _OnProxyRequestTimeout()
    if not _reported then
        _timeouts_in_row = _timeouts_in_row + 1

        if _timeouts_in_row >= MAX_TIMEOUTS_IN_ROW then
            PEARL.DiscordReporter:SendRawReportString("Proxy seems to be down!")
            _reported = true
        end
    end
end

--------------------------------
-- [[ Class Init ]]
--------------------------------

--- @class HTTPClientProxy
local HTTPClientProxy = {
    _url = nil,
    _enabled = false
}

--------------------------------
-- [[ Static Variables ]]
--------------------------------

-- More can be added later
HTTPClientProxy.METHODS = {
    PATCH   = "PATCH",
    DELETE  = "DELETE",
    POST    = "POST",
    GET     = "GET",
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function _CreateProxyRequest(callbackfn, ...)
    return Request(HTTPClientProxy._url, PEARL.HTTPClient.METHODS.POST, true)
        :SetStatusCodeHandle(0, _OnProxyRequestTimeout)
        :SetTimeout(PROXY_REQUEST_TIMEOUT)
        :SetCallbackFn(function(response, request, ...)
            if type(callbackfn) == "function" then
                callbackfn(response, request, ...)
            end

            _timeouts_in_row = 0
        end, ...)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function HTTPClientProxy:SetURL(url)
    self._url = url
end

function HTTPClientProxy:IsEnabled()
    return self._enabled
end

function HTTPClientProxy:SetEnabled(enabled)
    self._enabled = enabled
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param method string The method of the request.
--- @param callbackfn? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param data table The data table body for the request.
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request? request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:Request(url, method, callbackfn, data, timeout, ...)
    if not self:IsEnabled() then
        return
    end

    return _CreateProxyRequest(callbackfn, ...)
        :SetProxyData({ -- Data for the proxied request
            url = url,
            timeout = timeout,
            method = method,
            json = data,
        })
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param callbackfn? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request? request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:DELETE(url, callbackfn, timeout, ...)
    return self:Request(url, self.METHODS.DELETE, callbackfn, nil, timeout, ...)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param callbackfn? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param data table The data table body for the request.
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request? request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:PATCH(url, callbackfn, data, timeout, ...)
    return self:Request(url, self.METHODS.PATCH, callbackfn, data, timeout, ...)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param callbackfn? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request? request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:GET(url, callbackfn, timeout, ...)
    return self:Request(url, self.METHODS.GET, callbackfn, nil, timeout, ...)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param callbackfn? fun(result: string, success: boolean, http_code: number, ...: any): any The function that should be called after the request completes.
--- @param data table The data table body for the request.
--- @param timeout number? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request? request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:POST(url, callbackfn, data, timeout, ...)
    return self:Request(url, self.METHODS.POST, callbackfn, data, timeout, ...)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return HTTPClientProxy
