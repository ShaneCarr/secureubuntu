# 🛡️ Secure DNS + Firewall + ProtonVPN Setup (Linux)

This guide configures **secure DNS-over-TLS (DoT)** with multiple fallback resolvers, a hardened firewall that blocks plaintext DNS leaks, and ProtonVPN integration.

---

## 1. Ensure systemd-resolved is in use

Make sure your system uses `systemd-resolved` for DNS resolution:

```bash
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

---

## 2. Configure Secure DNS (DoT)

Create the override file:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/99-secure-dns.conf >/dev/null <<'EOF'
[Resolve]
# Cloudflare (fast, privacy-focused)
DNS=1.1.1.1 1.0.0.1 \
# Quad9 (nonprofit, Switzerland)
    9.9.9.9 149.112.112.112 \
# UncensoredDNS (privacy activist, Denmark)
    91.239.100.100 89.233.43.71 \
# Mullvad DNS (privacy-first, Sweden)
    194.242.2.2 194.242.2.3

DNSOverTLS=yes
Domains=~.
LLMNR=no
MulticastDNS=no
FallbackDNS=
EOF
```

Restart systemd-resolved:

```bash
sudo systemctl restart systemd-resolved
```

Verify:

```bash
resolvectl status
```

---

## 3. Prevent NetworkManager from overriding DNS

Edit `/etc/NetworkManager/NetworkManager.conf` and add:

```
[main]
dns=none
```

Restart NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

---

## 4. Harden Firewall (block plaintext DNS)

Block all plaintext DNS (port 53), allow DNS-over-TLS (port 853):

```bash
# Block plaintext DNS
sudo iptables -A OUTPUT -p udp --dport 53 -j REJECT
sudo iptables -A OUTPUT -p tcp --dport 53 -j REJECT

# Allow DNS-over-TLS
sudo iptables -A OUTPUT -p tcp --dport 853 -j ACCEPT
```

---

## 5. ProtonVPN Integration

ProtonVPN uses WireGuard or OpenVPN. Allow VPN handshake ports.

```bash
# WireGuard (UDP 51820)
sudo iptables -A OUTPUT -p udp --dport 51820 -j ACCEPT

# OpenVPN (UDP/TCP 1194, TCP 443)
sudo iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 1194 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# ProtonVPN API (optional)
sudo iptables -A OUTPUT -p tcp --dport 443 -d api.protonvpn.ch -j ACCEPT
```

Configure ProtonVPN to use its own DNS when active:

```bash
protonvpn-cli config dns true
```

---

## 6. Tests

Check your DNS and VPN setup:

```bash
# Confirm DNS resolver list
resolvectl status

# Confirm Cloudflare resolves
dig whoami.cloudflare TXT +short @1.1.1.1

# Confirm ProtonVPN IP when connected
curl https://am.i.mullvad.net/ip
```

---

## ✅ End Result

- Always-on **secure DNS-over-TLS** with Cloudflare, Quad9, UncensoredDNS, Mullvad.  
- Firewall blocks plaintext DNS, only allows DoT + VPN handshakes.  
- ProtonVPN uses its own DNS inside the tunnel, falls back to DoT when off.
