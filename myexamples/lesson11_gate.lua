local skynet = require("skynet")
local socketdriver = require("skynet.socketdriver")
local netpack = require("skynet.netpack")
local cjson = require("cjson")

local queue
local socket

local CMD = {}

function CMD.open(host, port)
    print("开始监听", host, port)
    local socket = socketdriver.listen(host, port)
    socketdriver.start(socket)
end

function CMD.close()
    if(socket) then
        print("监听结束", host, port)
        socketdriver.close(socket)
        socket = nil
    end
end

local function send_to(fd, data)
    local str = cjson.encode(data)
    socketdriver.send(fd, string.pack(">s2", str))
end

local MSG = {}

function MSG.data(fd, msg, sz)
    local str = netpack.tostring(msg, sz)
    print("收到数据：" .. str)

    local data = cjson.decode(str)
    if data.cmd == "register" then
        if type(data.account) ~= "string" or #data.account == 0 or #data.account > 16 then
            send_to(fd, {err = "invalid account"})
            return
        end

        if type(data.password) ~= "string" or #data.password < 6 or #data.password > 16 then
            send_to(fd, {err = "invalid password"})
            return
        end

        if type(data.name) ~= "string" or #data.name < 1 or #data.name > 16 then
            send_to(fd, {err = "invalid name"})
            return
        end


        if type(data.age) ~= "number" or data.age < 10 or data.age > 100 then
            send_to(fd, {err = "invalid age"})
            return
        end

        local sussess, users = skynet.call("db", "lua", "select_by_key", "user", "account", data.account)
        if not sussess then
            send_to(fd, {err = "db error"})
            return 
        end
        if #users > 0 then
            send_to(fd, {err = "user exist"})
            return
        end

        sussess, users = skynet.call("db", "lua", "select_by_key", "user", "name", data.name)
        if not sussess then
            send_to(fd, {err = "db error"})
            return 
        end
        if #users > 0 then
            send_to(fd, {err = "name exist"})
            return
        end

        sussess = skynet.call("db", "lua", "insert", "user", {
            account = data.account,
            password = data.password,
            age = data.age,
            name = data.name
        })
        if not sussess then
            send_to(fd, {err = "db error"})
            return
        end
        print("register success!")
        send_to(fd, {account = data.account, token = data.account .. "temp"})
    elseif data.cmd == "login" then
        if type(data.account) ~= "string" or #data.account == 0 or #data.account > 16 then
            send_to(fd, {err = "invalid account"})
            return
        end

        if type(data.password) ~= "string" or #data.password < 6 or #data.password > 16 then
            send_to(fd, {err = "invalid password"})
            return
        end

        local sussess, users = skynet.call("db", "lua", "select_by_key", "user", "account", data.account)
        if not sussess then
            send_to(fd, {err = "db error"})
            return 
        end
        if #users == 0 then
            send_to(fd, {err = "user not exist"})
            return
        end
        local user = users[1]
        if user.password ~= data.password then
            send_to(fd, {err = "invaild password"})
            return
        end

        print("login success!")
        send_to(fd, {account = data.account, token = data.account .. "temp"})
    end

end

function MSG.more()
    local fd, msg, sz = netpack.pop(queue)
    if fd then
        skynet.fork(dispatch_queue)
        MSG.data(fd, msg, sz)
        for fd, msg, sz in netpack.pop, queue do
            MSG.data(fd, msg, sz)
        end
    end
end

function MSG.open(fd, addr)
    print("接收到新连接id是:", fd, "addr: ", addr)
    socketdriver.start(fd)
end

function MSG.close(fd)
    if fd ~= socket then
        print("连接关闭fd=", fd)
    else
        print("监听套接字关闭")
        socket = nil
    end
end

function MSG.error(fd, msg)
    if fd == socket then
        socketdriver.close(fd)
    else
        print("套接字出错：", fd, msg)
    end
end

function MSG.warning(fd, size)
end

skynet.register_protocol{
    name = "socket",
    id = skynet.PTYPE_SOCKET,
    unpack = function(msg, sz)
        return netpack.filter(queue, msg, sz)
    end,
    dispatch = function(_, _, q, type, ...)
        queue = q
        if type then
            MSG[type](...)
        end
    end
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd];
        assert(f, "can't find cmd " .. (cmd or nil))
        if(session == 0) then
            f(...)
        else
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)