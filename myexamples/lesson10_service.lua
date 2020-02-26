local skynet = require("skynet")
local mysql = require("skynet.db.mysql")

local db

local function ping()
    while true do
        if(db) then
            db:query("select 1;")
        end
        skynet.sleep(3600*1000)
    end
end

local CMD = {}

function CMD.open(conf)
    db = mysql.connect(conf)
    skynet.fork(ping)
end

function CMD.close()
    if db then
        db.disconect()
        db = nil
    end
end

function CMD.insert(tablename, row)
    local columns = {}
    local values = {}
    for k,v in pairs(row) do
        table.insert( columns,k )
        if(type(v) == "string") then
            v = mysql.quote_sql_str(v)
        end
        table.insert(values, v)
    end
    values = table.concat( values, ", " )
    columns = table.concat(columns, ", ")
    local sql = string.format( "insert into %s(%s) values(%s)",tablename, columns, values)
    local result = db:query(sql)
    if result.errno then
        skynet.error(result.err)
        return false
    end
    return true
end

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