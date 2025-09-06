#!/usr/bin/env bash
set -euo pipefail

green() { echo -e "\e[32m[✓]\e[0m $*"; }
red()   { echo -e "\e[31m[✗]\e[0m $*"; }

echo "=== Secure DNS Lockdown Test ==="

# 1. Firewall rules
echo "--- Checking UFW rules ---"
ufw_ok=true
if sudo ufw status | grep -q "53.*DENY OUT"; then
  green "Plain DNS (53) is blocked"
else
  red "Plain DNS (53) NOT blocked!"
  ufw_ok=false
fi
if sudo ufw status | grep -q "853/udp.*DENY OUT"; then
  green "DoT over UDP is blocked"
else
  red "DoT over UDP NOT blocked!"
  ufw_ok=false
fi
if sudo ufw status | grep -q "853/tcp.*ALLOW OUT"; then
  green "DoT over TCP is allowed"
else
  red "DoT over TCP NOT allowed!"
  ufw_ok=false
fi

# 2. Leak test: plaintext DNS should fail
echo "--- Testing direct plaintext DNS ---"
if dig @1.1.1.1 example.com +timeout=2 +tries=1 >/dev/null 2>&1; then
  red "Leak detected: Plaintext DNS worked!"
else
  green "No leak: Plaintext DNS is blocked"
fi

# 3. Stub resolver test
echo "--- Testing systemd-resolved stub ---"
if dig @127.0.0.53 example.com +short >/dev/null 2>&1; then
  green "Stub resolver (127.0.0.53) works"
else
  red "Stub resolver failed!"
fi

# 4. Active DoT connections
echo "--- Checking active DoT sessions (TCP/853) ---"
if sudo ss -tupn | grep -q ':853'; then
  green "systemd-resolved is using DoT (TCP/853)"
  sudo ss -tupn | grep ':853' | awk '{print "   "$0}'
else
  red "No DoT sessions found"
fi

# 5. Resolver list
echo "--- resolvectl status ---"
resolvectl status | head -n 25

echo "=== Test Complete ==="
