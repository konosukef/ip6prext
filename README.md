# ip6prext
ip6prext is a OpenWrt hotplug script for extending IPv6 /64 prefix from a WAN interface to a one or more LAN interfaces. This is not a strict implementation of [RFC 7278](https://datatracker.ietf.org/doc/html/rfc7278), but is based on a similar concept.

## Dependencies
Use of this script requires the Busybox ip applet or iproute2 package (ip-tiny or ip).

## Installation
Place the scripts as follows:

```
# wget -O /etc/hotplug.d/iface/30-ip6prext https://raw.githubusercontent.com/konosukef/ip6prext/main/30-ip6prext
# wget -O /sbin/autowire.sh https://raw.githubusercontent.com/konosukef/ip6prext/main/autowire.sh
# chmod +x /sbin/autowire.sh
```

Enable NDP proxy for ndppd or odhcpd if necessary.

```
# opkg update && opkg install ndppd
# sed -i 's/NDPPD_ENABLE="0"/NDPPD_ENABLE="1"/' /etc/hotplug.d/iface/30-ip6prext
# sed -i 's/AUTOWIRE="0"/AUTOWIRE="1"/' /etc/hotplug.d/iface/30-ip6prext
```

## Limitations
Not synchronize the preferred and valid lifetimes of addresses between WAN and LAN interfaces.
