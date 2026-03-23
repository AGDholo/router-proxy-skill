#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <router-host> <node-id> [node-id...]" >&2
  exit 1
fi

ROUTER_HOST="$1"
shift
ROUTER_USER="${ROUTER_USER:-root}"
NODE_IDS=("$@")

NODE_LIST=""
for node_id in "${NODE_IDS[@]}"; do
  NODE_LIST+="${node_id} "
done

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/router_known_hosts \
  "${ROUTER_USER}@${ROUTER_HOST}" "NODE_IDS='${NODE_LIST}' sh" <<'EOF'
set -eu

for id in $NODE_IDS; do
  remarks=$(uci -q get passwall.$id.remarks)
  port=$(/usr/share/passwall/app.sh get_new_port 65080 tcp)
  /usr/share/passwall/app.sh run_socks flag=probe_$id node=$id bind=127.0.0.1 socks_port=$port config_file=probe_$id.json >/dev/null 2>&1
  sleep 2

  geo=$(curl -s --max-time 8 -x socks5h://127.0.0.1:$port https://api.ip.sb/geoip || true)

  ok=0
  total=0
  n=0
  i=1
  while [ "$i" -le 6 ]; do
    res=$(curl -s -o /dev/null -w '%{http_code} %{time_starttransfer}' --max-time 8 -x socks5h://127.0.0.1:$port https://www.google.com/generate_204 || true)
    code=$(echo "$res" | awk '{print $1}')
    t=$(echo "$res" | awk '{print $2}')
    [ "$code" = "204" ] && ok=$((ok + 1))
    total=$(awk -v a="$total" -v b="${t:-0}" 'BEGIN{printf "%.6f", a+b}')
    n=$((n + 1))
    i=$((i + 1))
  done
  avg=$(awk -v a="$total" -v b="$n" 'BEGIN{if (b > 0) printf "%.3f", a/b; else print "0"}')

  dl=$(curl -s -o /dev/null -w '%{http_code} %{speed_download} %{time_total} %{size_download}' --max-time 20 -x socks5h://127.0.0.1:$port 'https://speed.cloudflare.com/__down?bytes=8000000' || true)
  dcode=$(echo "$dl" | awk '{print $1}')
  dspeed=$(echo "$dl" | awk '{print $2}')
  dtime=$(echo "$dl" | awk '{print $3}')
  dsize=$(echo "$dl" | awk '{print $4}')
  dspeed_mbps=$(awk -v s="${dspeed:-0}" 'BEGIN{printf "%.2f", s*8/1000000}')

  printf 'ID=%s\nREMARKS=%s\nSTABILITY=%s/6 AVG=%ss\nDOWNLOAD=%s Mbps CODE=%s SIZE=%s TIME=%ss\nGEO=%s\n---\n' \
    "$id" "$remarks" "$ok" "$avg" "$dspeed_mbps" "${dcode:-}" "${dsize:-}" "${dtime:-}" "$geo"

  for pid in $(pgrep -f "probe_$id" || true); do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
  rm -rf /tmp/etc/passwall/*probe_${id}*.* >/dev/null 2>&1 || true
done
EOF
