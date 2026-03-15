#!/usr/bin/env bash
#
# Generate terraform.tfvars from 1Password for a given module.
# Usage: ./scripts/gen-tfvars.sh <module_dir> <pm_node>
# Example: ./scripts/gen-tfvars.sh proxmox/wazuh pve
#
set -euo pipefail

MODULE_DIR="${1:?Usage: $0 <module_dir> <pm_node>}"
PM_NODE="${2:?Usage: $0 <module_dir> <pm_node>}"

VAULT="Infrastructure"
PVE_ITEM="Proxmox VE API"

echo "Fetching credentials from 1Password..."
PM_USER=$(op read "op://${VAULT}/${PVE_ITEM}/username")
PM_PASS=$(op read "op://${VAULT}/${PVE_ITEM}/password")
CI_USER=$(op read "op://${VAULT}/${PVE_ITEM}/Cloud-Init/ci_username")
CI_PASS=$(op read "op://${VAULT}/${PVE_ITEM}/Cloud-Init/ci_password")
SSH_PUB=$(op read "op://${VAULT}/${PVE_ITEM}/Cloud-Init/ssh_public_key")
PM_API_URL="https://192.168.1.11:8006/api2/json"

cat > "${MODULE_DIR}/terraform.tfvars" <<EOF
pm_user        = "${PM_USER}"
pm_password    = "${PM_PASS}"
pm_api_url     = "${PM_API_URL}"
pm_node        = "${PM_NODE}"
ci_username    = "${CI_USER}"
ci_password    = "${CI_PASS}"
ssh_public_key = "${SSH_PUB}"
EOF

echo "Generated ${MODULE_DIR}/terraform.tfvars (pm_node=${PM_NODE})"
