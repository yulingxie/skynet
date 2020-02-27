package.path = "./myexamples/main/?.lua;" .. package.path;

local skynet = require("skynet")
local sprotoloader = require("sprotoloader")
local sprotoparser = require("sprotoparser")
local proto = require("proto")

skynet.start(function()
    sprotoloader.save(proto.c2s, 1)
    sprotoloader.save(proto.s2c, 2)
end)