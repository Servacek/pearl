--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    Manages the REST client's request queue so requests are not sent directly.

    Functions:
        - GET(url, callbackfn, timeout, ...)
        - POST(url, callbackfn, encoded_data, timeout, ...)

    - NOTES:
        - Each shard has it's own Requester so they are not synced.
          Therefore it's recommended to, if possible, send all requests
          from Master to prevent exceeding any rate limits.

        - The discord REST API rate limit is 16 requests/second.
--]]

--- @type Request
local Request = PEARL.loadfile("libraries/http/models/request")
local HTTPClientProxy = PEARL.loadfile("libraries/http/httpclientproxy")

local TheSim = TheSim

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class HTTPClient
local HTTPClient = {
    --- This should be public
    --- @type HTTPClientProxy
    proxy = HTTPClientProxy,
}

if HTTPClient.proxy and PEARL.CONFIG.PROXY.ENABLED and type(PEARL.CONFIG.PROXY.URL) == "string" then
    PEARL.info("Setting up the proxy...")

    HTTPClient.proxy:SetEnabled(true)
    HTTPClient.proxy:SetURL(PEARL.CONFIG.PROXY.URL)
end

--------------------------------
-- [[ Static Variables ]]
--------------------------------

-- More can be added later
HTTPClient.METHODS = {
    POST    = "POST",
    GET     = "GET",
}

HTTPClient.DEFAULT_REQUEST_TIMEOUT = 10

--------------------------------
-- [[ Getters ]]
--------------------------------

function HTTPClient:IsProxyEnabled()
    return self.proxy and self.proxy:IsEnabled()
end

--------------------------------
-- [[ Private Methods ]]
--------------------------------

--- @param request Request
function HTTPClient:SendRequest(request)
    PEARL.debug("HTTPClient:SendRequest", request, request.url, request.method)

    if type(request) ~= "table" then
        return PEARL.error("Attempted to send an invalid request!")
    end

    local data = request:GetData()
    if request.method == HTTPClient.METHODS.POST and type(data) ~= "string" then
        return PEARL.error("Attempted to send a POST request with invalid data provided!", request)
    end

    -- Run in a protected call so if an error occures and the request is not actually
    -- being sent, we do not block the requester.
    local success, err = pcall(TheSim.QueryServer, TheSim,
        request.url, function(...)
            request:OnCompleted(...)
        end, request.method, data, request.timeout
    )

    if success then
        request:OnSend()
    else
        PEARL.error("Failed to execute request!", err)
    end

    return success, err
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- @param request Request
--- @param seconds integer
function HTTPClient:RetryRequestAfter(request, seconds)
    if not request:IsRetryable() then
        return PEARL.warn("Max retry count reached! Request failed...")
    end

    request:OnRetry()
    PEARL.info(("Retrying request in %d seconds... (%d/%d)"):format(
        seconds, request.retries, request.maxretries
    ))

    PEARL.WallScheduler:ExecuteInTime(
        seconds, self.SendRequest, nil, self, request
    )
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param method string The method of the request.
--- @param proxy boolean? Whether this
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClient:Request(url, method, proxy)
    return Request(url, method, proxy)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param onsuccess? fun(result: string, success: boolean, http_code: string, ...: any): any The function that should be called after the request completes.
--- @param timeout integer? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClient:GET(url, onsuccess, timeout, ...)
    return self:Request(url, HTTPClient.METHODS.GET)
        :SetOnSuccess(onsuccess, ...)
        :SetTimeout(timeout or HTTPClient.DEFAULT_REQUEST_TIMEOUT)
end

--- @nodiscard
--- @param url string The url of the endpoint we want to send the request to.
--- @param onsuccess? fun(response: table|string, self: Request, ...: any): any The function that should be called after the request completes.
--- @param data string|table The json data body for the request (JSON or table)
--- @param timeout integer? The number of seconds before timeout should occur.
--- @param ... any? Additional parameters for the callback function.
---
--- @return Request request The newly created request. You need to execute it using :Send.
function HTTPClient:POST(url, onsuccess, data, timeout, ...)
    assert(data ~= nil, "Invalid data provided for POST request. Method would be changed to GET implicitly.")

    return self:Request(url, HTTPClient.METHODS.POST)
        :SetOnSuccess(onsuccess, ...)
        :SetTimeout(timeout or HTTPClient.DEFAULT_REQUEST_TIMEOUT)
        :SetData(data)
end

--------------------------------
-- [[ Return ]]
--------------------------------

return HTTPClient
