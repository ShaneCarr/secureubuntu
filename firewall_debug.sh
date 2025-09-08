#!/usr/bin/env bash
# Comprehensive privacy + firewall check for ProtonVPN setup

set -euo pipefail
set +H   # disable Zsh history expansion (important!)

green() { echo -e "\033[1;32m[+] $*\033[0m"; }
red()   { echo -e "\033[1;31m[!] $*\033[0m"; }
sep()   { echo -e "\n\033[1;34m--- $* ---\033[0m"; }

sep "1. Check external IP + ASN (VPN active?)"
curl -s https://ipinfo.io/json | jq || curl -s https://ipinfo.io

sep "2. Check DNS resolution (resolvectl)"
resolvectl status | grep -A5 'Global' || true

sep "3. Run DNS leak test against multiple providers"
domains=("whoami.cloudflare" "resolver.dnscrypt.info")
servers=("1.1.1.1" "9.9.9.9")
for d in "${domains[@]}"; do
  for s in "${servers[@]}"; do
    green "Testing $d via $s ..."
    dig @"$s" +short txt "$d" || true
  done
done

sep "4. Confirm blocked plaintext DNS (53/tcp+udp)"
for proto in tcp udp; do
  if nc -z -w2 -$proto 127.0.0.1 53 2>/dev/null; then
    red "Port 53/$proto appears OPEN (leak risk)"
  else
    green "Port 53/$proto blocked ✅"
  fi
done

sep "5. Confirm DoT (853/tcp) allowed"
nc -zv 1.1.1.1 853 && green "DoT works ✅" || red "DoT blocked ❌"

sep "6. ProtonVPN ports allowed (firewall rules)?"
for port in "51820/udp" "1194/udp" "1194/tcp" "443/tcp"; do
  proto="${port#*/}"
  dport="${port%/*}"
  if sudo iptables -C OUTPUT -p "$proto" --dport "$dport" -j ACCEPT 2>/dev/null; then
    echo "[+] $port allowed ✅"
  else
    echo "[!] $port not explicitly allowed (may fail)"
  fi
done

sep "7. Steam / Game ports open?"
for p in 27015 27036 23243; do
  nc -zvu -w2 127.0.0.1 "$p" 2>/dev/null && green "Port $p reachable" || green "Port $p closed (normal unless game running)"
done

sep "8. Outbound firewall rules snapshot"
sudo ufw status verbose || sudo iptables -L -v -n --line-numbers

sep "9. Scan listening services (local ports)"
sudo ss -tulwn

green "Test complete. Review above for ✅ vs ❌"
