
local math = math

--------------------------------
-- [[ Constants ]]
--------------------------------

local REQUEST_TIMEOUT = 10
local RETRY_SECONDS = 600
local DISCORD_STATUS_CODES = {
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
-- [[ Private Functions ]]
--------------------------------

local function on_request_completed(self, result, is_successful, status_code, request)
    if not is_successful then
        return self:_OnErrorStatusCode(status_code, result, request)
    end
end

--------------------------------
-- [[ Initialization ]]
--------------------------------

--- @class RestAPI
local RestAPI = Class(function(self)
    self._is_disabled = false

    --- @type Task
    self._rate_limit_task = nil
end)

--------------------------------
-- [[ Private Functions ]]
--------------------------------
--- @TODO: Test
function RestAPI:_OnErrorStatusCode(status_code, result, request)
    -- Handle rate limits first
    if status_code == DISCORD_STATUS_CODES.TOO_MANY_REQUESTS then
        local success, decoded_result = pcall(json.decode, result)
        return self:RateLimitForTime(
            (success and decoded_result) and tonumber(decoded_result.retry_after)
            or nil
        )
    end

    if status_code == DISCORD_STATUS_CODES.NOT_FOUND then
        PEARL.error("RestAPI", "Invalid endpoint url.")
        return self:SetIsDisabled(true)
    end

    if status_code == DISCORD_STATUS_CODES.GATEWAY_UNAVAILABLE then
        local retry_seconds = RETRY_SECONDS + math.random(RETRY_SECONDS)
        PEARL.error("RestAPI", "Gateway Unavailable.")
        PEARL.RestClient:RetryRequestAfter(retry_seconds, request)
    end

    if status_code > 500 then
        return PEARL.error("RestAPI", "Server failed to proccess the request.")
    end
end

--------------------------------
-- [[ Public Functions ]]
--------------------------------

function RestAPI:ExecuteWebhook(webhook, json_data, force)
    -- It would be better to create some kind of a buffer for the pending requests
    -- and send it after rate limiting ends. But since the only way to get rate limited
    -- is by a flaw, this is irelevant.
    if self:IsDisabled() then
        -- Ignore any API calls when disabled
        return
    end

    return PEARL.RestClient:POST(
        webhook.url, on_request_completed, json_data, REQUEST_TIMEOUT, self
    ):Send(force)
end

function RestAPI:RateLimitForTime(seconds)
    self:SetIsDisabled(true)

    if type(seconds) == "number" and seconds >= 0 then
        PEARL.info("RestAPI", "Disabling for", seconds, "seconds...")
        if self._rate_limit_task ~= nil and type(self._rate_limit_task.exec_time) == "number" then
            self._rate_limit_task.exec_time = self._rate_limit_task.exec_time + seconds
            return
        end

        self._rate_limit_task = PEARL.Scheduler:ExecuteInTime(seconds, function()
            PEARL.info("RestAPI", "Reanabling...")
            self:SetIsDisabled(false)

            self._rate_limit_task:Cancel()
            self._rate_limit_task = nil
        end)
    else
        -- When seconds are nil, disable this webhook permanently.
        PEARL.info("RestAPI", "Disabling...")
    end
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function RestAPI:SetIsDisabled(disabled)
    self._is_disabled = disabled
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

return RestAPI
