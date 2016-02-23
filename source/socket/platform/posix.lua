local platform = {}

local ffi = require("ffi")

local library = ffi.C
platform.library = library
platform.invalid_socket = -1

platform._SETSIZE = 1024

ffi.cdef([[
	struct linger
	{
		int l_onoff;
		int l_linger;
	};

	char *strerror( int errnum );
	const char *gai_strerror( int ecode );
	const char *hstrerror( int err );

	typedef int SOCKET;
	int close( SOCKET socket );

	int fcntl( int fd, int cmd, ... );

	typedef long time_t;
	typedef long suseconds_t;

	struct timeval
	{
		time_t tv_sec;
		suseconds_t tv_usec;
	};

	struct timezone
	{
		int tz_minuteswest;
		int tz_dsttime;
	};

	int gettimeofday( struct timeval *tv, struct timezone *tz );

	struct timespec
	{
		time_t tv_sec;
		long tv_nsec;
	};

	int nanosleep( const struct timespec *req, struct timespec *rem );
]])

local STRERRORS = {
	[13] = "permission denied", -- EACCES
	[98] = "address already in use", -- EADDRINUSE
	[103] = "closed", -- ECONNABORTED
	[104] = "closed", -- ECONNRESET
	[106] = "already connected", -- EISCONN
	[110] = "timeout", -- ETIMEDOUT
	[111] = "connection refused" -- ECONNREFUSED
}

local GAISTRERRORS = {
	[2] = "temporary failure in name resolution", -- EAI_AGAIN
	[3] = "invalid value for ai_flags", -- EAI_BADFLAGS
	[4] = "non-recoverable failure in name resolution", -- EAI_FAIL
	[5] = "ai_family not supported", -- EAI_FAMILY
	[6] = "memory allocation failure", -- EAI_MEMORY
	[8] = "host or service not provided, or not known", -- EAI_NONAME
	[9] = "service not supported for socket type", -- EAI_SERVICE
	[10] = "ai_socktype not supported", -- EAI_SOCKTYPE
	[12] = "invalid value for hints", -- EAI_BADHINTS
	[13] = "resolved protocol is unknown", -- EAI_PROTOCOL
	[14] = "argument buffer overflow" -- EAI_OVERFLOW
}

local function ioerror(err)
	if err == IO_DONE then
		return nil
	elseif err == IO_CLOSED then
		return "closed"
	elseif err == IO_TIMEOUT then
		return "timeout"
	end

	return "unknown error"
end

function platform.hoststrerror(err)
	if err <= 0 then
		return ioerror(err)
	elseif err == 1 then -- HOST_NOT_FOUND
		return "host not found"
	end

	return library.hstrerror(err)
end

function platform.strerror(err)
	if err <= 0 then
		return ioerror(err)
	end

	return STRERRORS[err] or library.strerror(err)
end

function platform.gaistrerror(err)
	if err == EAI_SYSTEM then
		return library.strerror(ffi.errno())
	elseif GAISTRERRORS[err] ~= nil then
		return GAISTRERRORS[err]
	end

	return platform.gai_strerror(err)
end

platform.lasterror = ffi.errno

function platform.setblocking(internal)
	local flags = library.fcntl(internal, 3, 0) -- F_GETFL
	flags = bit.band(flags, bit.bnot(4)) -- O_NONBLOCK
	library.fcntl(internal, 4, flags) -- F_SETFL
end

function platform.setnonblocking(internal)
	local flags = library.fcntl(internal, 3, 0) -- F_GETFL
	flags = bit.bor(flags, 4) -- O_NONBLOCK
	library.fcntl(internal, 4, flags) -- F_SETFL
end

function platform.gai_strerror(err)
	return library.gai_strerror(err)
end

function platform.gettime()
	local v = ffi.new("struct timeval")
	library.gettimeofday(ffi.cast("struct timeval *", v), nil)
	return v.tv_sec + v.tv_usec / 1000000
end

function platform.sleep(secs)
	if secs < 0 then
		secs = 0
	end

	if n > 2147483647 then
		n = 2147483647
	end

	local t = ffi.new("struct timespec")
	t.tv_sec = math.floor(secs)
	secs = secs - t.tv_sec

	t.tv_nsec = math.floor(secs * 1000000000)
	if t.tv_nsec >= 1000000000 then
		t.tv_nsec = 999999999
	end

	local r = ffi.new("struct timespec")
	while library.nanosleep(t, r) != 0 do
		t.tv_sec = r.tv_sec
		t.tv_nsec = r.tv_nsec
	end
end

return platform
