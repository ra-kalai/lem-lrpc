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

--  allow uri such as :
--    tcp://localhost:3222
--    unix://aaa.socket to be passed to lrpcc_new or lrpcs.run_rpc_server
--    if no scheme is given, we consider the uri as a path to an unix socket.
function lrpc_parse_uri(uri)
	local default_scheme = 'unix'
	local scheme, extra = uri:match("([a-z]*)://(.*)$")

	if scheme == 'tcp' then
		return scheme, extra
	elseif scheme == 'unix' then
		return scheme, extra
	end

	return default_scheme, uri
end

	local lrpcs = {}

	local g_current_client

	local method_call_stats = {}

	local function lrpcs_sendback_ret(sock, r)
		if sock then
			r = utils.serialize(r)
			sock:write(#r .. '\n')
			sock:write(r)
		end
	end

function lrpcs.declare_rpc_fun(method_name, method)

	method_call_stats[method_name] = 0

	_G[method_name] = function (...)
		method_call_stats[method_name] = method_call_stats[method_name] + 1
		local sock = g_current_client
		local r = method(...)
		lrpcs_sendback_ret(sock, r)
	end
end

local easy_proto_callback_map = {
	f = function (client, payload)
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
	end,
	p = function (client, payload)
		pcall(function ()
			local f = utils.unserialize(payload)
			g_current_client = nil
			f()
		end)
	end,
	np = function (client, payload)
		local attr = utils.unserialize(payload)
		_G[attr[1]](attr[2])
	end,
	nf = function (client, payload)
		g_current_client = client
		local attr = utils.unserialize(payload)
		_G[attr[1]](attr[2])
	end,
	s = function (client, payload)
		lrpcs_sendback_ret(client, method_call_stats)
	end,
}

function easy_proto(client)
	local byte_to_read = client:read("*l")

	if byte_to_read == nil then
		return nil, "connection close before receiving a number of byte to read"
	end

	local run, byte_to_read = byte_to_read:match("^(n?[fpsl])([0-9]+)$")

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

	easy_proto_callback_map[run](client, payload)

	return "ok"
end

function lrpcs.run_rpc_server(uri)
	local sock, err
	local proto, extra = lrpc_parse_uri(uri)

	if proto == 'unix' then
		local attr, err = lfs.symlinkattributes(extra)

		if attr ~= nil then
			if attr.mode ~= 'directory' then
				local ok, err = lfs.remove(extra)
				if not ok then
					return nil, err, 'fs op'
				end
			else
				return nil, err, 'fs op - path exist and is a directory'
			end
		end

		sock, err = io.unix.listen(extra, 666)

		elseif proto == 'tcp' then
			local host, port = extra:match('([^:]*):(.*)')
			sock = io.tcp.listen(host, port)
		end

		if not sock then
			return nil, err, 'listen op'
		end

	return sock:autospawn(function (client)
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

function lrpcc_new(uri)
	local o = {}
	local proto, extra = lrpc_parse_uri(uri)
	if proto == 'unix' then
		o.sock = io.unix.connect(extra)
	elseif proto == 'tcp' then
		local host, port = extra:match('([^:]*):(.*)')
		o.sock = io.tcp.connect(host, port)
	end

	if o.sock == nil then
		return nil, 'could not connect to rpc server check if uri is valid', uri
	end

	setmetatable(o, {__index=lrpcc})

	return o
end

function lrpcc:_remote_cmd(cmd, payload)
	self.sock:write(cmd .. #payload..'\n')
	self.sock:write(payload)
end

function lrpcc:_remote_get_ret()
	local l = self.sock:read('*l')

	if l == nil then
		return nil, 'rpc-server didn t send a "reply length" reply'
	end
	l = tonumber(l)
	if l <= 0 then
		return nil, "rpc-server sent an invalid 'length reply'", l
	end
	local sfun = self.sock:read(l)
	if sfun == nil then
		return nil, 'rpc-server didn t send the "2nd part reply payload"'
	end
	if #sfun < l then
		return nil, 'rpc-server didn t send entirely the "2nd part reply payload"'
	end

	return utils.unserialize(sfun)
end

function lrpcc:cast(fun)
	local sfun = utils.serialize(fun)
	self:_remote_cmd('p', sfun)
end

function lrpcc:ncast(fun_name, arg)
	local np = utils.serialize({fun_name, arg})
	self:_remote_cmd('np', np)
end

function lrpcc:call(fun)
	local sfun = utils.serialize(fun)
	self:_remote_cmd('f', sfun)
	return self:_remote_get_ret()
end

function lrpcc:ncall(fun_name, arg)
	local np = utils.serialize({fun_name, arg})
	self:_remote_cmd('nf', np)
	return self:_remote_get_ret()
end

function lrpcc:stats()
	self:_remote_cmd('s', utils.serialize(nil))
	return self:_remote_get_ret()
end

function lrpcc:quit()
	self.sock:close()
end

return {server=lrpcs, client=lrpcc_new}
