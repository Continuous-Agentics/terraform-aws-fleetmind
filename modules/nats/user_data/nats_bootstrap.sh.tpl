#!/bin/bash
set -euo pipefail

NATS_VERSION="${nats_version}"
FLEET_NAME="${fleet_name}"

# ── Detect arch ──────────────────────────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  aarch64) NATS_ARCH="linux-arm64" ;;
  x86_64)  NATS_ARCH="linux-amd64" ;;
  *)        echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

# ── Install NATS server ──────────────────────────────────────────────────────
echo "[nats-bootstrap] Installing NATS server v$${NATS_VERSION} ($${NATS_ARCH})..."
cd /tmp
NATS_ZIP="nats-server-v$${NATS_VERSION}-$${NATS_ARCH}.zip"
curl -fsSL "https://github.com/nats-io/nats-server/releases/download/v$${NATS_VERSION}/$${NATS_ZIP}" -o "$NATS_ZIP"
unzip -o "$NATS_ZIP" -d /tmp/nats-extract
install -m 755 /tmp/nats-extract/nats-server-v$${NATS_VERSION}-$${NATS_ARCH}/nats-server /usr/local/bin/nats-server
rm -rf "$NATS_ZIP" /tmp/nats-extract

echo "[nats-bootstrap] NATS server installed: $(nats-server --version)"

# ── NATS configuration ───────────────────────────────────────────────────────
# Single-node server. Listens on all interfaces within the VPC.
# JetStream disabled for the POC (stateless pub/sub only).
mkdir -p /etc/nats

cat > /etc/nats/nats-server.conf <<NATSCONF
# FleetMind NATS server — fleet: $${FLEET_NAME}
# Single-node, no auth for VPC-internal use. Add TLS + creds for production.

server_name = "$${FLEET_NAME}-nats"

# Listen on all interfaces within the VPC; port 4222 is the standard NATS port.
host = "0.0.0.0"
port = 4222

# Cluster monitoring port (internal; security group blocks external access).
http_port = 8222

# Log to systemd journal
log_time = false

# Connection limits — generous for a fleet of bots.
max_connections = 1024
max_payload     = 1MB

# Ping keep-alive: disconnect idle clients after ~3 missed pings.
ping_interval = "20s"
ping_max      = 3
NATSCONF

# ── systemd service ──────────────────────────────────────────────────────────
cat > /etc/systemd/system/nats.service <<SYSD
[Unit]
Description=NATS Server (FleetMind $${FLEET_NAME})
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/nats-server -c /etc/nats/nats-server.conf
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nats

[Install]
WantedBy=multi-user.target
SYSD

systemctl daemon-reload
systemctl enable --now nats.service

echo "[nats-bootstrap] NATS server started."
systemctl status nats.service --no-pager
