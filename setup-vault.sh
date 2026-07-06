#!/usr/bin/env bash
# setup-vault.sh — First-time vault setup for RHOSO lab students.
#
# Copies vault_template.yml to the live vault location, opens it in $EDITOR,
# then prompts the student to encrypt it with ansible-vault.
#
# Run once before starting the lab: bash setup-vault.sh
set -euo pipefail

VAULT_DEST="inventory/group_vars/all/vault.yml"
VAULT_TEMPLATE="vault_template.yml"

echo "=== RHOSO Lab — Vault Setup ==="
echo ""

if [ ! -f "$VAULT_TEMPLATE" ]; then
    echo "ERROR: $VAULT_TEMPLATE not found. Run this from the repo root."
    exit 1
fi

if [ -f "$VAULT_DEST" ]; then
    echo "WARNING: $VAULT_DEST already exists."
    read -rp "  Overwrite? [y/N] " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

cp "$VAULT_TEMPLATE" "$VAULT_DEST"
echo "  Copied template to $VAULT_DEST"
echo ""

echo "Opening $VAULT_DEST in your editor — fill in your lab credentials."
echo "  (Set EDITOR env var to change editor, default: vi)"
echo ""
read -rp "Press Enter to open the file..."
${EDITOR:-vi} "$VAULT_DEST"

echo ""
echo "--- Encrypting vault ---"
echo "You will be prompted to create a vault password."
echo "Remember this password — you'll need it every time you run playbooks."
echo ""
ansible-vault encrypt "$VAULT_DEST"

echo ""
echo "=== Vault setup complete ==="
echo ""
echo "To run playbooks, use one of:"
echo "  ansible-playbook playbooks/site.yml --ask-vault-pass"
echo "  ansible-playbook playbooks/site.yml --vault-password-file .vault_password"
echo ""
echo "To edit the vault later:"
echo "  ansible-vault edit $VAULT_DEST"
