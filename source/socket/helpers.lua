local helpers = {}

local ffi = require("ffi")
local platform = require("socket.platform")
local library = platform.library

helpers.inet_addrstrlen = 16
helpers.inet6_addrstrlen = 46
helpers.portstrlen = 6

helpers.address_any = 0

function helpers.newproxy(internal)
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)

	local function close(self)
		if internal ~= nil then
			library.close(internal)
			internal = nil
		end
	end

	meta.__gc = close

	function meta:__call(reset)
		if reset == true then
			return close()
		elseif reset ~= nil then
			internal = reset
		end

		return internal
	end

	return proxy
end

function helpers.typecheck(val, reqtype, narg, errlevel)
	local valtype = type(val)
	if valtype ~= reqtype then
		local name = "unknown"
		local dbg = debug.getinfo(errlevel or 2)
		if dbg ~= nil and dbg.name ~= nil and #dbg.name ~= 0 then
			name = dbg.name
		end

		error("bad argument #" .. narg .. " to '" .. name .. "' (" .. reqtype .. " expected, got " .. valtype .. ")", errlevel and errlevel + 1 or 3)
	end
end

function helpers.typeoptcheck(val, reqtype, narg, errlevel)
	local valtype = type(val)
	if val ~= nil and valtype ~= reqtype then
		local name = "unknown"
		local dbg = debug.getinfo(errlevel or 2)
		if dbg ~= nil and dbg.name ~= nil and #dbg.name ~= 0 then
			name = dbg.name
		end

		error("bad argument #" .. narg .. " to '" .. name .. "' (" .. reqtype .. " expected, got " .. valtype .. ")", errlevel and errlevel + 1 or 3)
	end
end

function helpers.optioncheck(optname, table, narg, errlevel)
	local option = table[optname]
	if option == nil then
		local name = "unknown"
		local dbg = debug.getinfo(errlevel or 2)
		if dbg ~= nil and dbg.name ~= nil and #dbg.name ~= 0 then
			name = dbg.name
		end

		error("bad argument #" .. narg .. " to '" .. name .. "' (invalid option '" .. optname .. "')", errlevel and errlevel + 1 or 3)
	end

	return option
end

function helpers.validate(internal, errlevel)
	if internal == nil or internal == platform.invalid_socket then
		error("invalid socket", errlevel and errlevel + 1 or 3)
	end

	return internal
end

function helpers.socketcheck(self, state, errlevel)
	if self.state ~= state then
		error(state .. " expected", errlevel and errlevel + 1 or 3)
	end

	return self
end

function helpers.getoption(internal, level, name, value)
	local options_size = ffi.new("socklen_t[1]")
	options_size[0] = ffi.sizeof(value)
	if library.getsockopt(internal, level, name, value, options_size) == -1 then
		return nil, "getsockopt failed"
	end

	return value
end

function helpers.getoption_bool(internal, level, name)
	local options_value = ffi.new("int[1]")
	local value, err = helpers.getoption(internal, level, name, options_value)
	if value == nil then
		return nil, err
	end

	return value[0] == 1
end

function helpers.getoption_int(internal, level, name)
	local options_value = ffi.new("int[1]")
	local value, err = helpers.getoption(internal, level, name, options_value)
	if value == nil then
		return nil, err
	end

	return value[0]
end

function helpers.setoption(internal, level, name, value)
	if library.setsockopt(internal, level, name, ffi.cast("const char *", value), ffi.sizeof(value)) == -1 then
		return nil, "setsockopt failed"
	end

	return 1
end

function helpers.setoption_bool(internal, level, name, value)
	helpers.typecheck(value, "boolean", 3, 3)
	local options_value = ffi.new("int[1]")
	options_value[0] = value and 1 or 0
	return helpers.setoption(internal, level, name, options_value)
end

function helpers.setoption_int(internal, level, name, value)
	helpers.typecheck(value, "number", 3, 3)
	local options_value = ffi.new("int[1]")
	options_value[0] = value
	return helpers.setoption(internal, level, name, options_value)
end

function helpers.bind(self, address, port, socktype, errlevel)
	local fd = helpers.validate(self.fd())
	helpers.typecheck(address, "string", 2, errlevel and errlevel + 1 or 3)
	helpers.typeoptcheck(port, "number", 3, errlevel and errlevel + 1 or 3)

	address = address == "*" and nil or address
	port = port == nil and "0" or tostring(port)

	local addrinfo_instance = ffi.new("struct addrinfo")
	addrinfo_instance.ai_socktype = socktype
	addrinfo_instance.ai_family = self.family
	addrinfo_instance.ai_flags = enums.AI_PASSIVE

	local addrinfo_list = ffi.new("struct addrinfo *[1]")

	local res = library.getaddrinfo(address, port, addrinfo_instance, addrinfo_list)
	if res ~= 0 then
		library.freeaddrinfo(addrinfo_list[0])
		return nil, platform.gaistrerror(res)
	end

	res = library.bind(fd, addrinfo_list[0].ai_addr, addrinfo_list[0].ai_addrlen)
	library.freeaddrinfo(addrinfo_list[0])
	if res == -1 then
		return nil, platform.strerror(platform.lasterror())
	end

	return true
end

function helpers.connect(self, address, port, socktype, errlevel)
	local fd = helpers.validate(self.fd())
	helpers.typecheck(address, "string", 2, errlevel and errlevel + 1 or 3)
	helpers.typeoptcheck(port, "number", 3, errlevel and errlevel + 1 or 3)

	address = address == "*" and nil or address
	port = port == nil and "0" or tostring(port)

	local addrinfo_instance = ffi.new("struct addrinfo")
	addrinfo_instance.ai_socktype = socktype
	addrinfo_instance.ai_family = self.family

	local addrinfo_list = ffi.new("struct addrinfo *[1]")

	local res = library.getaddrinfo(address, port, addrinfo_instance, addrinfo_list)
	if res ~= 0 then
		library.freeaddrinfo(addrinfo_list[0])
		return nil, platform.gaistrerror(res)
	end

	res = library.connect(fd, addrinfo_list[0].ai_addr, addrinfo_list[0].ai_addrlen)
	library.freeaddrinfo(addrinfo_list[0])
	if res == -1 then
		return nil, platform.strerror(platform.lasterror())
	end

	return true
end

return helpers
