LEM LRPC /(LEM| Lua) RPC/
=====================================
 
Summary
-------

Call Lua function in another Lua process.

Usage
-----

Import the module using something like

		local lrpc = require 'lem.lrpc'

This set the *lrpc* variable to a table with 2 exported property:

* __server__

	* __import()__

			This function import functions below in _G; your global environement

	* __declare_rpc_fun()__

		This function allow you to easily declare rpc function,
		able to return something	.

		usage:

				declare_rpc_fun('add', function (a,b)
					return a+b
				end)

	* __run_rpc_server(uri-or-socket-path)__

		listen on a socket, and start serving request.

		uri-or-socket-path, can be

			bla.socket
			unix:///var/bla.socket
			tcp://localhost:2222/

* __client(uri-or-socket-path)__

	Connect to an lem-rpc server binded on __uri-or-socket-path__ and return a
	client connection with the following  property:

	* __ncall(function_name, arg)__

		call function with the name function_name, with arg and wait for a result.

	* __call(function)__

		send the function, call it remotly, then wait for a result.

	* __cast(function)__

		send the function, call it remotly, then return without *any result*

	* __ncast(function_name, arg)__

		call procedure with the name function_name, with arg then return without *any result*

	* __stats()__

		return a list of all declared function and their current call count

	* __quit()__

		close socket



Examples
-------

*client ( lrpc-client.lua )*

		local lrpc = require 'lem.lrpc'
		local utils = require 'lem.utils'
		
		
		local rpcc = lrpc.client('socket')
		local rpcc2 = lrpc.client('socket')
		
		local err = 'could not connect to rpc server'
		assert(rpcc, err)
		assert(rpcc2, err)
		
		for i=1,1000 do
		
		  utils.spawn(function ()
		    rpcc2:cast(function () add(i,i) end)
		  end)
		
		  print(rpcc:call(function () add(i,i) end))
		  print(rpcc:ncall('addt', {i,i}))
		end
		
		for i,v in pairs(rpcc:stats()) do
		  print(i,v)
		end
		
		--
		-- should output:
		--
		-- add	2000
		-- addt	1000


*server ( lrpc-server.lua )*

		local lrpc = require 'lem.lrpc'
		
		lrpc.server.import()
		
		declare_rpc_fun('add', function (a,b)
		  return a+b
		end)
		
		declare_rpc_fun('addt', function (t)
		  return t[1] + t[2]
		end)
		
		run_rpc_server('socket')

License
-------

  Three clause BSD license


Contact
-------

  Please send bug reports, patches and feature requests to me <ra@apathie.net>.
