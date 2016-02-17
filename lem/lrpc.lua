-- LEM LRPC /(LEM| local) RPC/
-- Copyright (c) 2016, Ralph Augé
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
-- 
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-- 
-- 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-- 
-- 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
--

local utils = require 'lem.utils'
local lfs = require 'lem.lfs'
local io = require 'lem.io'

local lrpcs = {}

local g_current_client

function lrpcs.declare_rpc_fun(method_name, method)
	_G[method_name] = function (...)
		local sock = g_current_client
		local r = method(...)
		r = utils.serialize(r)
		if sock then
			sock:write(#r .. '\n')
			sock:write(r)
		end
	end
end

function easy_proto(client)
	local byte_to_read = client:read("*l")

	if byte_to_read == nil then
		return nil, "connection close before receiving a number of byte to read"
	end

	local run, byte_to_read = byte_to_read:match("^([fp])([0-9]+)$")

	if byte_to_read == nil then
		return nil, "proto error call or cast, no byte"
	end

	byte_to_read = tonumber(byte_to_read)

	local payload = client:read(byte_to_read)

	if payload == nil then
		return nil, "no payload received"
	end

	if #payload ~= byte_to_read then
		return nil, "received payload is incomplete"
	end

	if run == 'f' then
		local ok, msg = pcall(function () 
			local f = utils.unserialize(payload)
			g_current_client = client
			f()
		end)
		if ok == false then
			tf = utils.serialize({'err', {'remote_pcall', ok, msg}})
			client:write(#tf..'\n')
			client:write(tf)
		end
	elseif run == 'p' then
		pcall(function () 
			local f = utils.unserialize(payload)
			g_current_client = nil
			f()
		end)
	end

	return "ok"
end

function lrpcs.run_rpc_server(sock_name)
	lfs.remove(sock_name)
	local sock = io.unix.listen(sock_name, 666)
	sock:autospawn(function (client)
		local t = {}
		local ret

		while true do
			local ret, err = easy_proto(client)

			if ret == nil then
				client:close()
				return
			end
		end
	end)
end

function lrpcs.import()
	for k, m in pairs(lrpcs) do
		_G[k] = m
	end
end

local lrpcc = {}

function lrpcc_new(socket)
	local o = {}
	o.sock = io.unix.connect('socket')
	setmetatable(o, {__index=lrpcc})
	return o
end

function lrpcc:cast(fun)
	local sfun = utils.serialize(fun)
	self.sock:write('p' .. #sfun..'\n')
	self.sock:write(sfun)
end

function lrpcc:call(fun)
	local sfun = utils.serialize(fun)
	self.sock:write('f' .. #sfun .. '\n')
	self.sock:write(sfun)
	local l = self.sock:read('*l')
	if l == nil then
		return
	end
	l = tonumber(l)
	sfun = self.sock:read(l)
	local fun = utils.unserialize(sfun)
	return fun
end

return {server=lrpcs, client=lrpcc_new}
