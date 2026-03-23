#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <router-host> [router-user]" >&2
  exit 1
fi

ROUTER_HOST="$1"
ROUTER_USER="${2:-root}"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/router_known_hosts \
  "${ROUTER_USER}@${ROUTER_HOST}" '
for id in $(uci show passwall | sed -n "s/^passwall\.\([^.]*\)=nodes$/\1/p"); do
  proto=$(uci -q get passwall.$id.protocol)
  type=$(uci -q get passwall.$id.type)
  remarks=$(uci -q get passwall.$id.remarks)
  group=$(uci -q get passwall.$id.group)
  addr=$(uci -q get passwall.$id.address)
  port=$(uci -q get passwall.$id.port)
  [ "$proto" = "_shunt" ] && continue
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$id" "$remarks" "$group" "$type" "$proto" "$addr" "$port"
done
' | column -t -s $'\t'
