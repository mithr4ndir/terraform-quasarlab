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
# STUB_OP_SERVE=1 makes `op read <ref>` succeed with a value derived from
# the reference, so tests can tell which item a credential came from.
if [[ "${STUB_OP_SERVE:-}" == 1 && "${1:-}" == read ]]; then
    printf 'live:%s' "$2"
    exit 0
fi
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

# Slugs for the default item carry the first 16 hex characters of sha256
# over the reference. Computed here independently of the wrapper.
DEFAULT_ITEM='op://Infrastructure/Proxmox API'
OTHER_ITEM='op://Infrastructure/Proxmox API Staging'
DEFAULT_TAG="$(printf '%s' "$DEFAULT_ITEM" | sha256sum | cut -c1-16)"

seed_cache() {
    local slug
    for slug in tf_pve_username tf_pve_password tf_ci_username tf_ci_password tf_ssh_public_key; do
        printf 'value-of-%s' "$slug" > "$WORK/cache/${slug}.${DEFAULT_TAG}"
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
printf 'value-of-tf_pve_password' > "$WORK/cache/tf_pve_password.${DEFAULT_TAG}"
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

# 7. Overriding PVE_OP_ITEM never serves the default item's cached values.
#    The override name shares a prefix with the default on purpose.
find "$WORK/cache" -mindepth 1 -delete
rm -f "$STUB_OP_LOG"
out="$(OP_SERVICE_ACCOUNT_TOKEN=dummy STUB_OP_SERVE=1 "$WRAPPER" plan 2>&1)"
if grep -qx "TF_VAR_pm_password=live:${DEFAULT_ITEM}/password" <<<"$out"; then
    pass "default item populates its cache from op"
else
    fail "default item populate: $out"
fi
rm -f "$STUB_OP_LOG"
out="$(PVE_OP_ITEM="$OTHER_ITEM" OP_SERVICE_ACCOUNT_TOKEN=dummy STUB_OP_SERVE=1 "$WRAPPER" plan 2>&1)"
if grep -qx "TF_VAR_pm_user=live:${OTHER_ITEM}/username" <<<"$out" \
    && grep -qx "TF_VAR_pm_password=live:${OTHER_ITEM}/password" <<<"$out" \
    && grep -qx "TF_VAR_ci_username=live:${OTHER_ITEM}/Cloud-Init/ci_username" <<<"$out" \
    && grep -qx "TF_VAR_ci_password=live:${OTHER_ITEM}/Cloud-Init/ci_password" <<<"$out" \
    && grep -qx "TF_VAR_ssh_public_key=live:${OTHER_ITEM}/Cloud-Init/ssh_public_key" <<<"$out" \
    && ! grep -q "live:${DEFAULT_ITEM}/" <<<"$out"; then
    pass "PVE_OP_ITEM override does not reuse the default item's cache"
else
    fail "override served another item's cache: $out"
fi

# 8. Both items now hit their own cache: op is never called, even though
#    live reads would succeed.
rm -f "$STUB_OP_LOG"
out_default="$(OP_SERVICE_ACCOUNT_TOKEN=dummy STUB_OP_SERVE=1 "$WRAPPER" plan 2>&1)"
out_other="$(PVE_OP_ITEM="$OTHER_ITEM" OP_SERVICE_ACCOUNT_TOKEN=dummy STUB_OP_SERVE=1 "$WRAPPER" plan 2>&1)"
if grep -qx "TF_VAR_pm_password=live:${DEFAULT_ITEM}/password" <<<"$out_default" \
    && grep -qx "TF_VAR_pm_password=live:${OTHER_ITEM}/password" <<<"$out_other" \
    && [[ ! -e "$STUB_OP_LOG" ]]; then
    pass "default and override items each hit their own cache"
else
    fail "cache hit per item (op log: $(cat "$STUB_OP_LOG" 2>/dev/null)): $out_default / $out_other"
fi

# 9. Cache file names (values and lock files) carry an item tag, never the
#    raw op:// reference or any part of it.
names="$(ls -A "$WORK/cache")"
slugs="$(ls "$WORK/cache")"
if ! grep -qiE 'op:|infrastructure|proxmox|staging|api| ' <<<"$names"; then
    pass "cache file names contain no raw item reference"
else
    fail "raw reference in cache file names: $names"
fi
if [[ "$(wc -l <<<"$slugs")" -eq 10 ]] \
    && ! grep -vqE '^tf_(pve_username|pve_password|ci_username|ci_password|ssh_public_key)\.[0-9a-f]{16}$' <<<"$slugs" \
    && [[ "$(cut -d. -f2 <<<"$slugs" | sort -u | wc -l)" -eq 2 ]]; then
    pass "each item gets its own five tagged slugs"
else
    fail "unexpected slug set: $slugs"
fi

# 10. Migration: legacy untagged tf_* entries from before item scoping are
#     never served. The first run refetches all five once, later runs hit
#     the tagged cache.
find "$WORK/cache" -mindepth 1 -delete
rm -f "$STUB_OP_LOG"
for slug in tf_pve_username tf_pve_password tf_ci_username tf_ci_password tf_ssh_public_key; do
    printf 'legacy-%s' "$slug" > "$WORK/cache/$slug"
done
out_first="$(OP_SERVICE_ACCOUNT_TOKEN=dummy STUB_OP_SERVE=1 "$WRAPPER" plan 2>&1)"
reads_first="$(grep -c '^read ' "$STUB_OP_LOG" 2>/dev/null || true)"
rm -f "$STUB_OP_LOG"
out_second="$(OP_SERVICE_ACCOUNT_TOKEN=dummy STUB_OP_SERVE=1 "$WRAPPER" plan 2>&1)"
if grep -qx "TF_VAR_pm_password=live:${DEFAULT_ITEM}/password" <<<"$out_first" \
    && ! grep -q 'legacy-' <<<"$out_first$out_second" \
    && [[ "$reads_first" == 5 ]] \
    && grep -qx "TF_VAR_pm_password=live:${DEFAULT_ITEM}/password" <<<"$out_second" \
    && [[ ! -e "$STUB_OP_LOG" ]]; then
    pass "legacy untagged entries are refetched exactly once"
else
    fail "legacy migration (first run reads=$reads_first): $out_first / $out_second"
fi

if (( failures > 0 )); then
    echo "${failures} test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
