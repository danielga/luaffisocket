local core = {}

local ffi = require("ffi")
local platform = require("socket.platform")
local enums = require("socket.enums")
local helpers = require("socket.helpers")
local select = require("socket.select")
local library = platform.library

ffi.cdef([[
	typedef unsigned short sa_family_t;
	typedef unsigned int socklen_t;

	struct sockaddr_storage
	{
		sa_family_t ss_family;
		char __ss_pad1[6];
		long long __ss_align;
		char __ss_pad2[112];
	};

	struct sockaddr
	{
		unsigned short sa_family;
		char sa_data[14];
	};

	struct in_addr
	{
		unsigned int s_addr;
	};

	struct sockaddr_in
	{
		short sin_family;
		unsigned short sin_port;
		struct in_addr sin_addr;
		char sin_zero[8];
	};

	struct in6_addr
	{
		unsigned char s6_addr[16];
	};

	struct sockaddr_in6
	{
		short sin6_family;
		unsigned short sin6_port;
		unsigned int sin6_flowinfo;
		struct in6_addr sin6_addr;
		unsigned int sin6_scope_id;
	};

	struct addrinfo
	{
		int ai_flags;
		int ai_family;
		int ai_socktype;
		int ai_protocol;
		size_t ai_addrlen;
		char *ai_canonname;
		struct sockaddr *ai_addr;
		struct addrinfo *ai_next;
	};

	struct hostent
	{
		char *h_name;
		char **h_aliases;
		short h_addrtype;
		short h_length;
		char **h_addr_list;
	};

	struct protoent
	{
		char *p_name;
		char **p_aliases;
		short p_proto;
	};

	struct servent
	{
		char *s_name;
		char **s_aliases;
		int s_port;
		char *s_proto;
	};

	typedef struct fd_set
	{
		unsigned int fd_count;
		SOCKET fd_array[64];
	} fd_set;

	struct timeval
	{
		int tv_sec;
		int tv_usec;
	};

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
	int select( int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const struct timeval *timeout );
	int send( SOCKET socket, const char *buf, int len, int flags );
	int sendto( SOCKET socket, const char *buf, int len, int flags, const struct sockaddr *to, int tolen );
	int setsockopt( SOCKET socket, int level, int optname, const char *optval, int optlen );
	int shutdown( SOCKET socket, int how );
	SOCKET socket( int domain, int type, int protocol );

	int inet_aton( const char *cp, struct in_addr *inp );
	unsigned long inet_addr( const char *cp );
	char *inet_ntoa( struct in_addr in );

	unsigned int htonl( unsigned int hostlong );
	unsigned short htons( unsigned short hostshort );
	unsigned int ntohl( unsigned int netlong );
	unsigned short ntohs( unsigned short netshort );
]])

core.gettime = platform.gettime
core.sleep = platform.sleep
core.select = select

function core.udp()
	return udp(platform.invalid_socket, enums.AF_UNSPEC)
end

function core.udp4()
	return udp(core.validate(library.socket(enums.AF_INET, enums.SOCK_DGRAM, enums.IPPROTO_UDP)), enums.AF_INET)
end

function core.udp6()
	return udp(core.validate(library.socket(enums.AF_INET6, enums.SOCK_DGRAM, enums.IPPROTO_UDP)), enums.AF_INET6)
end

function core.tcp()
	return tcp(platform.invalid_socket, enums.AF_UNSPEC)
end

function core.tcp4()
	return tcp(core.validate(library.socket(enums.AF_INET, enums.SOCK_STREAM, enums.IPPROTO_TCP)), enums.AF_INET)
end

function core.tcp6()
	return tcp(core.validate(library.socket(enums.AF_INET6, enums.SOCK_STREAM, enums.IPPROTO_TCP)), enums.AF_INET6)
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
		local sock = socket.tcp6()
		res, err = connect(sock, remoteaddr, remoteport, localaddr, localport, family)
		if res ~= nil then
			return sock
		elseif family == enums.AF_INET6 then
			return nil, err
		end
	end

	if family == enums.AF_INET or family == enums.AF_UNSPEC then
		local sock = socket.tcp4()
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

return core
