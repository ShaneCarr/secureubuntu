#!/usr/bin/env bash
# Secure firewall setup with ProtonVPN + Steam + BG3 LAN

set -euo pipefail

echo "[+] Resetting UFW rules..."
sudo ufw --force reset

echo "[+] Default deny incoming, allow outgoing..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[+] Block plaintext DNS (53/tcp+udp), only allow DoT (853/tcp)..."
sudo ufw deny out 53
sudo ufw deny out 53/tcp
sudo ufw deny out 53/udp
sudo ufw allow out 853/tcp

echo "[+] ProtonVPN bootstrap ports..."
sudo ufw allow out 51820/udp   # WireGuard
sudo ufw allow out 1194/udp    # OpenVPN
sudo ufw allow out 1194/tcp
sudo ufw allow out 443/tcp     # TLS-based OpenVPN

echo "[+] Steam / gaming ports..."
sudo ufw allow out 27000:27100/udp
sudo ufw allow out 27015:27050/udp

echo "[+] BG3 + Larian LAN (TCP/UDP 23243–23252, LAN only)..."
sudo ufw allow from 192.168.0.0/16 to any port 23243:23252 proto tcp
sudo ufw allow from 192.168.0.0/16 to any port 23243:23252 proto udp

echo "[+] Enable UFW..."
sudo ufw --force enable
sudo ufw status verbose
