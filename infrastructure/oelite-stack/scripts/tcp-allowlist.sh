#!/bin/bash
# OElite Remote Cluster — TCP Port Allowlist Manager
# Restricts public access to shared-infrastructure TCP ports on the cluster node.
# Kubernetes API (6443) and SSH (22) are always protected — never removed.
#
# Usage:
#   ./tcp-allowlist.sh <ENV> status      # show current node firewall state (SSH)
#   ./tcp-allowlist.sh <ENV> dry-run     # preview ufw commands (default, safe)
#   ./tcp-allowlist.sh <ENV> apply       # apply allowlist to the node via SSH
#   ./tcp-allowlist.sh <ENV> add-my-ip   # append this machine's public IP to the allowlist
#
# Files (per environment, gitignored, operator-local):
#   clusters/<ENV>/firewall-allowlist.conf   NODE_HOST, ports
#   clusters/<ENV>/allowlist.ips             one allowed CIDR per line (# comments ok)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"

ENV_NAME="${1:-}"
ACTION="${2:-dry-run}"

if [ -z "$ENV_NAME" ]; then
  echo "Usage: $0 <ENV> [status|dry-run|apply|add-my-ip]"
  echo "Environments: $(ls -1 "$STACK_DIR/clusters" 2>/dev/null | tr '\n' ' ')"
  exit 1
fi

CONF="$STACK_DIR/clusters/$ENV_NAME/firewall-allowlist.conf"
IPS="$STACK_DIR/clusters/$ENV_NAME/allowlist.ips"

if [ ! -f "$CONF" ]; then
  echo "[ERR] Config missing: $CONF"
  echo "Create it from: $SCRIPT_DIR/tcp-allowlist.conf.example"
  exit 1
fi

# shellcheck source=/dev/null
source "$CONF"

: "${NODE_HOST:?NODE_HOST required in $CONF (e.g. root@91.99.249.173)}"
SSH_PORT="${SSH_PORT:-22}"
API_PORT="${API_PORT:-6443}"
MANAGED_PORTS="${MANAGED_PORTS:-27017 5672 1883 6379 8123 9000 9092 9094 9200}"

if [ ! -f "$IPS" ]; then
  echo "[ERR] Allowlist missing: $IPS (one CIDR per line, e.g. 203.0.113.5/32)"
  exit 1
fi

# Read CIDRs (strip comments/blanks)
CIDRS=$(grep -vE '^\s*(#|$)' "$IPS" | tr '\n' ' ')
if [ -z "$(echo $CIDRS)" ]; then
  echo "[ERR] No CIDRs in $IPS — refusing to deny-all (would lock out access)"
  exit 1
fi

echo "=== TCP Allowlist — $ENV_NAME ==="
echo "  Node:       $NODE_HOST"
echo "  Protected:  SSH $SSH_PORT, K8s API $API_PORT"
echo "  Managed:    $MANAGED_PORTS"
echo "  Allowed:    $CIDRS"
echo ""

build_rules() {
  echo "ufw allow $SSH_PORT/tcp comment 'SSH (oelite allowlist)'"
  echo "ufw allow $API_PORT/tcp comment 'K8s API (oelite allowlist)'"
  for port in $MANAGED_PORTS; do
    for cidr in $CIDRS; do
      echo "ufw allow from $cidr to any port $port proto tcp comment 'oelite allowlist $cidr'"
    done
    echo "ufw deny $port/tcp comment 'oelite default-deny $port'"
  done
  echo "ufw --force enable"
}

case "$ACTION" in
  status)
    ssh -p "$SSH_PORT" "$NODE_HOST" "ufw status numbered" 2>&1
    ;;
  dry-run)
    echo "=== DRY RUN — ufw commands for $NODE_HOST ==="
    build_rules
    ;;
  apply)
    echo "Applying via SSH to $NODE_HOST ..."
    build_rules | while IFS= read -r cmd; do
      echo "+ $cmd"
      ssh -p "$SSH_PORT" "$NODE_HOST" "$cmd"
    done
    echo ""
    echo "[OK] Allowlist applied on $ENV_NAME. Verify: $0 $ENV_NAME status"
    echo "⚠️  Keep one SSH session open while applying, to confirm you retain access."
    ;;
  add-my-ip)
    MY_IP=$(curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://ifconfig.me)
    if [ -z "$MY_IP" ]; then echo "[ERR] Could not detect public IP"; exit 1; fi
    if grep -q "^$MY_IP/32" "$IPS"; then
      echo "[OK] $MY_IP/32 already in allowlist"
    else
      printf '%s/32\n' "$MY_IP" >> "$IPS"
      echo "[OK] Added $MY_IP/32 to $IPS"
    fi
    echo "     Run 'apply' to push to the node."
    ;;
  *)
    echo "Unknown action '$ACTION'. Use: status|dry-run|apply|add-my-ip"
    exit 1
    ;;
esac
