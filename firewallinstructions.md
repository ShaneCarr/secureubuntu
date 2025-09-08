# Secure DNS Lockdown & Firewall Guide (Pop!_OS / Ubuntu)

This document explains **everything we did to lock down DNS on your machine**.  
It covers setup, how systemd-resolved, NetworkManager, and UFW interact, how to back up and restore configurations, and how to test.

---

## 🧩 The Strategy

- **Stub resolver**: systemd-resolved runs locally on `127.0.0.53`.
- **Recursive resolvers**: trusted upstream DNS servers (Mullvad, AdGuard, Quad9, Cloudflare, NextDNS).
- **/etc/resolv.conf**: symlinked to `/run/systemd/resolve/stub-resolv.conf`, forcing all apps to talk to systemd-resolved.
- **Firewall (UFW)**: blocks all plaintext DNS (port 53), allows only encrypted DNS-over-TLS (port 853/TCP).
- **NetworkManager override**: stopped from injecting Comcast/Xfinity DNS.

This ensures:
- Apps → `127.0.0.53` (systemd-resolved).
- systemd-resolved → upstream resolvers (DoT on 853/tcp only).
- Firewall prevents leaks via 53.

---

## 📂 Key Files

- `/etc/systemd/resolved.conf.d/dot.conf` → your DoT resolver config.
- `/run/systemd/resolve/stub-resolv.conf` → systemd-generated stub file (nameserver 127.0.0.53).
- `/etc/resolv.conf` → symlink to stub, so apps always go through systemd-resolved.
- `/etc/NetworkManager/conf.d/90-dns-none.conf` → disables NM from pushing ISP DNS.

---

## ⚙️ Setup Overview

### 1. Stop NetworkManager from overriding DNS
```bash
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/90-dns-none.conf >/dev/null <<'EOF'
[main]
dns=none
EOF
sudo systemctl restart NetworkManager
```

### 2. Configure systemd-resolved for DoT
```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dot.conf >/dev/null <<'EOF'
[Resolve]
# Mullvad (Ad-blocking, Sweden)
DNS=194.242.2.2 194.242.2.3

# AdGuard (Ad-blocking, Cyprus/Russia infra)
DNS=94.140.14.14 94.140.15.15

# Quad9 (Malware blocking, Switzerland)
DNS=9.9.9.9 149.112.112.112

# Cloudflare (Fast, privacy-first, USA-based)
DNS=1.1.1.1 1.0.0.1

# NextDNS (Customizable, privacy-focused)
DNS=45.90.28.0 45.90.30.0

DNSOverTLS=yes
EOF
```

### 3. Point resolv.conf to the stub
```bash
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
```

### 4. Configure UFW firewall rules
```bash
# Block all plaintext DNS
sudo ufw deny out 53

# Block DoT over UDP
sudo ufw deny out 853/udp

# Allow DoT over TCP
sudo ufw allow out 853/tcp

# (Optional) Allow SSH
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable
```

---

## 🔒 Backup & Restore

### Backup UFW rules
```bash
sudo ufw status numbered > ~/ufw-rules-backup.txt
```

### Restore UFW rules
```bash
sudo ufw reset
# Reapply rules manually using backup as reference
```

### Backup systemd-resolved config
```bash
sudo cp -r /etc/systemd/resolved.conf.d ~/resolved-backup
```

### Restore systemd-resolved config
```bash
sudo cp -r ~/resolved-backup/* /etc/systemd/resolved.conf.d/
sudo systemctl restart systemd-resolved
```

### Backup NetworkManager config
```bash
sudo cp -r /etc/NetworkManager/conf.d ~/nm-backup
```

### Restore NetworkManager config
```bash
sudo cp -r ~/nm-backup/* /etc/NetworkManager/conf.d/
sudo systemctl restart NetworkManager
```

---

## 🛡 VPN Compatibility

If you use a VPN:
- Allow the VPN tunnel through UFW (usually `tun0` or `wg0`).
- Example for WireGuard (UDP 51820):
```bash
sudo ufw allow 51820/udp
```

Strategy:
- Firewall still blocks DNS on port 53.
- VPN provider supplies its own DNS, or your VPN DNS queries are tunneled inside the VPN — safe.

---

## ✅ Testing

### Firewall rules
```bash
sudo ufw status numbered
```

Expected:
```
53        DENY OUT
853/udp   DENY OUT
853/tcp   ALLOW OUT
```

### Plaintext DNS must fail
```bash
dig @1.1.1.1 example.com
```
Expected: `no servers could be reached`.

### Stub resolver must work
```bash
dig @127.0.0.53 example.com
```

Expected: valid A/AAAA records.

### DoT connections must be active
```bash
sudo ss -tupn | grep ':853'
```

Expected: `systemd-resolved` connected to Mullvad/AdGuard/Quad9/Cloudflare.

### Check resolvers
```bash
resolvectl status
```

Expected: only your configured IPs, not Comcast DNS.

---

## 🛠 Troubleshooting

- **No DNS working?**
  Temporarily re-enable port 53:
  ```bash
  sudo ufw delete deny out 53
  ```

- **NetworkManager still showing ISP DNS in resolvectl?**
  Make sure `/etc/NetworkManager/conf.d/90-dns-none.conf` exists and restart both NM and resolved.

- **Reset everything if broken:**
  ```bash
  sudo ufw reset
  sudo ufw enable
  sudo rm -rf /etc/systemd/resolved.conf.d/*
  sudo systemctl restart systemd-resolved
  ```

---

## 📌 Summary

- All apps use `/etc/resolv.conf` → `127.0.0.53` (systemd-resolved stub).
- systemd-resolved forwards securely to trusted DoT resolvers on port 853/tcp.
- UFW firewall blocks plaintext DNS leaks.  
- NetworkManager override stops ISP DNS injection.  
- Backups make it easy to restore firewall and DNS configs.  
- VPN can be allowed while still forcing secure DNS.

**Result: Comcast/Xfinity can’t see or intercept your DNS anymore.**
