#!/bin/sh
# Copyright (c) 2021 Konosuke Furuhata <konosuke@furuhata.jp>
# Licensed under the MIT License.
#
# When a neighbor cache entry in the INCOMPLETE state is created on any of the specified
# interfaces, the same entry will be created on all other specified interfaces.
# If the state of the neighbor cache entry is changed from INCOMPLETE to REACHABLE, the
# static route entry will be created automatically.
# This is useful if the WAN interface is a point-to-point link (e.g. 3GPP network) that
# does not use IPv6 NDP and there are two or more LAN interfaces.
#

readonly ROUTE_TTL="600"
readonly IP_PATH="ip"

log() {
	logger -t "$(basename $0)" -p "user.${2:-notice}" "$1"
	echo "$1"
}

keepalive() {
	local addr="$1"
	local device=$("$IP_PATH" -6 route show "$1" | awk '{print $3}')
	[ "$device" ] || return

	# Keep or delete route entry depending on the state of neighbor cache entry.
	ping -c 1 -W 1 -I "$device" "$addr" >/dev/null &
	for i in $(seq 10); do
		"$IP_PATH" -6 neigh show nud reachable | grep -q "$addr" && {
			{ sleep "$ROUTE_TTL"; keepalive "$addr"; } &
			return
		}
		sleep 1
	done
	"$IP_PATH" -6 route del "$addr" dev "$device" &&
		log "Deleted route entry ($addr dev $device)"
}

main() {
	local devices="$*"
	local addrs=$(
		"$IP_PATH" -6 neigh show nud incomplete |
			grep -e ${devices// / -e } |
			sed '/fe80::/d' |
			awk '{print $1}' |
			tr '\n' ' '
	)

	local addr
	for addr in $addrs; do
		"$IP_PATH" -6 route | grep -q "$addr" && continue

		# Send ICMPv6 echo request from specified interfaces
		# to be kept up to date for neighbor cache entries.
		local device random
		for device in $devices; do
			random=$(cat /dev/urandom | tr -dc '123456789' | head -c 5)
			log "Pinging for $addr on $device"
			{
				"$IP_PATH" -6 route add "$addr" dev "$device" metric "$random"
				ping -c 1 -W 1 -I "$device" "$addr" >/dev/null
				"$IP_PATH" -6 route del "$addr" dev "$device" metric "$random"
			} &
		done

		# Add route entry depending on the state of neighbor cache entry.
		for i in $(seq 10); do
			"$IP_PATH" -6 neigh show nud reachable | grep -q "$addr" && {
				device=$(
					"$IP_PATH" -6 neigh show "$addr" nud reachable |
						awk '{print $3}'
				)
				"$IP_PATH" -6 route add "$addr" dev "$device" proto static && {
					log "Added route entry ($addr dev $device)"
					{ sleep "$ROUTE_TTL"; keepalive "$addr"; } &
				}
				break
			}
			sleep 1
		done
	done
}

[ "$1" ] || {
	echo "Usage: $0 <device>" 1>&2
	exit 1
}

which "$IP_PATH" >/dev/null || {
	log "Missing or invalid path '$IP_PATH'" err
	exit 1
}

while :; do
	main "$@"
	sleep 1
done
