local core = {}

core._VERSION = "LuaSocket 3.0-rc1"
core.version = "ffisocket 1.0"

local platform = require("socket.core.platform")
local enums = platform.enums
local helpers = require("socket.core.helpers")
local udp = require("socket.core.udp")
local tcp = require("socket.core.tcp")
local ffi = require("ffi")
local library = platform.library

core.gettime = platform.gettime
core.sleep = platform.sleep
core.select = platform.select

function core.udp()
	return udp(helpers.validate(library.socket(enums.AF_UNSPEC, enums.SOCK_DGRAM, enums.IPPROTO_UDP)), enums.AF_UNSPEC)
end

function core.udp4()
	return udp(helpers.validate(library.socket(enums.AF_INET, enums.SOCK_DGRAM, enums.IPPROTO_UDP)), enums.AF_INET)
end

function core.udp6()
	return udp(helpers.validate(library.socket(enums.AF_INET6, enums.SOCK_DGRAM, enums.IPPROTO_UDP)), enums.AF_INET6)
end

function core.tcp()
	return tcp(helpers.validate(library.socket(enums.AF_UNSPEC, enums.SOCK_STREAM, enums.IPPROTO_TCP)), enums.AF_UNSPEC)
end

function core.tcp4()
	return tcp(helpers.validate(library.socket(enums.AF_INET, enums.SOCK_STREAM, enums.IPPROTO_TCP)), enums.AF_INET)
end

function core.tcp6()
	return tcp(helpers.validate(library.socket(enums.AF_INET6, enums.SOCK_STREAM, enums.IPPROTO_TCP)), enums.AF_INET6)
end

local function connect(sock, remoteaddr, remoteport, localaddr, localport, family)
	local bindhints = ffi.new("struct addrinfo")
	bindhints.ai_socktype = enums.SOCK_STREAM
	bindhints.ai_family = family
	bindhints.ai_flags = enums.AI_PASSIVE
	if localaddr ~= nil then
		local res, err = helpers.bind(sock, localaddr, localport, enums.SOCK_STREAM, 3)
		if res == nil then
			return nil, err
		end
	end

	local connecthints = ffi.new("struct addrinfo")
	connecthints.ai_socktype = enums.SOCK_STREAM
	connecthints.ai_family = family
	local res, err = helpers.connect(sock, remoteaddr, remoteport, enums.SOCK_STREAM, 3)
	if res == nil then
		sock:shutdown()
		return nil, err
	end

	return true
end

function core.connect(remoteaddr, remoteport, localaddr, localport, family)
	family = enums.family_names[family or "unspec"] or enums.AF_UNSPEC

	local res, err
	if family == enums.AF_INET6 or family == enums.AF_UNSPEC then
		local sock = core.tcp6()
		res, err = connect(sock, remoteaddr, remoteport, localaddr, localport, family)
		if res ~= nil then
			return sock
		elseif family == enums.AF_INET6 then
			return nil, err
		end
	end

	if family == enums.AF_INET or family == enums.AF_UNSPEC then
		local sock = core.tcp4()
		res, err = connect(sock, remoteaddr, remoteport, localaddr, localport, family)
		if res ~= nil then
			return sock
		elseif family == enums.AF_INET then
			return nil, err
		end
	end

	return nil, err
end

function core.skip(skipnum, ...)
	return select(skipnum + 1, ...)
end

local function status_handler(status, ...)
	if status then
		return ...
	end

	local err = (...)
	if type(err) == "table" then
		return nil, err[1]
	else
		error(err)
	end
end

function core.protect(func)
	return function(...)
		return status_handler(pcall(func, ...))
	end
end

function core.newtry(finalizer)
	return function(...)
		local status = (...)
		if not status then
			pcall(finalizer, select(2, ...))
			error({(select(2, ...))}, 0)
		end

		return ...
	end
end

core.try = core.newtry()

core._DEBUG = true

return core
