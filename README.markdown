LEM LRPC /(LEM| local) RPC/
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

	* __run_rpc_server(socket_path)__

		listen on one unix socket, and start serving request.

* __client(socket_path)__

	Connect to an lem-rpc server binded on __socket_path__ and return a
	client connection with the following  property:

	* __call(function)__

		send the function, call it remotly, then wait for a result.

	* __cast(function)__

		send the function, call it remotly, then return without *any result*


Examples
-------

*client ( lrpc-client.lua )*

		local lrpc = require 'lem.lrpc'
		local utils = require 'lem.utils'
		
		
		local rpcc = lrpc.client('socket')
		local rpcc2 = lrpc.client('socket')
		
		for i=0,1000 do
		
		  utils.spawn(function ()
		    rpcc2:cast(function () add(i,i) end)
		  end)
		
		  print(rpcc:call(function () add(i,i) end))
		end


*server ( lrpc-server.lua )*

		local lrpc = require 'lem.lrpc'
		
		lrpc.server.import()
		
		declare_rpc_fun('add', function (a,b)
		  return a+b
		end)
		
		run_rpc_server('socket')

License
-------

  Three clause BSD license


Contact
-------

  Please send bug reports, patches and feature requests to me <ra@apathie.net>.
