local skynet = require("skynet")
local socketdriver = require("skynet.socketdriver")
local netpack = require("skynet.netpack")

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

local MSG = {}

function MSG.data(fd, msg, sz)
    local str = netpack.tostring(msg, sz)
    print("收到数据：" .. str)
    if str == "exit" then
        socketdriver.close(fd)
    else
        socketdriver.send(fd, string.pack(">s2", str))
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