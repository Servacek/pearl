--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local math = math

--------------------------------
-- [[ Constants ]]
--------------------------------

local REQUEST_TIMEOUT = 10
local RETRY_SECONDS = 600

local ENDPOINTS = {
    W_MESSAGE = "/messages/%s"
}

local MESSAGE_ACTIONS = {
    POST   = 1,
    DELETE = 2,
    EDIT   = 3,
}

local MESSAGE_ACTION_METHODS = {
    [MESSAGE_ACTIONS.POST]      = PEARL.HTTPClient.METHODS.POST,
    [MESSAGE_ACTIONS.DELETE]    = PEARL.HTTPClient.proxy.METHODS.DELETE,
    [MESSAGE_ACTIONS.EDIT]      = PEARL.HTTPClient.proxy.METHODS.PATCH,
}

--------------------------------
-- [[ Initialization ]]
--------------------------------

--- @class RestAPI - singleton
local RestAPI = {
    _is_disabled = false,

    --- @type Task?
    _rate_limit_task = nil,
}

--------------------------------
-- [[ Static ]]
--------------------------------

RestAPI.STATUS_CODES = {
    OK                  = 200, -- The request completed successfully.
    CREATED             = 201, -- The entity was created successfully.
    NO_CONTENT          = 204, -- The request completed successfully but returned no content.
    NOT_MODIFIED        = 304, -- The entity was not modified (no action was taken).
    BAD_REQUEST         = 400, -- The request was improperly formatted, or the server couldn't understand it.
    UNAUTHORIZED        = 401, -- The Authorization header was missing or invalid.
    FORBIDDEN           = 403, -- The Authorization token you passed did not have permission to the resource.
    NOT_FOUND           = 404, -- The resource at the location specified doesn't exist.
    METHOD_NOT_ALLOWED  = 405, -- The HTTP method used is not valid for the location specified.
    TOO_MANY_REQUESTS   = 429, -- You are being rate limited, see Rate Limits.
    GATEWAY_UNAVAILABLE = 502, -- There was not a gateway available to process your request. Wait a bit and retry.
    --5xx (SERVER ERROR)	The server had an error processing your request (these are rare).
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function _OnErrorStatusCode(response, status_code, request)
    -- Handle rate limits first
    if status_code == RestAPI.STATUS_CODES.TOO_MANY_REQUESTS then
        return RestAPI:RateLimitForTime(
            response and tonumber(response.retry_after or 0) or nil
        )
    end

    if status_code == RestAPI.STATUS_CODES.NOT_FOUND then
        PEARL.error("Invalid endpoint url.")
        return request:SetMaxRetries(0)
    end

    if status_code == RestAPI.STATUS_CODES.GATEWAY_UNAVAILABLE then
        local retry_seconds = RETRY_SECONDS + math.random(RETRY_SECONDS)
        PEARL.error("Gateway Unavailable.")
        PEARL.HTTPClient:RetryRequestAfter(request, retry_seconds)
    end

    if status_code > 500 then
        return PEARL.error("Server failed to proccess the request.")
    end
end

local function _SendActionRequest(url, action, data, force)
    local method = MESSAGE_ACTION_METHODS[action]

    --- @type HTTPClient|HTTPClientProxy
    local client = PEARL.HTTPClient
    if not PEARL.HTTPClient.METHODS[method] then
        -- This method seems to require proxy server to be used.
        client = PEARL.HTTPClient.proxy
    end

    local request = client:Request(
        url, MESSAGE_ACTION_METHODS[action], nil, data, REQUEST_TIMEOUT
    )
    :SetErrorHandler(_OnErrorStatusCode)

    if client ~= PEARL.HTTPClient.proxy then
        request:SetMaxRetries(0)
    end

    return request:Send(force)
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function RestAPI:IsDisabled()
    return self._is_disabled
end

function RestAPI:IsRateLimited()
    return self._rate_limit_task ~= nil and self._rate_limit_task.limit > 0
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function RestAPI:SetIsDisabled(disabled)
    self._is_disabled = disabled
end

--------------------------------
-- [[ Public Functions ]]
--------------------------------

--- @param wurl string The URL of the target webhook.
--- @param message_id string? The snowflake of the target message.
--- @param action MESSAGE_ACTIONS The action to be executed for the given webhook's message.
--- @param message Message The message object representing providing the data for this action.
--- @param force boolean? Whether to skip the queue for the action request or not.
--- @return Request? request The request send for this action.
function RestAPI:DoWebhookMessageAction(wurl, message_id, action, message, force)
    if self:IsDisabled() then
        return
    end

    if type(wurl) ~= "string" then
        PEARL.error("Invalid webhook url provided for message action!")
        return
    end

    if message and not message:IsValid() then
        PEARL.error("Attempted to", action, "an invalid message!")
    end

    local data = message and message:ToTable()
    local endpoint_url = message_id and wurl..ENDPOINTS.W_MESSAGE:format(message_id) or wurl
    return _SendActionRequest(endpoint_url, action, data, force)
end

--- @param wurl string The URL of the target webhook.
--- @param message Message The message to be posted by this webhook
--- @param force boolean? Whether to skip the queue for the action request or not.
--- @return Request? request The request send for this action.
function RestAPI:PostWebhookMessage(wurl, message, force)
    --PEARL.debug("PostWebhookMessage", message)

    return self:DoWebhookMessageAction(
        wurl, nil, MESSAGE_ACTIONS.POST, message, force
    )
end

--- @param wurl string The URL of the target webhook.
--- @param message_id string The snowflake of the target message.
--- @param edited Message The message object representing the edited message.
--- @param force boolean? Whether to skip the queue for the action request or not.
--- @return Request? request The request send for this action.
function RestAPI:EditWebhookMessage(wurl, message_id, edited, force)
    --PEARL.debug("EditWebhookMessage", message_id)

    return self:DoWebhookMessageAction(
        wurl, message_id, MESSAGE_ACTIONS.EDIT, edited, force
    )
end

--- @param wurl string The URL of the target webhook.
--- @param message_id string The snowflake of the target message.
--- @param force boolean? Whether to skip the queue for the action request or not.
--- @return Request? request The request send for this action.
function RestAPI:DeleteWebhookMessage(wurl, message_id, force)
    --PEARL.debug("DeleteWebhookMessage", message_id)

    return self:DoWebhookMessageAction(
        wurl, message_id, MESSAGE_ACTIONS.DELETE, nil, force
    )
end

--------------------------------
-- [[ Rate Limiting ]]
--------------------------------

function RestAPI:RateLimitForTime(seconds)
    --PEARL.debug("RateLimitForTime", seconds)

    self:SetIsDisabled(true)

    if type(seconds) == "number" and seconds >= 0 then
        PEARL.info("Disabling for", seconds, "seconds...")

        -- If the task already exists then increase it's number of seconds.
        if self._rate_limit_task ~= nil and type(self._rate_limit_task.exec_time) == "number" then
            self._rate_limit_task.exec_time = self._rate_limit_task.exec_time + seconds
            return
        end

        self._rate_limit_task = PEARL.WallScheduler:ExecuteInTime(seconds, function()
            PEARL.info("Reanabling...")
            self:SetIsDisabled(false)

            self._rate_limit_task:cancel()
            self._rate_limit_task = nil
        end)
    else
        -- When seconds are nil, keep the webhook disabled (so it's permanent)
        PEARL.info("Disabling...")
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return RestAPI
