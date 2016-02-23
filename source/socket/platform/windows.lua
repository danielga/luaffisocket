local platform = {}

local ffi = require("ffi")

local library = ffi.load("ws2_32")
platform.library = library
platform.invalid_socket = 4294967295

platform._SETSIZE = 64

if ffi.arch == "x86" then
	ffi.cdef([[
		typedef struct WSAData
		{
			unsigned short wVersion;
			unsigned short wHighVersion;
			char szDescription[257];
			char szSystemStatus[129];
			unsigned short iMaxSockets;
			unsigned short iMaxUdpDg;
			char *lpVendorInfo;
		} WSADATA;

		typedef unsigned int SOCKET;
	]])
elseif ffi.arch == "x64" then
	ffi.cdef([[
		typedef struct WSAData
		{
			unsigned short wVersion;
			unsigned short wHighVersion;
			unsigned short iMaxSockets;
			unsigned short iMaxUdpDg;
			char *lpVendorInfo;
			char szDescription[257];
			char szSystemStatus[129];
		} WSADATA;

		typedef unsigned long long SOCKET;
	]])
end

ffi.cdef([[
	typedef void *HANDLE;
	typedef HANDLE HLOCAL;

	struct linger
	{
		unsigned short l_onoff;
		unsigned short l_linger;
	};

	unsigned long FormatMessage(
		unsigned long flags,
		void *source,
		unsigned long msgid,
		unsigned long langid,
		char *buffer,
		unsigned long size,
		va_list *args
	) __asm__("FormatMessageA");
	HLOCAL LocalFree( HLOCAL mem );

	char *strerror( int errnum );

	int WSAStartup( unsigned short versionreq, WSADATA *wsadata );
	int WSACleanup( );

	int WSAGetLastError( );
	void WSASetLastError( int error );

	int close( SOCKET socket ) __asm__("closesocket");

	int ioctlsocket( SOCKET socket, long cmd, unsigned long *argp );

	typedef struct _FILETIME
	{
		unsigned long dwLowDateTime;
		unsigned long dwHighDateTime;
	} FILETIME, *PFILETIME;

	void GetSystemTimeAsFileTime( FILETIME *lpSystemTimeAsFileTime );

	void Sleep( unsigned long dwMilliseconds );
]])

local wsadata = ffi.new("WSADATA")
if library.WSAStartup(131074, wsadata) ~= 0 then -- bit.bor(2, bit.lshift(2, 16))
	error("unable to initialize the Windows sockets library")
end

platform.internal = newproxy(true)
local internal_metatable = getmetatable(platform.internal)

function internal_metatable:__gc()
	library.WSACleanup()
end

local STRERRORS = {
	[10004] = "Interrupted function call", -- WSAEINTR
	[10013] = "permission denied", -- WSAEACCES
	[10014] = "Bad address", -- WSAEFAULT
	[10022] = "Invalid argument", -- WSAEINVAL
	[10024] = "Too many open files", -- WSAEMFILE
	[10035] = "Resource temporarily unavailable", -- WSAEWOULDBLOCK
	[10036] = "Operation now in progress", -- WSAEINPROGRESS
	[10037] = "Operation already in progress", -- WSAEALREADY
	[10038] = "Socket operation on nonsocket", -- WSAENOTSOCK
	[10039] = "Destination address required", -- WSAEDESTADDRREQ
	[10040] = "Message too long", -- WSAEMSGSIZE
	[10041] = "Protocol wrong type for socket", -- WSAEPROTOTYPE
	[10042] = "Bad protocol option", -- WSAENOPROTOOPT
	[10043] = "Protocol not supported", -- WSAEPROTONOSUPPORT
	[10044] = "ai_socktype not supported", -- WSAESOCKTNOSUPPORT
	[10045] = "Operation not supported", -- WSAEOPNOTSUPP
	[10046] = "Protocol family not supported", -- WSAEPFNOSUPPORT
	[10047] = "ai_family not supported", -- WSAEAFNOSUPPORT
	[10048] = "address already in use", -- WSAEADDRINUSE
	[10049] = "Cannot assign requested address", -- WSAEADDRNOTAVAIL
	[10050] = "Network is down", -- WSAENETDOWN
	[10051] = "Network is unreachable", -- WSAENETUNREACH
	[10052] = "Network dropped connection on reset", -- WSAENETRESET
	[10053] = "closed", -- WSAECONNABORTED
	[10054] = "closed", -- WSAECONNRESET
	[10055] = "No buffer space available", -- WSAENOBUFS
	[10056] = "already connected", -- WSAEISCONN
	[10057] = "Socket is not connected", -- WSAENOTCONN
	[10058] = "Cannot send after socket shutdown", -- WSAESHUTDOWN
	[10060] = "timeout", -- WSAETIMEDOUT
	[10061] = "connection refused", -- WSAECONNREFUSED
	[10064] = "Host is down", -- WSAEHOSTDOWN
	[10065] = "No route to host", -- WSAEHOSTUNREACH
	[10067] = "Too many processes", -- WSAEPROCLIM
	[10091] = "Network subsystem is unavailable", -- WSASYSNOTREADY
	[10092] = "Winsock.dll version out of range", -- WSASYSNOTREADY
	[10093] = "Successful WSAStartup not yet performed", -- WSANOTINITIALISED
	[10101] = "Graceful shutdown in progress", -- WSAEDISCON
	[11001] = "host not found", -- WSAHOST_NOT_FOUND
	[11002] = "Nonauthoritative host not found", -- WSATRY_AGAIN
	[11003] = "non-recoverable failure in name resolution", -- WSANO_RECOVERY
	[11004] = "Valid name, no data record of requested type" -- WSANO_DATA
}

local GAISTRERRORS = {
	[8] = "memory allocation failure", -- EAI_MEMORY
	[10022] = "invalid value for ai_flags", -- EAI_BADFLAGS
	[10044] = "ai_socktype not supported", -- EAI_SOCKTYPE
	[10047] = "ai_family not supported", -- EAI_FAMILY
	[10109] = "service not supported for socket type", -- EAI_SERVICE
	[11001] = "host or service not provided, or not known", -- EAI_NONAME
	[11002] = "temporary failure in name resolution", -- EAI_AGAIN
	[11003] = "non-recoverable failure in name resolution" -- EAI_FAIL

	--[EAI_BADHINTS] = "invalid value for hints", -- EAI_BADHINTS
	--[EAI_OVERFLOW] = "argument buffer overflow", -- EAI_OVERFLOW
	--[EAI_PROTOCOL] = "resolved protocol is unknown", -- EAI_PROTOCOL
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

function platform.strerror(err)
	if err <= 0 then
		return ioerror(err)
	end

	return STRERRORS[err] or "Unknown error"
end

platform.hoststrerror = platform.strerror

function platform.gaistrerror(err)
	if err == EAI_SYSTEM then
		return library.strerror(ffi.errno())
	elseif GAISTRERRORS[err] ~= nil then
		return GAISTRERRORS[err]
	end

	return platform.gai_strerror(err)
end

function platform.lasterror(errno)
	if errno ~= nil then
		library.WSASetLastError(errno)
	end

	return library.WSAGetLastError()
end

local blocking_value = ffi.new("unsigned int")
function platform.setblocking(internal)
	blocking_value[0] = 0
	library.ioctlsocket(internal, 2147772030, blocking_value) -- FIONBIO
end

function platform.setnonblocking(internal)
	blocking_value[0] = 1
	library.ioctlsocket(internal, 2147772030, blocking_value) -- FIONBIO
end

local buffer = ffi.new("char *[1]")
local C = ffi.C
function platform.gai_strerror(err)
	local res = C.FormatMessage(
		5119, -- FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_MAX_WIDTH_MASK | FORMAT_MESSAGE_ALLOCATE_BUFFER
		nil, -- NULL
		err,
		1024, -- MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)
		buff,
		0,
		nil -- NULL
	)
	if res == 0 then
		return "failed to obtain error message for code " .. err
	end

	local str = ffi.string(buffer, res)
	C.LocalFree(buffer)
	return str
end


function platform.gettime()
	local ft = ffi.new("FILETIME")
	C.GetSystemTimeAsFileTime(ffi.cast("FILETIME *", ft))
	return ft.dwLowDateTime / 10000000 + ft.dwHighDateTime * 4294967296 / 10000000 - 11644473600
end

function platform.sleep(secs)
	if secs < 0 then
		secs = 0
	end

	if secs < 1e34 then
		secs = secs * 1000
	end

	if secs > 2147483647 then
		secs = 2147483647
	end

	C.Sleep(math.floor(secs))
end

return platform
