#!/usr/bin/env bash
# Tests for scripts/tf-cached-secrets.sh. Uses the real ansible-quasarlab
# cache and kill-switch libraries against a throwaway cache directory, with
# stub op, logger and terraform binaries on PATH. Never calls real op or
# terraform. Requires a local ansible-quasarlab checkout (ANSIBLE_QUASARLAB_DIR,
# default /var/lib/ansible-quasarlab/repo).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="${REPO_ROOT}/scripts/tf-cached-secrets.sh"
export ANSIBLE_QUASARLAB_DIR="${ANSIBLE_QUASARLAB_DIR:-/var/lib/ansible-quasarlab/repo}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin" "$WORK/cache" "$WORK/state"
cat > "$WORK/bin/op" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_OP_LOG"
exit 1
STUB
cat > "$WORK/bin/logger" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat > "$WORK/bin/terraform" <<'STUB'
#!/usr/bin/env bash
echo "args=$*"
for v in TF_VAR_pm_user TF_VAR_pm_password TF_VAR_ci_username TF_VAR_ci_password TF_VAR_ssh_public_key; do
    echo "${v}=${!v:-<unset>}"
done
STUB
chmod +x "$WORK/bin/"*

export PATH="$WORK/bin:$PATH"
export STUB_OP_LOG="$WORK/op.log"
export OP_SECRET_CACHE_DIR="$WORK/cache"
export OP_KILLSWITCH_STATE_DIR="$WORK/state"
export OP_KILLSWITCH_METRIC_FILE="$WORK/state/metric.prom"
unset OP_SERVICE_ACCOUNT_TOKEN TF_VAR_pm_user TF_VAR_pm_password TF_VAR_ci_username TF_VAR_ci_password TF_VAR_ssh_public_key

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }

seed_cache() {
    local slug
    for slug in tf_pve_username tf_pve_password tf_ci_username tf_ci_password tf_ssh_public_key; do
        printf 'value-of-%s' "$slug" > "$WORK/cache/$slug"
    done
}

# 1. Fresh cache: plan gets every credential and op is never called.
rm -f "$WORK/cache/"* "$STUB_OP_LOG"
seed_cache
out="$("$WRAPPER" plan -input=false 2>&1)"
if grep -qx 'args=plan -input=false' <<<"$out" \
    && grep -qx 'TF_VAR_pm_password=value-of-tf_pve_password' <<<"$out" \
    && grep -qx 'TF_VAR_ci_password=value-of-tf_ci_password' <<<"$out" \
    && grep -qx 'TF_VAR_ssh_public_key=value-of-tf_ssh_public_key' <<<"$out" \
    && [[ ! -e "$STUB_OP_LOG" ]]; then
    pass "fresh cache exports TF_VAR values without calling op"
else
    fail "fresh cache: $out"
fi

# 2. Global flags before the subcommand are skipped when detecting it.
out="$("$WRAPPER" -chdir=proxmox/wazuh apply 2>&1)"
if grep -qx 'TF_VAR_pm_user=value-of-tf_pve_username' <<<"$out"; then
    pass "-chdir before apply still loads credentials"
else
    fail "-chdir apply: $out"
fi

# 3. Commands that do not configure providers never touch the cache or op.
rm -f "$WORK/cache/"*
for cmd in fmt validate init; do
    if out="$("$WRAPPER" "$cmd" 2>&1)" && grep -qx 'TF_VAR_pm_password=<unset>' <<<"$out"; then
        pass "$cmd runs without loading credentials"
    else
        fail "$cmd: $out"
    fi
done

# 4. Missing cache and no op token: fail closed, terraform not run,
#    and the error output names the variable but never a value.
rm -f "$WORK/cache/"* "$STUB_OP_LOG"
printf 'value-of-tf_pve_password' > "$WORK/cache/tf_pve_password"
rc=0
out="$("$WRAPPER" plan 2>&1)" || rc=$?
if (( rc != 0 )) && ! grep -q '^args=' <<<"$out" \
    && grep -q 'TF_VAR_pm_user' <<<"$out" \
    && ! grep -q 'value-of-' <<<"$out" \
    && [[ ! -e "$STUB_OP_LOG" ]]; then
    pass "missing cache fails closed without leaking values"
else
    fail "missing cache (rc=$rc): $out"
fi

# 5. Stale cache with op unavailable: stale values are served, op not called.
seed_cache
touch -d '30 days ago' "$WORK/cache/"*
out="$("$WRAPPER" plan 2>&1)"
if grep -qx 'TF_VAR_ci_username=value-of-tf_ci_username' <<<"$out" && [[ ! -e "$STUB_OP_LOG" ]]; then
    pass "stale cache served when op is unavailable"
else
    fail "stale cache: $out"
fi

# 6. Missing ansible-quasarlab libraries: fail closed.
rc=0
out="$(ANSIBLE_QUASARLAB_DIR="$WORK/nope" "$WRAPPER" plan 2>&1)" || rc=$?
if (( rc != 0 )) && ! grep -q '^args=' <<<"$out"; then
    pass "missing libraries fail closed"
else
    fail "missing libraries (rc=$rc): $out"
fi

if (( failures > 0 )); then
    echo "${failures} test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
