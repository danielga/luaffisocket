local ffi = require("ffi")

local platform

if ffi.os == "Windows" then
	platform = require("socket.platform.windows")
elseif ffi.os == "Linux" or ffi.os == "OSX" then
	platform = require("socket.platform.posix")
else
	error("unsupported architecture")
end

if ffi.arch == "x86" then
	ffi.cdef("typedef unsigned int size_t;")
elseif ffi.arch == "x64" then
	ffi.cdef("typedef unsigned long long size_t;")
else
	error("unsupported architecture")
end

return platform
