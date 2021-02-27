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

enums.IP_MULTICAST_IF = 9
enums.IP_MULTICAST_LOOP = 11

enums.IPV6_UNICAST_HOPS = 4
enums.IPV6_MULTICAST_HOPS = 10
enums.IPV6_MULTICAST_LOOP = 11
enums.IPV6_V6ONLY = 27

enums.SD_RECEIVE = 0
enums.SD_SEND = 1
enums.SD_BOTH = 2

enums.SHUT_RD = enums.SD_RECEIVE
enums.SHUT_WR = enums.SD_SEND
enums.SHUT_RDWR = enums.SD_BOTH

enums.NI_NUMERICHOST = 2
enums.NI_NUMERICSERV = 8

enums.AI_PASSIVE = 1
enums.AI_NUMERICHOST = 4
enums.AI_NUMERICSERV = 8

enums.SOL_SOCKET = 65535

enums.SO_DEBUG = 1
enums.SO_REUSEADDR = 4
enums.SO_TYPE = 4104
enums.SO_ERROR = 4103
enums.SO_DONTROUTE = 16
enums.SO_BROADCAST = 32
enums.SO_SNDBUF = 4097
enums.SO_RCVBUF = 4098
enums.SO_KEEPALIVE = 8
enums.SO_OOBINLINE = 256
enums.SO_LINGER = 128
enums.SO_REUSEPORT = enums.SO_REUSEADDR
enums.SO_RCVLOWAT = 4100
enums.SO_SNDLOWAT = 4099
enums.SO_RCVTIMEO = 4102
enums.SO_SNDTIMEO = 4101

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
