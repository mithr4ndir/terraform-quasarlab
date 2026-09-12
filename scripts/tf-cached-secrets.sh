#!/usr/bin/env bash
# Runs terraform with the Proxmox API and cloud-init credentials exported
# as TF_VAR_* values served from the ansible-quasarlab 1Password file cache.
#
# Why: the wazuh and authentik root modules used to read 1Password through
# the onepassword provider on every plan, apply, and refresh. Those reads
# came out of the shared 1000/24h account quota. This wrapper reuses the
# ansible-quasarlab cache (/var/lib/ansible-quasarlab/secrets, mode 0600)
# and its rate-limit kill switch, so a plan costs zero 1Password reads
# while the cache is fresh.
#
# Usage (from a root module directory):
#     ../../scripts/tf-cached-secrets.sh plan
#     ../../scripts/tf-cached-secrets.sh apply
#
# Credentials are only loaded for subcommands that configure providers.
# fmt, validate, init and friends never touch the cache or op.
#
# SECURITY: values live only in this process environment and the 0600
# cache files. They are never printed. Root module input variables are not
# persisted to terraform state, but a saved plan file (plan -out=...) does
# contain them, so treat *.tfplan files as secrets.

set -euo pipefail

ANSIBLE_QUASARLAB_DIR="${ANSIBLE_QUASARLAB_DIR:-/var/lib/ansible-quasarlab/repo}"
# These credentials rarely rotate, so refresh weekly instead of the
# library default of 12h. Delete the tf_* cache files to force a refresh.
export OP_SECRET_CACHE_TTL_SECS="${OP_SECRET_CACHE_TTL_SECS:-604800}"
PVE_OP_ITEM="${PVE_OP_ITEM:-op://Infrastructure/Proxmox API}"

needs_credentials() {
    local arg
    for arg in "$@"; do
        [[ "$arg" == -* ]] && continue
        case "$arg" in
            plan | apply | destroy | refresh | import | console) return 0 ;;
            *) return 1 ;;
        esac
    done
    return 1
}

load_credentials() {
    local lib
    for lib in op-killswitch.sh op-secret-cache.sh; do
        if [[ ! -r "${ANSIBLE_QUASARLAB_DIR}/scripts/lib/${lib}" ]]; then
            echo "ERROR: ${lib} not found under ${ANSIBLE_QUASARLAB_DIR}/scripts/lib (set ANSIBLE_QUASARLAB_DIR)" >&2
            return 1
        fi
    done
    # shellcheck source=/dev/null
    source "${ANSIBLE_QUASARLAB_DIR}/scripts/lib/op-killswitch.sh"
    # shellcheck source=/dev/null
    source "${ANSIBLE_QUASARLAB_DIR}/scripts/lib/op-secret-cache.sh"

    local env_name slug op_path value missing=0
    while read -r env_name slug op_path; do
        # Fail closed: never hand terraform an empty credential.
        if ! value=$(cached_op_read "$slug" "$op_path") || [[ -z "$value" ]]; then
            echo "ERROR: no cached or live value for ${env_name} (cache slug ${slug})" >&2
            missing=1
            continue
        fi
        export "${env_name}=${value}"
    done <<EOF_SECRETS
TF_VAR_pm_user         tf_pve_username      ${PVE_OP_ITEM}/username
TF_VAR_pm_password     tf_pve_password      ${PVE_OP_ITEM}/password
TF_VAR_ci_username     tf_ci_username       ${PVE_OP_ITEM}/Cloud-Init/ci_username
TF_VAR_ci_password     tf_ci_password       ${PVE_OP_ITEM}/Cloud-Init/ci_password
TF_VAR_ssh_public_key  tf_ssh_public_key    ${PVE_OP_ITEM}/Cloud-Init/ssh_public_key
EOF_SECRETS
    return "$missing"
}

if needs_credentials "$@"; then
    load_credentials
fi

exec terraform "$@"
