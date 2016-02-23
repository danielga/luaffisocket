# luaffisocket

A Lua module that makes use of the [FFI library][1] to provide bindings to [sockets][2], in a [luasocket][3] compatible interface.

# Info

This module was made to take advantage of LuaJIT's FFI library but as long as you have a compatible FFI library for your regular Lua application, it should work.
It contains code from [luasocket][3], with the MIT license. This code extends the sockets themselves to provide HTTP, FTP and other capabilities.


  [1]: http://luajit.org/ext_ffi.html
  [2]: http://man7.org/linux/man-pages/man2/socket.2.html
  [3]: http://w3.impa.br/~diego/software/luasocket
