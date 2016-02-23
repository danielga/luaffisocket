local ffi = require("ffi")
local core = require("socket.core")
local enums = require("socket.enums")
local helpers = require("socket.helpers")
local platform = require("socket.platform")
local library = platform.library

local TCP

local function tcp(internal, family)
	return setmetatable({fd = helpers.newproxy(internal), type = enums.IPPROTO_TCP, family = family, state = "unconnected", class = "tcp{client}"}, TCP)
end

local TCP_GETOPTIONS = {
	["keepalive"] = function(internal)
		return helpers.getoption_bool(internal, enums.SOL_SOCKET, enums.SO_KEEPALIVE)
	end,
	["reuseaddr"] = function(internal)
		return helpers.getoption_bool(internal, enums.SOL_SOCKET, enums.SO_REUSEADDR)
	end,
	["tcp-nodelay"] = function(internal)
		return helpers.getoption_bool(internal, enums.IPPROTO_TCP, enums.TCP_NODELAY)
	end,
	["linger"] = function(internal)
		local options_linger = ffi.new("struct linger")
		local value, err = helpers.getoption(internal, enums.SOL_SOCKET, enums.SO_LINGER, options_linger)
		if value == nil then
			return nil, err
		end

		return {on = value.l_onoff == 1, timeout = value.l_linger}
	end,
	["error"] = function(internal)
		return helpers.getoption_int(internal, enums.SOL_SOCKET, enums.SO_ERROR)
	end,
	["timeout"] = function(internal)
		return helpers.getoption_int(internal, enums.SOL_SOCKET, enums.SO_RCVTIMEO)
	end
}

local TCP_SETOPTIONS = {
	["keepalive"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.SOL_SOCKET, enums.SO_KEEPALIVE, value)
	end,
	["reuseaddr"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.SOL_SOCKET, enums.SO_REUSEADDR, value)
	end,
	["tcp-nodelay"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.IPPROTO_TCP, enums.TCP_NODELAY, value)
	end,
	["linger"] = function(internal, value)
		helpers.typecheck(value, "table", 3)
		local options_linger = ffi.new("struct linger")
		options_linger.l_onoff = value.on and 1 or 0
		options_linger.l_linger = value.timeout
		return helpers.setoption(internal, enums.SOL_SOCKET, enums.SO_LINGER, options_linger)
	end,
	["ipv6-v6only"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.IPPROTO_IPV6, enums.IPV6_V6ONLY, value)
	end,
	["timeout"] = function(internal, value)
		helpers.typecheck(value, "number", 3)
		if value == 0 then
			helpers.setnonblocking(internal)
		elseif value > 0 then
			helpers.setblocking(internal)
		else
			error("invalid timeout value")
		end

		local res, err = helpers.setoption_int(internal, enums.SOL_SOCKET, enums.SO_RCVTIMEO, value)
		if res == nil then
			return nil, err
		end

		return helpers.setoption_int(internal, enums.SOL_SOCKET, enums.SO_SNDTIMEO, value)
	end
}

TCP = {
	__tostring = function(self)
		return string.format("tcp{%s}: %08X", self.state, self.fd())
	end,
	__index = {
		accept = function(self)
			local fd = helpers.validate(self.fd())

			local sockaddr_instance = ffi.new("struct sockaddr_storage")
			local sockaddr_size = ffi.new("socklen_t[1]")
			sockaddr_size[0] = self.family == enums.AF_INET and ffi.sizeof("struct sockaddr_in") or ffi.sizeof("struct sockaddr_in6")

			local sock = library.accept(fd, ffi.cast("struct sockaddr *", sockaddr_instance), sockaddr_size)
			if sock == platform.invalid_socket then
				return nil, platform.strerror(platform.lasterror())
			end

			return tcp(sock, self.family)
		end,
		bind = function(self, address, port)
			return helpers.bind(self, address, port, enums.SOCK_STREAM)
		end,
		close = function(self)
			self.fd(true)
		end,
		connect = function(self, address, port)
			return helpers.connect(self, address, port, enums.SOCK_STREAM)
		end,
		dirty = function(self)
			return false
		end,
		getfamily = function(self)
			return enums.family_names[self.family]
		end,
		getfd = function(self)
			return self.fd()
		end,
		getoption = function(self, name)
			local fd = helpers.validate(self.fd())
			helpers.typecheck(name, "string", 2)

			local optiongetter = helpers.optioncheck(name, TCP_GETOPTIONS, 2)
			return optiongetter(fd)
		end,
		getpeername = function(self)
			local fd = helpers.validate(self.fd())

			local sockaddr_instance = ffi.new("struct sockaddr_storage")
			local sockaddr_size = ffi.new("socklen_t")
			sockaddr_size[0] = ffi.sizeof(sockaddr_instance)

			if library.getpeername(fd, sockaddr_instance, sockaddr_size) == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			local address_buffer = ffi.new("char[?]", helpers.int6_addrstrlen)
			local port_buffer = ffi.new("char[?]", helpers.portstrlen)
			local err = library.getnameinfo(
				ffi.cast("sockaddr *", sockaddr_instance), sockaddr_size[0],
				address_buffer, helpers.int6_addrstrlen,
				port_buffer, helpers.portstrlen,
				bit.bor(enums.NI_NUMERICHOST, enums.NI_NUMERICSERV)
			)
			if err ~= 0 then
				return nil, platform.gai_strerror(err)
			end

			return ffi.string(address_buffer), tonumber(ffi.string(port_buffer)), enums.family_names[self.family]
		end,
		getsockname = function(self)
			local fd = helpers.validate(self.fd())

			local sockaddr_instance = ffi.new("struct sockaddr_storage")
			local sockaddr_size = ffi.new("socklen_t")
			sockaddr_size[0] = ffi.sizeof(sockaddr_instance)

			if library.getsockname(fd, sockaddr_instance, sockaddr_size) == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			local address_buffer = ffi.new("char[?]", helpers.int6_addrstrlen)
			local port_buffer = ffi.new("char[?]", helpers.portstrlen)
			local err = library.getnameinfo(
				ffi.cast("sockaddr *", sockaddr_instance), sockaddr_size[0],
				address_buffer, helpers.int6_addrstrlen,
				port_buffer, helpers.portstrlen,
				bit.bor(enums.NI_NUMERICHOST, enums.NI_NUMERICSERV)
			)
			if err ~= 0 then
				return nil, platform.gai_strerror(err)
			end

			return ffi.string(address_buffer), tonumber(ffi.string(port_buffer)), enums.family_names[self.family]
		end,
		getstats = function(self)
			return nil, "not implemented"
		end,
		listen = function(self, backlog)
			local fd = helpers.validate(self.fd())
			helpers.typeoptcheck(backlog, "number", 2)

			if library.listen(fd, backlog) == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			return 1
		end,
		receive = function(self, size)
			local fd = helpers.validate(self.fd())
			helpers.typeoptcheck(size, "number", 2)

			size = size or 2^16
			local data_buffer = ffi.new("char[?]", size)

			local res = library.recv(fd, data_buffer, size, 0)
			if res == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			if res == 0 then
				print(size, res)
				--self:close()
				return nil, "closed"
			end

			if res ~= size then
				print(size, res)
				--self:close()
				return nil, "closed", ffi.string(data_buffer, res)
			end

			return ffi.string(data_buffer, res)
		end,
		send = function(self, data)
			local fd = helpers.validate(self.fd())
			helpers.typecheck(data, "string", 2)

			local res = library.send(fd, data, #data, 0)
			if res == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			return res
		end,
		setfd = function(self, fd)
			self.fd(fd)
		end,
		setoption = function(self, name, value)
			local fd = helpers.validate(self.fd())
			helpers.typecheck(name, "string", 2)

			local optionsetter = helpers.optioncheck(name, TCP_SETOPTIONS, 2)
			return optionsetter(fd, value)
		end,
		setpeername = function(self, address, port)
			return helpers.connect(self, address, port, enums.SOCK_STREAM)
		end,
		setsockname = function(self, address, port)
			return helpers.bind(self, address, port, enums.SOCK_STREAM)
		end,
		setstats = function(self, name, value)
			return nil, "not implemented"
		end,
		settimeout = function(self, value)
			return self:setoption("timeout", value)
		end,
		shutdown = function(self, mode)
			local fd = helpers.validate(self.fd())

			if mode == nil or mode == "both" then
				mode = enums.SHUT_RDWR
			elseif mode == "read" then
				mode = enums.SHUT_RD
			elseif mode == "write" then
				mode = enums.SHUT_WR
			elseif type(mode) == "string" then
				error("bad argument #2 to 'shutdown' (invalid option '" .. mode .. "')", 2)
			else
				error("bad argument #2 to 'shutdown' (string expected, got " .. type(mode) .. ")", 2)
			end

			library.shutdown(fd, mode)
		end
	}
}

return tcp
