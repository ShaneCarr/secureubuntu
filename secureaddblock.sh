#!/usr/bin/env bash
set -euo pipefail

echo "[+] Updating packages and installing dependencies..."
sudo apt update -y
sudo apt install -y ufw systemd-resolved

echo "[+] Enabling systemd-resolved..."
sudo systemctl enable --now systemd-resolved

echo "[+] Configuring DNS over TLS with Mullvad + AdGuard (with Quad9 fallback)..."
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dot.conf >/dev/null <<'EOF'
[Resolve]
# Primary ad/tracker blocking resolvers (encrypted DoT)
DNS=adblock.dns.mullvad.net dns.adguard.com

# Fallback resolver (encrypted, malware protection)
FallbackDNS=dns.quad9.net

DNSOverTLS=yes
# Optional: DNSSEC validation (uncomment if desired)
# DNSSEC=allow-downgrade
EOF

echo "[+] Pointing resolv.conf to systemd stub..."
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "[+] Restarting systemd-resolved..."
sudo systemctl restart systemd-resolved

echo "[+] Setting up firewall rules..."
# Initialize firewall if not already enabled
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Block all plaintext DNS
sudo ufw delete deny out 53 2>/dev/null || true
sudo ufw deny out 53 comment 'Block plaintext DNS (UDP/TCP)'

# Block DoT over UDP (force TCP only)
sudo ufw delete deny out 853 proto udp 2>/dev/null || true
sudo ufw deny out 853 proto udp comment 'Block DoT over UDP (enforce TCP/TLS)'

# Allow DoT over TCP
sudo ufw delete allow out 853 proto tcp 2>/dev/null || true
sudo ufw allow out 853 proto tcp comment 'Allow DNS over TLS (TCP)'

# (Optional) allow SSH if you use it
# sudo ufw allow 22/tcp comment 'Allow SSH'

# Enable firewall if not already active
if ! sudo ufw status | grep -q "Status: active"; then
  echo "[+] Enabling UFW firewall..."
  sudo ufw --force enable
fi

echo "[+] Firewall status:"
sudo ufw status verbose

echo "[+] Sanity checks..."
resolvectl status | head -n 30 || true
echo "---"
sudo ss -tupn | grep ':853' || echo "No DNS queries seen yet. Open a webpage to test."

echo "[✓] Secure DNS + Firewall setup complete."
