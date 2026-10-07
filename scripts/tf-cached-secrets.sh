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
# The same subcommands are also SERIALISED per module directory, with an flock
# held for the lifetime of the terraform process. The local backend provides no
# usable locking of its own: state lives on NFS from the NAS, where flock is
# advisory at best, and several Claude Code sessions run on this host at once.
# Two concurrent applies against one state file is how state gets corrupted.
#
# The lock is per module directory, so different modules still run in parallel.
# A run that cannot get the lock within TF_LOCK_TIMEOUT seconds fails and names
# the holder rather than waiting forever. TF_SKIP_LOCK=1 bypasses it, which is
# for recovering from a stale lock and nothing else.
#
# SECURITY: values live only in this process environment and the 0600
# cache files. They are never printed. Root module input variables are not
# persisted to terraform state, but a saved plan file (plan -out=...) does
# contain them, so treat *.tfplan files as secrets.

set -euo pipefail

ANSIBLE_QUASARLAB_DIR="${ANSIBLE_QUASARLAB_DIR:-/var/lib/ansible-quasarlab/repo}"
# These credentials rarely rotate, so refresh weekly instead of the
# library default of 48h. Delete the tf_* cache files to force a refresh.
export OP_SECRET_CACHE_TTL_SECS="${OP_SECRET_CACHE_TTL_SECS:-604800}"
PVE_OP_ITEM="${PVE_OP_ITEM:-op://Infrastructure/Proxmox API}"

# Serialisation. The directory is deliberately outside the repo and outside the
# NFS-mounted state tree: a lock file is only useful if flock on it is real.
TF_LOCK_DIR="${TF_LOCK_DIR:-${XDG_RUNTIME_DIR:-/tmp}/tf-quasarlab-locks}"
TF_LOCK_TIMEOUT="${TF_LOCK_TIMEOUT:-600}"

# Cache slugs are namespaced by item so a PVE_OP_ITEM override can never be
# served another item's cached credentials. The tag is the first 16 hex
# characters of sha256 over the exact reference string.
# SECURITY: slugs become file names and show up in logs, so they carry only
# this hash, never the reference itself.
item_cache_tag() {
    local tag
    tag=$(printf '%s' "$1" | sha256sum) || return 1
    tag="${tag:0:16}"
    [[ "$tag" =~ ^[0-9a-f]{16}$ ]] || return 1
    printf '%s' "$tag"
}

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

    local tag
    if ! tag=$(item_cache_tag "$PVE_OP_ITEM"); then
        echo "ERROR: could not derive a cache tag for PVE_OP_ITEM (is sha256sum installed?)" >&2
        return 1
    fi

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
TF_VAR_pm_user         tf_pve_username.${tag}      ${PVE_OP_ITEM}/username
TF_VAR_pm_password     tf_pve_password.${tag}      ${PVE_OP_ITEM}/password
TF_VAR_ci_username     tf_ci_username.${tag}       ${PVE_OP_ITEM}/Cloud-Init/ci_username
TF_VAR_ci_password     tf_ci_password.${tag}       ${PVE_OP_ITEM}/Cloud-Init/ci_password
TF_VAR_ssh_public_key  tf_ssh_public_key.${tag}    ${PVE_OP_ITEM}/Cloud-Init/ssh_public_key
EOF_SECRETS
    return "$missing"
}

# The module directory this invocation will act on. -chdir is terraform's own
# flag and changes which state is touched, so it has to key the lock too.
target_dir() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -chdir=*) (cd "${arg#-chdir=}" 2>/dev/null && pwd) && return 0 ;;
        esac
    done
    pwd
}

# flock holds the lock on an open file descriptor, so opening it here and then
# exec'ing terraform keeps it held for terraform's whole run and releases it when
# terraform exits, however it exits. No trap to get wrong, no stale lock after a
# kill -9.
take_lock() {
    local dir key lockfile
    dir="$(target_dir "$@")"
    key="$(printf '%s' "$dir" | sha256sum | cut -c1-16)"
    mkdir -p "$TF_LOCK_DIR" || return 1
    lockfile="${TF_LOCK_DIR}/${key}.lock"

    exec {TF_LOCK_FD}>>"$lockfile" || return 1
    if ! flock -w "$TF_LOCK_TIMEOUT" "$TF_LOCK_FD"; then
        echo "ERROR: another terraform run is holding ${dir}" >&2
        echo "       waited ${TF_LOCK_TIMEOUT}s. Holder recorded in ${lockfile}:" >&2
        sed 's/^/       /' "$lockfile" >&2
        echo "       Set TF_SKIP_LOCK=1 only if that holder is gone." >&2
        return 1
    fi
    # Overwrite rather than append: the file is a who-holds-it note, not a log.
    printf 'pid=%s user=%s dir=%s started=%s cmd=terraform %s\n' \
        "$$" "${USER:-$(id -un)}" "$dir" "$(date -Is)" "$*" >&"$TF_LOCK_FD"
    return 0
}

if needs_credentials "$@"; then
    if [[ "${TF_SKIP_LOCK:-}" == 1 ]]; then
        echo "WARNING: TF_SKIP_LOCK=1, running without serialisation" >&2
    elif ! take_lock "$@"; then
        exit 1
    fi
    load_credentials
fi

exec terraform "$@"
