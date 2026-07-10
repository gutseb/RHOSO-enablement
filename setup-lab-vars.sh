#!/usr/bin/env bash
# setup-lab-vars.sh — Import lab portal Details variables into vars.yml.
#
# Usage:
#   Interactive (paste then Ctrl+D):
#     bash setup-lab-vars.sh
#
#   From a saved file:
#     bash setup-lab-vars.sh < my-lab-exports.txt
#
# The script maps portal env-var names to Ansible variable names and
# updates inventory/group_vars/all/vars.yml in-place.
set -euo pipefail

VARS_FILE="inventory/group_vars/all/vars.yml"

if [ ! -f "$VARS_FILE" ]; then
    echo "ERROR: $VARS_FILE not found. Run this script from the repo root."
    exit 1
fi

echo "=== RHOSO Lab — Import Portal Variables ==="
echo ""

if [ -t 0 ]; then
    # stdin is a terminal — prompt the user to paste
    echo "Paste the 'export ...' block from your lab Details tab."
    echo "Press Ctrl+D on a blank line when done."
    echo ""
fi

UPDATED=0

while IFS= read -r line || [[ -n "${line:-}" ]]; do
    # Match lines of the form: [export] KEY=VALUE
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Z_][A-Z0-9_]*)=(.+)$ ]]; then
        key="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[3]}"

        # Strip surrounding quotes from the value if present
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"

        # Map portal export name → Ansible variable name
        case "$key" in
            EXTERNAL_IP_WORKER_1) ansible_var="external_ip_worker_1" ;;
            EXTERNAL_IP_WORKER_2) ansible_var="external_ip_worker_2" ;;
            EXTERNAL_IP_WORKER_3) ansible_var="external_ip_worker_3" ;;
            EXTERNAL_IP_BASTION)  ansible_var="external_ip_bastion"  ;;
            PUBLIC_NET_START)     ansible_var="public_net_start"      ;;
            PUBLIC_NET_END)       ansible_var="public_net_end"        ;;
            CONVERSION_HOST_IP)   ansible_var="conversion_host_ip"    ;;
            *) continue ;;
        esac

        # Replace the variable line in vars.yml (top-level vars only)
        sed -i "s|^${ansible_var}:.*|${ansible_var}: \"${value}\"|" "$VARS_FILE"

        # sed exits 0 even when nothing matched — confirm the line now exists
        if grep -qE "^${ansible_var}: \"${value}\"" "$VARS_FILE"; then
            echo "  Set: ${ansible_var} = ${value}"
            ((UPDATED++)) || true
        else
            echo "  WARNING: ${ansible_var} not found in ${VARS_FILE} — add it manually"
        fi
    fi
done

echo ""
if [ "$UPDATED" -eq 0 ]; then
    echo "WARNING: No recognised variables found in input."
    echo ""
    echo "Expected lines like:"
    echo "  export EXTERNAL_IP_WORKER_1=192.168.10.80"
    echo "  export PUBLIC_NET_START=192.168.10.84"
    exit 1
else
    echo "Updated ${UPDATED} variable(s) in ${VARS_FILE}"
    echo ""
    echo "Verify:"
    grep -E '^(external_ip_|public_net_|conversion_host_ip)' "$VARS_FILE"
fi
