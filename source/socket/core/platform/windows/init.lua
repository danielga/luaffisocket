local ffi = require("ffi")

ffi.cdef("typedef unsigned short WORD;")

if ffi.arch == "x86" then
	ffi.cdef([[
		typedef struct WSAData
		{
			WORD wVersion;
			WORD wHighVersion;
			char szDescription[257]; // WSADESCRIPTION_LEN + 1
			char szSystemStatus[129]; // WSASYS_STATUS_LEN + 1
			unsigned short iMaxSockets;
			unsigned short iMaxUdpDg;
			char *lpVendorInfo;
		} WSADATA, *LPWSADATA;

		typedef unsigned int SOCKET;
	]])
elseif ffi.arch == "x64" then
	ffi.cdef([[
		typedef struct WSAData
		{
			WORD wVersion;
			WORD wHighVersion;
			unsigned short iMaxSockets;
			unsigned short iMaxUdpDg;
			char *lpVendorInfo;
			char szDescription[257]; // WSADESCRIPTION_LEN + 1
			char szSystemStatus[129]; // WSASYS_STATUS_LEN + 1
		} WSADATA, *LPWSADATA;

		typedef unsigned long long SOCKET;
	]])
end

local C = ffi.C
local library = ffi.load("ws2_32")
local platform = {}
platform.library = library
platform.invalid_socket = 4294967295

platform._SETSIZE = 64

ffi.cdef([[
	typedef void *HANDLE;
	typedef int BOOL;
	typedef unsigned long DWORD;
	typedef char CHAR;
	typedef CHAR *LPSTR;
	typedef LPSTR LPTSTR;
	typedef const void *LPCVOID;
	typedef void *LPVOID;
	typedef unsigned short u_short;
	typedef unsigned long u_long;

	struct servent
	{
		char *s_name;
		char **s_aliases;
		short s_port;
		char *s_proto;
	};

	struct linger
	{
		u_short l_onoff;
		u_short l_linger;
	};

	typedef struct _FILETIME
	{
		DWORD dwLowDateTime;
		DWORD dwHighDateTime;
	} FILETIME, *PFILETIME, *LPFILETIME;

	HANDLE GetProcessHeap( );
	BOOL HeapFree( HANDLE hHeap, DWORD dwFlags, LPVOID lpMem );

	DWORD FormatMessage(
		DWORD flags,
		LPCVOID source,
		DWORD msgid,
		DWORD langid,
		LPTSTR buffer,
		DWORD size,
		va_list *args
	) __asm__( "FormatMessageA" );

	char *strerror( int errnum );

	int WSAStartup( WORD versionreq, LPWSADATA wsadata );
	int WSACleanup( );

	int WSAGetLastError( );
	void WSASetLastError( int error );

	int close( SOCKET socket ) __asm__( "closesocket" );

	int ioctlsocket( SOCKET socket, long cmd, u_long *argp );

	void GetSystemTimeAsFileTime( LPFILETIME lpSystemTimeAsFileTime );

	void Sleep( DWORD dwMilliseconds );

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

do
	local wsadata = ffi.new("WSADATA")
	if library.WSAStartup(131074, wsadata) ~= 0 then -- bit.bor(2, bit.lshift(2, 16))
		error("unable to initialize the Windows sockets library")
	end
end

platform.internal = newproxy(true)
local internal_metatable = getmetatable(platform.internal)

function internal_metatable:__gc()
	library.WSACleanup()
end

local function FormatMessage(err)
	local buffer = ffi.new("char *[1]")
	local res = C.FormatMessage(
		5119, -- FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_MAX_WIDTH_MASK | FORMAT_MESSAGE_ALLOCATE_BUFFER
		nil, -- NULL
		err,
		1024, -- MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)
		ffi.cast("LPTSTR", buffer),
		0,
		nil -- NULL
	)
	if res == 0 then
		return "failed to obtain error message for code " .. err
	end

	local str = ffi.string(buffer[0], res)
	C.HeapFree(C.GetProcessHeap(), 0, buffer[0])
	return str
end

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

local STRERRORS = {}
function platform.strerror(err)
	if err <= 0 then
		return ioerror(err)
	end

	local errstr = STRERRORS[err]
	if errstr == nil then
		errstr = FormatMessage(err)
		STRERRORS[err] = errstr
	end

	return errstr
end

platform.hoststrerror = platform.strerror

local GAISTRERRORS = {}
function platform.gai_strerror(err)
	if err == EAI_SYSTEM then
		return platform.strerror(ffi.errno())
	end

	local errstr = GAISTRERRORS[err]
	if errstr == nil then
		errstr = FormatMessage(err)
		GAISTRERRORS[err] = errstr
	end

	return errstr
end

function platform.lasterror(errno)
	local err = library.WSAGetLastError()
	if errno ~= nil then
		library.WSASetLastError(errno)
	end

	return err
end

function platform.setblocking(internal)
	local blocking_value = ffi.new("unsigned int[1]")
	blocking_value[0] = 0
	library.ioctlsocket(internal, 2147772030, blocking_value) -- FIONBIO
end

function platform.setnonblocking(internal)
	local blocking_value = ffi.new("unsigned int[1]")
	blocking_value[0] = 1
	library.ioctlsocket(internal, 2147772030, blocking_value) -- FIONBIO
end

function platform.gettime()
	local ft = ffi.new("FILETIME")
	C.GetSystemTimeAsFileTime(ft)
	return ft.dwLowDateTime / 10000000 + ft.dwHighDateTime * 4294967296 / 10000000 - 11644473600
end

function platform.sleep(secs)
	secs = (secs >= 0 and secs or 0) * 1000
	if secs > 2147483647 then
		secs = 2147483647
	end

	C.Sleep(secs)
end

platform.enums = require("socket.core.platform.windows.enums")

platform.select = require("socket.core.platform.windows.select")

return platform
