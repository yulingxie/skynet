local skynet = require("skynet")
skynet.start(function()
    skynet.error("Server Start")
    local s = skynet.newservice("lesson9_service")
    skynet.call(s, "lua", "open", "0.0.0.0", 6666)
    skynet.timeout(60*100, function()
        skynet.call(s, "lua", "close")
    end)
end)