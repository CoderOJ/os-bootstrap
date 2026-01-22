set -euo pipefail

# enable resolved mdns

DROPIN_DIR="/etc/systemd/resolved.conf.d"
DROPIN_FILE="${DROPIN_DIR}/10-enable-mdns.conf"

mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_FILE" <<'EOF'
[Resolve]
MulticastDNS=yes
EOF

echo "Enable resolved mDNS, restarting"

systemctl daemon-reload
systemctl restart systemd-resolved

# enalbe mdns

DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')

if [[ -z "$DEFAULT_IFACE" ]]; then
  echo "Error: cannot detect default interface."
  exit 1
fi

echo "Enable mdns on $DEFAULT_IFACE"
sudo resolvectl mdns "$DEFAULT_IFACE" yes
