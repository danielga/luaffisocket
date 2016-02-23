local socket = require("socket.core")
local enums = require("socket.enums")
local helpers = require("socket.helpers")

socket._VERSION = "LuaSocket 3.0-rc1"
socket.VERSION = "ffisocket 1.0"

socket.try = socket.newtry()

function socket.choose(table)
	return function(name, opt1, opt2)
		if type(name) ~= "string" then
			name, opt1, opt2 = "default", name, opt1
		end

		local f = table[name or "nil"]
		if f == nil then
			error("unknown key (".. tostring(name) ..")", 3)
		else
			return f(opt1, opt2)
		end
	end
end

local sourcet, sinkt = {}, {}
socket.sourcet = sourcet
socket.sinkt = sinkt

socket.BLOCKSIZE = 2048

sinkt["close-when-done"] = function(sock)
	return setmetatable({}, {
		__call = function(self, chunk, err)
			if chunk == nil then
				sock:close()
				return 1
			else
				return sock:send(chunk)
			end
		end,
		__index = {
			getfd = function()
				return sock:getfd()
			end,
			dirty = function()
				return sock:dirty()
			end
		}
	})
end

sinkt["keep-open"] = function(sock)
	return setmetatable({}, {
		__call = function(self, chunk, err)
			if chunk ~= nil then
				return sock:send(chunk)
			else
				return 1
			end
		end,
		__index = {
			getfd = function()
				return sock:getfd()
			end,
			dirty = function()
				return sock:dirty()
			end
		}
	})
end

sinkt["default"] = sinkt["keep-open"]

socket.sink = socket.choose(sinkt)

sourcet["by-length"] = function(sock, length)
	return setmetatable({}, {
		__call = function()
			if length <= 0 then
				return nil
			end

			local size = math.min(socket.BLOCKSIZE, length)
			local chunk, err = sock:receive(size)
			if err ~= nil then
				return nil, err
			end

			length = length - string.len(chunk)
			return chunk
		end,
		__index = {
			getfd = function()
				return sock:getfd()
			end,
			dirty = function()
				return sock:dirty()
			end
		}
	})
end

sourcet["until-closed"] = function(sock)
	local done
	return setmetatable({}, {
		__call = function()
			if done ~= nil then
				return nil
			end

			local chunk, err, partial = sock:receive(socket.BLOCKSIZE)
			if err == nil then
				return chunk
			elseif err == "closed" then
				sock:close()
				done = 1
				return partial
			else
				return nil, err
			end
		end,
		__index = {
			getfd = function()
				return sock:getfd()
			end,
			dirty = function()
				return sock:dirty()
			end
		}
	})
end


sourcet["default"] = sourcet["until-closed"]

socket.source = socket.choose(sourcet)

function socket.connect4(address, port, laddress, lport)
	return socket.connect(address, port, laddress, lport, "inet4")
end

function socket.connect6(address, port, laddress, lport)
	return socket.connect(address, port, laddress, lport, "inet6")
end

local function bind(sock, host, port, backlog)
	sock:setoption("reuseaddr", true)
	local res, err = helpers.bind(sock, host, port, enums.SOCK_STREAM, 3)
	if res == nil then
		sock:close()
	else
		res, err = sock:listen(backlog or 32)
		if res == nil then
			sock:close()
		else
			return sock
		end
	end

	return nil, err
end

function socket.bind(host, port, backlog)
	local sock = socket.tcp6()
	local res, err = bind(sock, host, port, backlog)
	if res ~= nil then
		return sock
	end

	sock = socket.tcp4()
	res, err = bind(sock, host, port, backlog)
	if res ~= nil then
		return sock
	end

	return nil, err
end

return socket
