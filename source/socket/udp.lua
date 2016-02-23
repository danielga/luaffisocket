local ffi = require("ffi")
local core = require("socket.core")
local helpers = require("socket.helpers")
local enums = require("socket.enums")
local platform = require("socket.platform")
local library = platform.library

local UDP_GETOPTIONS = {
	["dontroute"] = function(internal)
		return helpers.getoption_bool(internal, enums.SOL_SOCKET, enums.SO_DONTROUTE)
	end,
	["broadcast"] = function(internal)
		return helpers.getoption_bool(internal, enums.SOL_SOCKET, enums.SO_BROADCAST)
	end,
	["reuseaddr"] = function(internal)
		return helpers.getoption_bool(internal, enums.SOL_SOCKET, enums.SO_REUSEADDR)
	end,
	["reuseport"] = function(internal)
		return helpers.getoption_bool(internal, enums.SOL_SOCKET, enums.SO_REUSEPORT)
	end,
	["ip-multicast-if"] = function(internal)
		local options_in_addr = ffi.new("struct in_addr")
		local value, err = helpers.getoption(internal, enums.IPPROTO_IP, enums.IP_MULTICAST_IF, ffi.cast("char *", options_in_addr))
		if value == nil then
			return nil, err
		end

		return library.inet_ntoa(value)
	end,
	["ip-multicast-loop"] = function(internal)
		return helpers.getoption_bool(internal, enums.IPPROTO_IP, enums.IP_MULTICAST_LOOP)
	end,
	["error"] = function(internal)
		return helpers.getoption_int(internal, enums.SOL_SOCKET, enums.SO_ERROR)
	end,
	["ipv6-unicast-hops"] = function(internal)
		return helpers.getoption_int(internal, enums.IPPROTO_IPV6, enums.IPV6_UNICAST_HOPS)
	end,
	["ipv6-multicast-hops"] = function(internal)
		return helpers.getoption_int(internal, enums.IPPROTO_IPV6, enums.IPV6_MULTICAST_HOPS)
	end,
	["ipv6-multicast-loop"] = function(internal)
		return helpers.getoption_bool(internal, enums.IPPROTO_IPV6, enums.IPV6_MULTICAST_LOOP)
	end,
	["ipv6-v6only"] = function(internal)
		return helpers.getoption_bool(internal, enums.IPPROTO_IPV6, enums.IPV6_V6ONLY)
	end,
	["timeout"] = function(internal)
		return helpers.getoption_int(internal, enums.SOL_SOCKET, enums.SO_RCVTIMEO)
	end
}

local UDP_SETOPTIONS = {
	["dontroute"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.SOL_SOCKET, enums.SO_DONTROUTE, value)
	end,
	["broadcast"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.SOL_SOCKET, enums.SO_BROADCAST, value)
	end,
	["reuseaddr"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.SOL_SOCKET, enums.SO_REUSEADDR, value)
	end,
	["reuseport"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.SOL_SOCKET, enums.SO_REUSEPORT, value)
	end,
	["ip-multicast-if"] = function(internal, address)
		local in_addr_instance = ffi.new("struct in_addr")
		in_addr_instance.s_addr = library.htonl(helpers.address_any)
		if address ~= "*" and library.inet_aton(address, in_addr_instance) == 0 then
			error("ip expected")
		end

		return helpers.setoption(internal, enums.IPPROTO_IP, enums.IP_MULTICAST_IF, in_addr_instance)
	end,
	["ip-multicast-loop"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.IPPROTO_IP, enums.IP_MULTICAST_LOOP, value)
	end,
	["ipv6-unicast-hops"] = function(internal, value)
		return helpers.setoption_int(internal, enums.IPPROTO_IPV6, enums.IPV6_UNICAST_HOPS, value)
	end,
	["ipv6-multicast-hops"] = function(internal, value)
		return helpers.setoption_int(internal, enums.IPPROTO_IPV6, enums.IPV6_MULTICAST_HOPS, value)
	end,
	["ipv6-multicast-loop"] = function(internal, value)
		return helpers.setoption_bool(internal, enums.IPPROTO_IPV6, enums.IPV6_MULTICAST_LOOP, value)
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

local UDP = {
	__tostring = function(self)
		return string.format("udp{%s}: %08X", self.state, self.fd())
	end,
	__index = {
		close = function(self)
			self.fd(true)
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

			local optiongetter = helpers.optioncheck(name, UDP_GETOPTIONS, 2)
			return optiongetter(fd)
		end,
		getpeername = function(self)
			local fd = helpers.validate(self.fd())

			local sockaddr_instance = ffi.new("struct sockaddr_storage")
			local sockaddr_size = ffi.new("socklen_t")
			sockaddr_size[0] = ffi.sizeof(sockaddr_instance)

			if library.getpeername(fd, sockaddr_instance, sockaddr_size) == -1 then
				return nil, platform.strerror(socket_lasterror())
			end

			local address_buffer = ffi.new("char[?]", helpers.inet6_addrstrlen)
			local port_buffer = ffi.new("char[?]", helpers.portstrlen)
			local err = library.getnameinfo(
				ffi.cast("sockaddr *", sockaddr_instance), sockaddr_size[0],
				address_buffer, helpers.inet6_addrstrlen,
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

			local address_buffer = ffi.new("char[?]", helpers.inet6_addrstrlen)
			local port_buffer = ffi.new("char[?]", helpers.portstrlen)
			local err = library.getnameinfo(
				ffi.cast("sockaddr *", sockaddr_instance), sockaddr_size[0],
				address_buffer, helpers.inet6_addrstrlen,
				port_buffer, helpers.portstrlen,
				bit.bor(enums.NI_NUMERICHOST, enums.NI_NUMERICSERV)
			)
			if err ~= 0 then
				return nil, platform.gai_strerror(err)
			end

			return ffi.string(address_buffer), tonumber(ffi.string(port_buffer)), enums.family_names[self.family]
		end,
		receive = function(self, size)
			local fd = helpers.validate(self.fd())
			helpers.typeoptcheck(size, "number", 2)

			local data_size = 65535
			local data_buffer = ffi.new("char[?]", data_size)

			local res = library.recv(fd, data_buffer, math.min(size or data_size, data_size), 0)
			if res == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			return ffi.string(data_buffer, res)
		end,
		receivefrom = function(self, size)
			local fd = helpers.validate(self.fd())
			helpers.typeoptcheck(size, "number", 2)

			local sockaddr_instance = ffi.new("struct sockaddr_storage")
			local sockaddr_size = ffi.new("socklen_t")
			sockaddr_size[0] = ffi.sizeof(sockaddr_instance)

			local data_size = 65535
			local data_buffer = ffi.new("char[?]", data_size)

			local res = library.recvfrom(fd, data_buffer, math.min(size or data_size, data_size), 0, sockaddr_instance, sockaddr_size)
			if res == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			local address_buffer = ffi.new("char[?]", helpers.inet6_addrstrlen)
			local port_buffer = ffi.new("char[?]", helpers.portstrlen)
			local err = library.getnameinfo(
				ffi.cast("sockaddr *", sockaddr_instance), sockaddr_size[0],
				address_buffer, helpers.inet6_addrstrlen,
				port_buffer, helpers.portstrlen,
				bit.bor(enums.NI_NUMERICHOST, enums.NI_NUMERICSERV)
			)
			if err ~= 0 then
				return nil, platform.gai_strerror(err)
			end

			return ffi.string(data_buffer, res), ffi.string(address_buffer), tonumber(ffi.string(port_buffer)), enums.family_names[sockaddr_instance.sa_family]
		end,
		send = function(self, data)
			local fd = helpers.validate(self.fd())
			helpers.typecheck(data, "string", 2)

			local res = library.send(fd, data, #data, 0)
			if res == -1 then
				return nil, platfom.strerror(platfom.lasterror())
			end

			return res
		end,
		sendto = function(self, data, address, port)
			local fd = helpers.validate(self.fd())
			helpers.typecheck(data, "string", 2)
			helpers.typecheck(address, "string", 3)
			helpers.typecheck(port, "number", 4)

			local addrinfo_instance = ffi.new("struct addrinfo")
			addrinfo_instance.ai_family = self.family
			addrinfo_instance.ai_socktype = enums.SOCK_DGRAM
			addrinfo_instance.ai_flags = bit.bor(enums.AI_NUMERICHOST, enums.AI_NUMERICSERV)

			local addrinfo_list = ffi.new("struct addrinfo *[1]")

			local err = library.getaddrinfo(address, tostring(port), addrinfo_instance, addrinfo_list)
			if err ~= 0 then
				return nil, platform.gai_strerror(err)
			end

			local res = library.sendto(fd, data, #data, 0, addrinfo_list[0].ai_addr, addrinfo_list[0].ai_addrlen)
			library.freeaddrinfo(addrinfo_list[0])
			if res == -1 then
				return nil, platform.strerror(platform.lasterror())
			end

			return res
		end,
		setfd = function(self, fd)
			self.fd(fd)
		end,
		setpeername = function(self, address, port)
			return helpers.connect(self, address, port, enums.SOCK_DGRAM)
		end,
		setsockname = function(self, address, port)
			return helpers.bind(self, address, port, enums.SOCK_DGRAM)
		end,
		setoption = function(self, name, value)
			local fd = helpers.validate(self.fd())
			helpers.typecheck(name, "string", 2)

			local optionsetter = optioncheck(name, UDP_SETOPTIONS, 2)
			return optionsetter(fd, value)
		end,
		settimeout = function(self, value)
			return self:setoption("timeout", value)
		end
	}
}

return function(internal, family)
	return setmetatable({fd = helpers.newproxy(internal), type = enums.IPPROTO_UDP, family = family, state = "unconnected", class = "udp{unconnected}"}, UDP)
end
