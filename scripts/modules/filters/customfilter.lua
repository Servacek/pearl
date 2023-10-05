


for priority, filter in pairs(PEARL.CONFIG.CUSTOM_FILTERS) do
    PEARL.ServerNetwork:AddConnectionFilter(function(userid, data)
        filter(userid, data, PEARL)
    end, priority)
end
