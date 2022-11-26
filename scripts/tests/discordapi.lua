
local Embed = require("libraries/discordapi/models/embed")
local Message = require("libraries/discordapi/models/message")

----------------------------------------

local tests = {}

function tests.test_all()
    local init_request_count = PEARL.RestClient:GetSentRequestsCount()

    PEARL.info("=============== Message Buffer Test ===============")
    tests.msg_buffer_test()

    PEARL.Scheduler:ExecuteInTime(5, function()
        PEARL.info("=============== Message Embed Test ===============")
        tests.msg_embed_test()
    end)

    PEARL.Scheduler:ExecuteInTime(10, function()
        PEARL.info("=============== Return Value Test ===============")
        tests.ret_val_test()
    end)

    PEARL.Scheduler:ExecuteInTime(15, function()
        PEARL.info("=============== Content Limit Test ===============")
        tests.content_limit_test()
    end)

    PEARL.Scheduler:ExecuteInTime(20, function()
        PEARL.info("=============== Content Limit Test Mutliple ===============")
        tests.content_limit_test_multiple()
    end)

    PEARL.Scheduler:ExecuteInTime(20, function()
        PEARL.info("=============== Rate Limit Test ===============")
        tests.rate_limit_test()
    end)

    PEARL.Scheduler:ExecuteInTime(25, function()
        PEARL.info("=============== END ===============")
        local current_requests_count = PEARL.RestClient:GetSentRequestsCount()
        PEARL.info("Requests Sent:", current_requests_count - init_request_count)
    end)()
end

function tests.msg_buffer_test()
    for i = 1, 10 do
        PEARL.Logger:LogString("Test číslo "..i, "ikonka")
    end
end

function tests.msg_embed_test()
    PEARL.Logger:LogString("Správa", "ikonka")
    for i = 1, Message.EMBED_COUNT_LIMIT do
        PEARL.Logger:LogEmbed(
            Embed():SetDescription("Embed #"..i)
        )
    end
end

function tests.ret_val_test()
    PEARL.Logger:LogString("<@481731484982444052>", "ikonka")
        --:AllowMentionsForType(Message.MENTION_TYPES.USERS)
        :AddEmbed(Embed():SetDescription("The Testing Embed"))
end

function tests.content_limit_test()
    PEARL.Logger:LogString(string.rep("a", Message.CONTENT_LENGHT_LIMIT + 1))
end

function tests.content_limit_test_multiple()
    PEARL.Logger:LogString(string.rep("a", Message.CONTENT_LENGHT_LIMIT / 2))
    PEARL.Logger:LogString(string.rep("a", Message.CONTENT_LENGHT_LIMIT / 2))
end

function tests.rate_limit_test()
    PEARL.DiscordRestAPI:_OnErrorStatusCode(429, [[
        {
            "message": "You are being rate limited.",
            "retry_after": 20,
            "global": false
        }
    ]])

    -- Attempt to send some messages while we are being rate limitted.
    tests.msg_buffer_test()
    tests.msg_embed_test()
end

return tests
