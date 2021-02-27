local ffi = require("ffi")

if ffi.arch == "x86" then
	ffi.cdef("typedef unsigned int size_t;")
elseif ffi.arch == "x64" then
	ffi.cdef("typedef unsigned long long size_t;")
else
	error("unsupported architecture")
end

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
		sa_family_t sa_family;
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

	struct timeval
	{
		int tv_sec;
		int tv_usec;
	};

	int inet_aton( const char *cp, struct in_addr *inp );
	unsigned long inet_addr( const char *cp );
	char *inet_ntoa( struct in_addr in );

	unsigned int htonl( unsigned int hostlong );
	unsigned short htons( unsigned short hostshort );
	unsigned int ntohl( unsigned int netlong );
	unsigned short ntohs( unsigned short netshort );
]])

if ffi.os == "Windows" then
	return require("socket.core.platform.windows")
elseif ffi.os == "Linux" or ffi.os == "OSX" then
	return require("socket.core.platform.posix")
else
	error("unsupported architecture")
end
