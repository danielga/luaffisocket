local ffi = require("ffi")

ffi.cdef([[
	typedef struct fd_set
	{
		unsigned int fd_count;
		SOCKET fd_array[64];
	} fd_set;

	int select( int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timeval *timeout );
]])

local library = ffi.load("ws2_32")

local function mkfdset(fds, nfds)
	if not fds then
		return nil, nfds
	end

	local set = ffi.new("fd_set")
	for i = 1, #fds do
		local fd = fds[i]:getfd()
		if fd + 1 > nfds then
			nfds = fd + 1
		end

		set.fd_array[i - 1] = fd
	end

	set.fd_count = #fds
	return set, nfds
end

local function fdisset(fds, set)
	local f = {}
	if fds then
		for i = 0, set.fd_count - 1 do
			local fd = set.fd_array[i]
			for k = 1, #fds do
				local sock = fds[k]
				if sock:getfd() == fd then
					table.insert(f, sock)
					break
				end
			end
		end
	end

	return f
end

return function(recvt, sendt, timeout)
	if timeout then
		local i, f = math.modf(timeout)
		timeout = ffi.new("struct timeval")
		timeout.tv_sec, timeout.tv_usec = i, math.floor(f * 1000000)
	end

	local r, w
	local nfds = 0
	r, nfds = mkfdset(recvt, nfds)
	w, nfds = mkfdset(sendt, nfds)

	local ret = library.select(nfds, r, w, nil, timeout)
	if ret == -1 then
		return nil, platform.strerror(platform.lasterror())
	end

	return fdisset(recvt, r), fdisset(sendt, w), ret
end
