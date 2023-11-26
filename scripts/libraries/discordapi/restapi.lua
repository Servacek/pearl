--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Library = require("models/library")
local Message = require("libraries/discordapi/models/message")

local math = math

--------------------------------
-- [[ Constants ]]
--------------------------------

local REQUEST_TIMEOUT = 10
local RETRY_SECONDS = 600

local ENDPOINTS = {
    W_MESSAGE = "/messages/%s"
}

local WEBHOOK_ACTIONS = {
    POST   = 1,
    DELETE = 2,
    EDIT   = 3,

    GET    = 4,
}

local WEBHOOK_ACTION_METHODS = {
    [WEBHOOK_ACTIONS.POST]      = PEARL.HTTPClient.METHODS.POST,
    [WEBHOOK_ACTIONS.DELETE]    = PEARL.HTTPClient.proxy.METHODS.DELETE,
    [WEBHOOK_ACTIONS.EDIT]      = PEARL.HTTPClient.proxy.METHODS.PATCH,

    [WEBHOOK_ACTIONS.GET]      = PEARL.HTTPClient.METHODS.GET,
}

--------------------------------
-- [[ Initialization ]]
--------------------------------

--- @singleton
--- @class RestAPI: Library
local RestAPI = {
    --- @type Task?
    _rate_limit_task = nil,
}

--- @type RestAPI
RestAPI = Library(RestAPI)

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
        -- WallScheduler doesn't support floats with the current precision.
        return RestAPI:RateLimitForTime(
            response and math.ceil(tonumber(response.retry_after or 1) or 1) or nil
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

        return
    end

    if status_code > 500 then
        PEARL.error("Server failed to proccess the request.")
        return
    end
end

--- @return Request? request
local function _SendActionRequest(url, action, data)
    if RestAPI:IsDisabled() then
        return
    end

    local request
    local method = WEBHOOK_ACTION_METHODS[action]
    if not PEARL.HTTPClient.METHODS[method] then
        -- This method seems to require proxy server to be used.
        if not PEARL.HTTPClient.proxy or PEARL.HTTPClient.proxy:IsDisabled() then
            PEARL.error("Attempted to execute an action which requires the HTTP proxy to be enabled!")
            return
        end

        request = PEARL.HTTPClient.proxy:Request(url, method, nil, data, REQUEST_TIMEOUT)
            :SetMaxRetries(0)
    else
        request = PEARL.HTTPClient:Request(url, method)
            :SetData(data)
            :SetTimeout(REQUEST_TIMEOUT)
    end

    request:SetOnError(_OnErrorStatusCode)

    return (request:Send())
end

--------------------------------
-- [[ Getters ]]
--------------------------------

function RestAPI:IsRateLimited()
    return self._rate_limit_task ~= nil and self._rate_limit_task.limit > 0
end

--------------------------------
-- [[ Public Functions ]]
--------------------------------

--- @param wurl string The URL of the target webhook.
--- @param action integer The action to be executed for the given webhook's message.
--- @return Request? request
function RestAPI:DoWebhookAction(wurl, action)
    if self:IsDisabled() then
        PEARL.error("Attempted to execute a webhook action but the Rest API is disabled!")
        return
    end

    return _SendActionRequest(wurl, action, nil)
end

--- @param wurl string The URL of the target webhook.
--- @param message_id string? The snowflake of the target message.
--- @param action integer The action to be executed for the given webhook's message.
--- @param message Message? The message object representing providing the data for this action.
--- @return Request? request
function RestAPI:DoWebhookMessageAction(wurl, message_id, action, message)
    if self:IsDisabled() then
        PEARL.error("Attempted to execute a webhook message action but the Rest API is disabled!")
        return
    end

    if type(wurl) ~= "string" then
        PEARL.error("Invalid webhook url provided for message action!")
        return
    end

    if message and Message.is_instance(message) and message:IsValid() then
        PEARL.error("Attempted to", WEBHOOK_ACTION_METHODS[action], "an invalid message!")
        return
    end

    local data = message and message:ToTable()
    local endpoint_url = message_id and wurl..ENDPOINTS.W_MESSAGE:format(message_id) or wurl
    return _SendActionRequest(endpoint_url, action, data)
end

--- @param wurl string The URL of the target webhook.
--- @param message Message The message to be posted by this webhook
--- @return Request? request
function RestAPI:PostWebhookMessage(wurl, message)
    PEARL.debug("PostWebhookMessage", message)

    return self:DoWebhookMessageAction(
        wurl, nil, WEBHOOK_ACTIONS.POST, message
    )
end

--- @param wurl string The URL of the target webhook.
--- @param message_id string The snowflake of the target message.
--- @param edited Message The message object representing the edited message.
--- @return Request? request
function RestAPI:EditWebhookMessage(wurl, message_id, edited)
    --PEARL.debug("EditWebhookMessage", message_id)

    return self:DoWebhookMessageAction(
        wurl, message_id, WEBHOOK_ACTIONS.EDIT, edited
    )
end

--- @param wurl string The URL of the target webhook.
--- @param message_id string The snowflake of the target message.
--- @return Request? request The request send for this action.
function RestAPI:DeleteWebhookMessage(wurl, message_id)
    --PEARL.debug("DeleteWebhookMessage", message_id)

    return self:DoWebhookMessageAction(
        wurl, message_id, WEBHOOK_ACTIONS.DELETE, nil
    )
end

--- @param wurl string The URL of the target webhook.
--- @return Request? request The request send for this action.
function RestAPI:FetchWebhookData(wurl)
    --PEARL.debug("FetchWebhookData", message_id)

    return self:DoWebhookAction(wurl, WEBHOOK_ACTIONS.GET)
end

--------------------------------
-- [[ Rate Limiting ]]
--------------------------------

function RestAPI:RateLimitForTime(seconds)
    PEARL.debug("RateLimitForTime", seconds)

    self:SetIsEnabled(false)

    if type(seconds) == "number" and seconds >= 0 then
        PEARL.info("Disabling for", seconds, "seconds...")

        -- If the task already exists then increase it's number of seconds.
        if self._rate_limit_task ~= nil and type(self._rate_limit_task.exec_time) == "number" then
            self._rate_limit_task:setexttime(self._rate_limit_task._ext + seconds)
            return
        end

        self._rate_limit_task = PEARL.WallScheduler:ExecuteInTime(seconds, function()
            PEARL.info("Reanabling...")
            self:SetIsEnabled(true)

            if self._rate_limit_task then
                self._rate_limit_task:cancel()
                self._rate_limit_task = nil
            end
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
