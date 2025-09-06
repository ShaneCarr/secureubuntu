#!/usr/bin/env bash
set -euo pipefail

echo "[+] Updating packages and installing dependencies..."
sudo apt update -y
sudo apt install -y ufw

echo "[+] Enabling systemd-resolved (already included in Pop!_OS)..."
sudo systemctl enable --now systemd-resolved

echo "[+] Forcing NetworkManager not to override DNS..."
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/90-dns-none.conf >/dev/null <<'EOF'
[main]
dns=none
EOF
sudo systemctl restart NetworkManager

echo "[+] Configuring DNS over TLS with trusted resolvers (by IP only)..."
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dot.conf >/dev/null <<'EOF'
[Resolve]
# --- Secure DNS resolvers (DoT on TCP/853) ---
# Mullvad (Ad-blocking, privacy-focused, Sweden)
DNS=194.242.2.2 194.242.2.3

# AdGuard (Ad-blocking, tracker blocking, Cyprus/Russia infra)
DNS=94.140.14.14 94.140.15.15

# Quad9 (Malware blocking, nonprofit, Switzerland)
DNS=9.9.9.9 149.112.112.112

# Cloudflare (Privacy-first, very fast, USA-based)
DNS=1.1.1.1 1.0.0.1

# NextDNS (Customizable profiles, privacy-focused)
DNS=45.90.28.0 45.90.30.0

# Enforce DNS over TLS
DNSOverTLS=yes
EOF

echo "[+] Pointing resolv.conf to systemd stub..."
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "[+] Restarting systemd-resolved..."
sudo systemctl restart systemd-resolved

echo "[+] Setting up firewall rules..."
# Initialize firewall defaults
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Block plaintext DNS (both TCP+UDP)
sudo ufw deny out 53 || true

# Block DoT over UDP (force TCP only)
sudo ufw deny out 853/udp || true

# Allow DoT over TCP
sudo ufw allow out 853/tcp || true

# (Optional) allow SSH if you use it
# sudo ufw allow 22/tcp

# Enable firewall if not already active
if ! sudo ufw status | grep -q "Status: active"; then
  echo "[+] Enabling UFW firewall..."
  sudo ufw --force enable
fi

echo "[+] Firewall status:"
sudo ufw status verbose

echo "[+] Sanity checks..."
echo "--- resolvectl ---"
resolvectl status | head -n 30 || true
echo "--- active DoT sessions (TCP/853) ---"
sudo ss -tupn | grep ':853' || echo "No DNS queries yet. Open a webpage to test."

echo "[✓] Secure DNS over TLS + Firewall setup complete for Pop!_OS."
