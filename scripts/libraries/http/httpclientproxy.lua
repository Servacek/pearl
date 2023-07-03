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
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function _CreateProxyRequest(callbackfn, ...)
    return Request(HTTPClientProxy._url, PEARL.HTTPClient.METHODS.POST)
        :SetCallbackFn(callbackfn, ...)
        :SetTimeout(PROXY_REQUEST_TIMEOUT)
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function HTTPClientProxy:SetURL(url)
    self._url = url
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
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:Request(url, method, callbackfn, data, timeout, ...)
    return _CreateProxyRequest(callbackfn, ...)
        :SetData({
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
--- @return Request request The newly created request. You need to execute it using :Send.
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
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClientProxy:PATCH(url, callbackfn, data, timeout, ...)
    return self:Request(url, self.METHODS.PATCH, callbackfn, data, timeout, ...)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return HTTPClientProxy
