#!/usr/bin/env bash
# secure-net.sh — Harden DNS + Firewall for Ubuntu/Pop!_OS
# Defaults: DNS=Cloudflare+Quad9, Samba allowed on LAN, NFS off, SSH off
# Usage examples:
#   sudo bash secure-net.sh
#   sudo bash secure-net.sh --dns "1.1.1.1 1.0.0.1 9.9.9.9" --lan-cidr 192.168.0.0/16 --allow-nfs --allow-ssh
#   sudo bash secure-net.sh --no-samba

set -euo pipefail

DNS_SERVERS="1.1.1.1 1.0.0.1 9.9.9.9"   # Default: Cloudflare + Quad9 (no Google)
LAN_CIDR="192.168.0.0/16"
ALLOW_SAMBA=1
ALLOW_NFS=0
ALLOW_SSH=0

log() { printf "\033[1;34m[secure-net]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[secure-net]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[secure-net]\033[0m %s\n" "$*" >&2; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Please run as root: sudo $0 [options]"
    exit 1
  fi
}

backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  cp -a "$f" "${f}.bak.$(date +%Y%m%d-%H%M%S)"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dns)           DNS_SERVERS="$2"; shift 2 ;;
      --lan-cidr)      LAN_CIDR="$2"; shift 2 ;;
      --allow-samba)   ALLOW_SAMBA=1; shift 1 ;;
      --no-samba)      ALLOW_SAMBA=0; shift 1 ;;
      --allow-nfs)     ALLOW_NFS=1; shift 1 ;;
      --allow-ssh)     ALLOW_SSH=1; shift 1 ;;
      --help|-h)
        cat <<USAGE
Usage: sudo bash $0 [options]

Options:
  --dns "X Y Z"       Space-separated DNS servers (default: "$DNS_SERVERS")
  --lan-cidr CIDR     LAN CIDR allowed to reach filesharing (default: $LAN_CIDR)
  --allow-samba       Allow Samba/CIFS from LAN (default: ON)
  --no-samba          Do not allow Samba
  --allow-nfs         Allow NFS from LAN (default: OFF)
  --allow-ssh         Allow SSH from LAN (default: OFF)
USAGE
        exit 0
        ;;
      *)
        err "Unknown option: $1"; exit 2 ;;
    esac
  done
}

ensure_packages() {
  log "Ensuring base packages present (ufw, network-manager, systemd-resolved, dnsutils)..."
  # On Ubuntu/Pop these are present, but we'll be explicit & quiet.
  apt-get update -qq || true
  apt-get install -y -qq ufw network-manager systemd-resolved dnsutils tcpdump >/dev/null
}

configure_resolved() {
  log "Configuring systemd-resolved for DNS-over-TLS..."
  mkdir -p /etc/systemd/resolved.conf.d

  local conf="/etc/systemd/resolved.conf.d/99-securedns.conf"
  backup_file "$conf"
  cat > "$conf" <<CONF
[Resolve]
DNS=${DNS_SERVERS}
DNSOverTLS=yes
# Harden local name-resolution exposure:
LLMNR=no
MulticastDNS=no
# Force global resolvers for all lookups:
Domains=~.
CONF

  # Ensure resolv.conf points at the stub (127.0.0.53)
  if [[ ! -L /etc/resolv.conf ]]; then
    warn "/etc/resolv.conf is not a symlink; fixing to systemd stub..."
    backup_file /etc/resolv.conf
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  fi

  systemctl enable systemd-resolved >/dev/null 2>&1 || true
  systemctl restart systemd-resolved
}

configure_nm() {
  if ! command -v nmcli >/dev/null 2>&1; then
    warn "NetworkManager not found; skipping NM configuration."
    return
  fi

  log "Pointing NetworkManager at systemd-resolved..."
  local nmconf="/etc/NetworkManager/NetworkManager.conf"
  touch "$nmconf"
  backup_file "$nmconf"

  if ! grep -q '^\[main\]' "$nmconf"; then
    printf "\n[main]\n" >> "$nmconf"
  fi

  if grep -q '^dns=' "$nmconf"; then
    sed -i 's/^dns=.*/dns=systemd-resolved/' "$nmconf"
  else
    sed -i '/^\[main\]/a dns=systemd-resolved' "$nmconf"
  fi

  log "Instructing all ethernet/wifi connections to ignore DHCP DNS..."
  # For each connection, set ignore-auto-dns for IPv4/IPv6
  # Only touch ethernet/wifi types
  while IFS= read -r line; do
    # Format: NAME:UUID:TYPE:DEVICE
    IFS=":" read -r NAME UUID TYPE DEVICE <<<"$line"
    [[ "$TYPE" == "ethernet" || "$TYPE" == "wifi" ]] || continue
    nmcli connection modify "$UUID" ipv4.ignore-auto-dns yes || true
    nmcli connection modify "$UUID" ipv6.ignore-auto-dns yes || true
  done < <(nmcli -t -f NAME,UUID,TYPE,DEVICE connection show)

  systemctl restart NetworkManager
  # Bounce active ethernet/wifi connections to apply (best-effort)
  while IFS= read -r UUID; do
    nmcli -t -f UUID connection show --active | grep -q "$UUID" || continue
    nmcli connection down "$UUID" || true
    nmcli connection up "$UUID" || true
  done < <(nmcli -t -f UUID,TYPE connection show | awk -F: '$2=="ethernet"||$2=="wifi"{print $1}')
}

configure_ufw() {
  log "Configuring UFW (deny inbound, allow outbound; LAN-only file sharing)..."
  ufw --force reset >/dev/null 2>&1 || true

  ufw default deny incoming
  ufw default allow outgoing

  # Allow Samba from LAN (CIFS/SMB)
  if [[ $ALLOW_SAMBA -eq 1 ]]; then
    # UFW app profile 'Samba' should exist; fall back to explicit ports if not.
    if ufw app list | grep -qi '^samba$'; then
      ufw allow from "$LAN_CIDR" to any app Samba
    else
      # SMB ports: 137/udp,138/udp,139/tcp,445/tcp
      ufw allow from "$LAN_CIDR" to any port 137 proto udp
      ufw allow from "$LAN_CIDR" to any port 138 proto udp
      ufw allow from "$LAN_CIDR" to any port 139 proto tcp
      ufw allow from "$LAN_CIDR" to any port 445 proto tcp
    fi
  fi

  # Allow NFS from LAN (optional)
  if [[ $ALLOW_NFS -eq 1 ]]; then
    # Common NFS ports: 111/tcp+udp (rpcbind), 2049/tcp+udp (nfs)
    ufw allow from "$LAN_CIDR" to any port 111 proto tcp
    ufw allow from "$LAN_CIDR" to any port 111 proto udp
    ufw allow from "$LAN_CIDR" to any port 2049 proto tcp
    ufw allow from "$LAN_CIDR" to any port 2049 proto udp
    # If you pin mountd/statd/lockd ports in /etc/nfs.conf, add them here as well.
  fi

  # Allow SSH from LAN (optional)
  if [[ $ALLOW_SSH -eq 1 ]]; then
    ufw allow from "$LAN_CIDR" to any port 22 proto tcp
  fi

  ufw --force enable
}

verify() {
  log "Verification (resolvectl)..."
  resolvectl status || true

  log "Quick DNS test via stub (dig):"
  if command -v dig >/dev/null 2>&1; then
    dig +timeout=2 +tries=1 @127.0.0.53 one.one.one.one || true
  else
    warn "dig not installed (dnsutils). Install with: sudo apt install -y dnsutils"
  fi

  log "UFW rules:"
  ufw status verbose || true

  log "Tip: To observe DNS-over-TLS traffic in real-time:"
  echo "  sudo tcpdump -i any port 853"
}

main() {
  need_root
  parse_args "$@"
  log "Starting with DNS='$DNS_SERVERS', LAN='$LAN_CIDR', Samba=$( [[ $ALLOW_SAMBA -eq 1 ]] && echo ON || echo OFF ), NFS=$( [[ $ALLOW_NFS -eq 1 ]] && echo ON || echo OFF ), SSH=$( [[ $ALLOW_SSH -eq 1 ]] && echo ON || echo OFF )"
  ensure_packages
  configure_resolved
  configure_nm
  configure_ufw
  verify
  log "Done. Your system now uses DNS-over-TLS to ${DNS_SERVERS} and only allows LAN file sharing through the firewall."
}

main "$@"
