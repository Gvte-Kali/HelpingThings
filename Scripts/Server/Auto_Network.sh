#!/bin/bash
# ============================================================
# auto_network.sh — Auto static IP / DHCP fallback
# Detects the active network and applies the matching
# static IP config via Netplan. Falls back to DHCP if
# no known network is detected.
#
# Usage: place network.conf in the same directory,
#        or set NETWORK_CONF to an absolute path.
# ============================================================

set -euo pipefail

# --- Load config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_CONF="${NETWORK_CONF:-$SCRIPT_DIR/network.conf}"

if [[ ! -f "$NETWORK_CONF" ]]; then
    echo "[ERROR] Config file not found: $NETWORK_CONF" >&2
    exit 1
fi

source "$NETWORK_CONF"

# ============================================================
# Helpers
# ============================================================

add_temp_ip() {
    sudo ip addr add "$1" dev "$INTERFACE" 2>/dev/null || true
}

del_temp_ip() {
    sudo ip addr del "$1" dev "$INTERFACE" 2>/dev/null || true
}

probe_gateway() {
    ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$1" > /dev/null 2>&1
}

write_static_netplan() {
    local ip="$1"
    local gw="$2"
    sudo bash -c "cat > '$CONFIG_FILE' << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $ip
      routes:
        - to: default
          via: $gw
      nameservers:
        addresses: $DNS
EOF"
}

write_dhcp_netplan() {
    sudo bash -c "cat > '$CONFIG_FILE' << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: yes
EOF"
}

# ============================================================
# Main detection loop
# ============================================================

echo "[INFO] Starting network detection on $INTERFACE..."

MATCHED=false
INDEX=1

while true; do
    PROBE_VAR="PROBE_${INDEX}"
    GATEWAY_VAR="GATEWAY_${INDEX}"
    STATIC_IP_VAR="STATIC_IP_${INDEX}"

    # Stop if the next network block is not defined
    [[ -z "${!PROBE_VAR+x}" ]] && break

    PROBE="${!PROBE_VAR}"
    GATEWAY="${!GATEWAY_VAR}"
    STATIC_IP="${!STATIC_IP_VAR}"

    echo "[INFO] [$INDEX] Probing gateway $GATEWAY (temp IP: $PROBE)..."

    add_temp_ip "$PROBE"

    if probe_gateway "$GATEWAY"; then
        echo "[INFO] [$INDEX] Network detected via $GATEWAY → applying static IP $STATIC_IP"
        del_temp_ip "$PROBE"
        write_static_netplan "$STATIC_IP" "$GATEWAY"
        MATCHED=true
        break
    fi

    del_temp_ip "$PROBE"
    INDEX=$((INDEX + 1))
done

if [[ "$MATCHED" == false ]]; then
    echo "[INFO] No known network detected. Falling back to DHCP."
    write_dhcp_netplan
fi

echo "[INFO] Applying Netplan config..."
sudo netplan apply
echo "[INFO] Done."
