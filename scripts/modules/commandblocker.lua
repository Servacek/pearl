--- @TODO: Debug

local UserCommands = require("usercommands")

--------------------------------
-- [[ Handlers ]]
--------------------------------

PEARL.AddGamePostInit(function()
    for name, allowed in pairs(PEARL.CONFIG.COMMAND_BLOCKLIST) do
        local command = UserCommands.GetCommandFromName(name)
        if command then
            PEARL.AddClassFunctionPreCall("hasaccessfn", function(command_name, caller)
                if not caller or (not caller.admin and allowed == false) then
                    return false
                end
            end, command)
        end
    end
end)
