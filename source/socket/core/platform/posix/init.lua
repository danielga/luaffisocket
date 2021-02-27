local ffi = require("ffi")

local library = ffi.C
local platform = {}
platform.library = library
platform.invalid_socket = -1

platform._SETSIZE = 1024

ffi.cdef([[
	typedef int SOCKET;
	typedef long time_t;
	typedef long suseconds_t;

	struct servent
	{
		char *s_name;
		char **s_aliases;
		int s_port;
		char *s_proto;
	};

	struct linger
	{
		int l_onoff;
		int l_linger;
	};

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

	struct timespec
	{
		time_t tv_sec;
		long tv_nsec;
	};

	char *strerror( int errnum );
	const char *gai_strerror( int ecode );
	const char *hstrerror( int err );

	int close( SOCKET socket );

	int fcntl( int fd, int cmd, ... );

	int gettimeofday( struct timeval *tv, struct timezone *tz );

	int nanosleep( const struct timespec *req, struct timespec *rem );

	SOCKET accept( SOCKET socket, struct sockaddr *addr, int *addrlen );
	int bind( SOCKET socket, const struct sockaddr *name, int namelen );
	int connect( SOCKET socket, const struct sockaddr *name, int namelen );
	void freeaddrinfo( struct addrinfo *ai );
	int getaddrinfo( const char *nodename, const char *servicename, const struct addrinfo *hints, struct addrinfo **result );
	struct hostent *gethostbyaddr( const char *addr, int len, int type );
	struct hostent *gethostbyname( const char *name );
	int getnameinfo( const struct sockaddr *sa, socklen_t salen, char *host, unsigned long hostlen, char *serv, unsigned long servlen, int flags );
	int getpeername( SOCKET socket, struct sockaddr *name, int *namelen );
	struct protoent *getprotobyname( const char *name );
	struct protoent *getprotobynumber( int number );
	struct servent *getservbyname( const char *name, const char *proto );
	struct servent *getservbyport( int  port, const char *proto );
	int getsockname( SOCKET socket, struct sockaddr *name, int *namelen );
	int getsockopt( SOCKET socket, int level, int optname, char *optval, int *optlen );
	int listen( SOCKET socket, int backlog );
	int recv( SOCKET socket, char *buf, int len, int flags );
	int recvfrom( SOCKET socket, char *buf, int len, int flags, struct sockaddr *from, int *fromlen );
	int send( SOCKET socket, const char *buf, int len, int flags );
	int sendto( SOCKET socket, const char *buf, int len, int flags, const struct sockaddr *to, int tolen );
	int setsockopt( SOCKET socket, int level, int optname, const char *optval, int optlen );
	int shutdown( SOCKET socket, int how );
	SOCKET socket( int domain, int type, int protocol );
]])

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

local STRERRORS = {}
function platform.strerror(err)
	if err <= 0 then
		return ioerror(err)
	end

	local errstr = STRERRORS[err]
	if errstr == nil then
		errstr = library.strerror(err)
		STRERRORS[err] = errstr
	end

	return errstr
end

local GAISTRERRORS = {}
function platform.gai_strerror(err)
	if err == EAI_SYSTEM then
		return platform.strerror(ffi.errno())
	end

	local errstr = GAISTRERRORS[err]
	if errstr == nil then
		errstr = library.gai_strerror(err)
		GAISTRERRORS[err] = errstr
	end

	return errstr
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

platform.enums = require("socket.core.platform.posix.enums")

platform.select = require("socket.core.platform.posix.select")

return platform
