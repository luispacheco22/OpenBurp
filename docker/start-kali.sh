#!/bin/bash
# start-kali.sh — Launch Kali pentesting container with VPN
#
# Usage:
#   ./docker/start-kali.sh <vpn-config.ovpn> [target-ip]
#
# Example:
#   ./docker/start-kali.sh machines_us-1.ovpn 10.129.32.249

set -e

VPN_FILE="${1:?Usage: $0 <vpn-config.ovpn> [target-ip]}"
TARGET_IP="${2:-}"
CONTAINER="kali-pentest"
IMAGE="kali-htb"
REPORT_DIR="$(pwd)/reports"

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "[*] Building Kali image..."
    docker build -t "$IMAGE" -f docker/Dockerfile.kali .
fi

# Stop old container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[*] Removing old container..."
    docker rm -f "$CONTAINER" >/dev/null
fi

# Create report directory
if [ -n "$TARGET_IP" ]; then
    mkdir -p "$REPORT_DIR/htb-${TARGET_IP}"/{scans,evidence,notes}
fi

# Start container
echo "[*] Starting Kali container..."
docker run -d \
    --name "$CONTAINER" \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    -v "$(realpath "$VPN_FILE"):/workspace/vpn.ovpn:ro" \
    -v "$REPORT_DIR:/workspace/report" \
    "$IMAGE" \
    sleep infinity

# Connect VPN
echo "[*] Connecting VPN..."
docker exec "$CONTAINER" bash -c \
    "mkdir -p /dev/net && mknod /dev/net/tun c 10 200 2>/dev/null; \
     openvpn --config /workspace/vpn.ovpn --daemon --log /tmp/vpn.log"

# Wait for VPN
sleep 5
if docker exec "$CONTAINER" grep -q "Initialization Sequence Completed" /tmp/vpn.log 2>/dev/null; then
    VPN_IP=$(docker exec "$CONTAINER" ifconfig tun0 2>/dev/null | grep -oP 'inet \K[\d.]+')
    echo "[+] VPN connected! IP: $VPN_IP"
else
    echo "[!] VPN may still be connecting. Check: docker exec $CONTAINER tail /tmp/vpn.log"
fi

# Test target connectivity
if [ -n "$TARGET_IP" ]; then
    echo "[*] Testing connectivity to $TARGET_IP..."
    if docker exec "$CONTAINER" ping -c 1 -W 5 "$TARGET_IP" &>/dev/null; then
        echo "[+] Target $TARGET_IP is reachable!"
    else
        echo "[!] Target $TARGET_IP not reachable yet. VPN may need more time."
    fi
fi

echo ""
echo "=== Ready ==="
echo "Container:  $CONTAINER"
echo "Run:        docker exec $CONTAINER <command>"
echo "Shell:      docker exec -it $CONTAINER bash"
echo "Stop:       docker rm -f $CONTAINER"
