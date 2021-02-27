local enums = {}

enums.AF_UNSPEC = 0
enums.AF_INET = 2
enums.AF_INET6 = 23

enums.SOCK_STREAM = 1
enums.SOCK_DGRAM = 2

enums.IPPROTO_IP = 0
enums.IPPROTO_TCP = 6
enums.IPPROTO_UDP = 17
enums.IPPROTO_IPV6 = 41

enums.IP_MULTICAST_IF = 32
enums.IP_MULTICAST_LOOP = 34

enums.IPV6_UNICAST_HOPS = 16
enums.IPV6_MULTICAST_HOPS = 18
enums.IPV6_MULTICAST_LOOP = 19
enums.IPV6_V6ONLY = 26

enums.SHUT_RD = 0
enums.SHUT_WR = 1
enums.SHUT_RDWR = 2

enums.NI_NUMERICHOST = 2
enums.NI_NUMERICSERV = 8

enums.AI_PASSIVE = 1
enums.AI_NUMERICHOST = 4
enums.AI_NUMERICSERV = 8

enums.SOL_SOCKET = 1

enums.SO_DEBUG = 1
enums.SO_REUSEADDR = 2
enums.SO_TYPE = 3
enums.SO_ERROR = 4
enums.SO_DONTROUTE = 5
enums.SO_BROADCAST = 6
enums.SO_SNDBUF = 7
enums.SO_RCVBUF = 8
enums.SO_KEEPALIVE = 9
enums.SO_OOBINLINE = 10
enums.SO_NO_CHECK = 11
enums.SO_PRIORITY = 12
enums.SO_LINGER = 13
enums.SO_BSDCOMPAT = 14
enums.SO_REUSEPORT = 15
enums.SO_PASSCRED = 16
enums.SO_PEERCRED = 17
enums.SO_RCVLOWAT = 18
enums.SO_SNDLOWAT = 19
enums.SO_RCVTIMEO = 20
enums.SO_SNDTIMEO = 21
enums.SO_SNDBUFFORCE = 32
enums.SO_RCVBUFFORCE = 33

enums.TCP_NODELAY = 1

enums.family_names = {
	[enums.AF_UNSPEC] = "unspec",
	[enums.AF_INET] = "inet4",
	[enums.AF_INET6] = "inet6",

	unspec = enums.AF_UNSPEC,
	inet4 = enums.AF_INET,
	inet6 = enums.AF_INET6,
}

return enums
