local skynet = require("skynet")

local function  print_t(s)
    local str = "{"
    for k, v in pairs(t) do
        if type(v) == "table" then
            v = print_v(v)
        end
        str = str .. k .. "=" .. v .. ","
    end
    str = str .. "}"
    return str
end

skynet.start(function()
    skynet.error("Server Start")
    local db = skynet.newservice("lesson11_db")
    skynet.call(db, "lua", "open", {
        host = "127.0.0.1",
        port = "3306",
        database = "test",
        user = "root",
        password = "zwf1004713"
    })

    local gate = skynet.newservice("lesson11_gate")
    skynet.call(gate, "lua", "open", "127.0.0.1", 6666)
end)

