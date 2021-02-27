local ffi = require("ffi")

ffi.cdef([[
	typedef struct fd_set
	{
		long int fds_bits[1024 / ( 8 * sizeof( long int ) )];
	} fd_set;

	int select( int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timeval *timeout );
]])

local C = ffi.C

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

		local fdelt = bit.rshift(fd, 5)
		set.fds_bits[fdelt] = bit.bor(set.fds_bits[fdelt], bit.lshift(1, fd % 32))
	end

	return set, nfds
end

local function fdisset(fds, set)
	local f = {}
	if fds then
		for i = 1, #fds do
			local sock = fds[i]
			local fd = sock:getfd()
			local fdelt = bit.rshift(fd, 5)
			if bit.band(set.fds_bits[fdelt], bit.lshift(1, fd % 32)) ~= 0 then
				table.insert(f, sock)
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

	local ret = C.select(nfds, r, w, nil, timeout)
	if ret == -1 then
		return nil, platform.strerror(platform.lasterror())
	end

	return fdisset(recvt, r), fdisset(sendt, w), ret
end
