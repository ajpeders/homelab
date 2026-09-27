#!/bin/sh
# Dumps wg-quick configs for named clients to /out/ by reading the wg-easy DB.
# Runs as a oneshot sidecar. Keys are written with mode 600.
set -eu

DB=/wg/wg-easy.db
OUT=/out

command -v sqlite3 >/dev/null 2>&1 || apk add --no-cache --quiet sqlite >/dev/null

mkdir -p "$OUT"
umask 077
OWNER=$(stat -c '%u:%g' "$OUT")

CLIENTS="${CLIENTS:-$(sqlite3 "$DB" "SELECT name FROM clients_table WHERE enabled = 1;")}"

csv() { echo "$1" | sed 's/^\[//; s/\]$//; s/"//g; s/,/, /g'; }

for name in $CLIENTS; do
  row=$(sqlite3 -separator '|' "$DB" "
    SELECT c.private_key, c.ipv4_address, c.ipv6_address, COALESCE(c.dns,''), c.mtu,
           i.public_key, c.pre_shared_key, COALESCE(c.allowed_ips,''),
           COALESCE(c.server_endpoint,''), i.port, c.persistent_keepalive
    FROM clients_table c JOIN interfaces_table i ON c.interface_id = i.name
    WHERE c.name = '$name' AND c.enabled = 1;" || true)

  if [ -z "$row" ]; then
    echo "skip: no enabled client '$name'" >&2
    continue
  fi

  IFS='|'
  # shellcheck disable=SC2086
  set -- $row
  unset IFS
  priv=$1; v4=$2; v6=$3; dns=$4; mtu=$5
  srv_pub=$6; psk=$7; allowed=$8
  endpoint=$9; port=${10}; keepalive=${11}

  if [ -n "${WG_PUBLIC_IP:-}" ] && [ -n "${WG_HOSTNAME:-}" ]; then
    endpoint=$(echo "$endpoint" | sed "s/${WG_HOSTNAME}/${WG_PUBLIC_IP}/")
  fi

  cat > "$OUT/$name.conf" <<CFG
[Interface]
PrivateKey = $priv
Address = $v4/24, $v6/64
DNS = $(csv "$dns")
MTU = $mtu

[Peer]
PublicKey = $srv_pub
PresharedKey = $psk
AllowedIPs = $(csv "$allowed")
Endpoint = $endpoint
PersistentKeepalive = $keepalive
CFG
  chown "$OWNER" "$OUT/$name.conf"
  echo "wrote $OUT/$name.conf"
done
