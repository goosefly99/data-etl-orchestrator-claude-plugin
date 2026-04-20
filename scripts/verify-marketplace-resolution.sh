#!/usr/bin/env bash
#
# verify-marketplace-resolution.sh
# ===============================================================
# PLACEHOLDER SCRIPT — Phase 6 (R12 mitigation gate).
#
# Purpose
# -------
# Before the orchestrator v1.0.0 tag is cut, all three sibling plugins
# (agent-knowledgebase v0.6.0, youtube-mcp v0.5.0, x-api-mcp v0.4.0)
# must already be resolvable from the `goosefly99-plugins-auto-dev`
# marketplace. This script asserts that invariant and exits 0 only if
# every sibling latest version matches the expected floor. Any mismatch
# or UNRESOLVED response fails the gate.
#
# Status: PLACEHOLDER
# -------------------
# As of 2026-04-20, the `claude plugin query` CLI (or equivalent HTTP
# marketplace endpoint) does not yet exist. The script is wired to call
# it anyway so the interface stays correct once the CLI lands — but
# operators MUST run the manual-checklist fallback documented in
# `skills/references/release-gates.md` § "Marketplace-resolution
# verification (Phase 6 sub-task, R12)" until the CLI is confirmed.
#
# Manual fallback (one-sentence summary):
#   Open the goosefly99-plugins-auto-dev marketplace entry for each of
#   the three sibling plugins; confirm latest published version matches
#   the expected floor below; then do a clean install in a fresh
#   ~/.claude/plugins/ and run probes 1-3 from contract-probe-protocol.md.
#   Log the decision + timestamp + operator in cron-log.md.
#
# Platform note
# -------------
# This is a Bash script (`#!/usr/bin/env bash`). On Windows, run via
# Git Bash or WSL — PowerShell is not supported directly. A PowerShell
# port may follow once the marketplace CLI lands and the interface is
# stable.
#
# Exit codes
# ----------
#   0  — all three siblings resolved at their expected version floor.
#   1  — at least one sibling mismatched or UNRESOLVED; gate fails.
#   2  — script misuse (missing dependencies, bad env).
#
# Usage
# -----
#   ./scripts/verify-marketplace-resolution.sh
#
# No arguments — the expected floors are hardcoded below to match the
# probe-4 upgrade-sibling error message (kb 0.6.0 / yt 0.5.0 /
# x-api 0.4.0). Update the EXPECTED map + this header comment in the
# same commit if the floors ever change.
#
# ===============================================================

set -euo pipefail

MARKETPLACE="goosefly99-plugins-auto-dev"

# Expected version floors — character-for-character match with
# skills/references/contract-probe-protocol.md L120 and L112-114.
declare -A EXPECTED=(
  ["agent-knowledgebase"]="0.6.0"
  ["youtube-mcp"]="0.5.0"
  ["x-api-mcp"]="0.4.0"
)

FAIL=0

# Placeholder for the marketplace query. Replace the body of query_marketplace
# with the real CLI invocation once confirmed — the current implementation
# emits UNRESOLVED unconditionally so the script fails closed (R12 gate is
# designed to fail closed until actual resolution can be verified).
query_marketplace() {
  local plugin="$1"
  # TODO(phase-6-cutover): replace with the real marketplace query once
  # the `claude plugin query` CLI (or equivalent) is confirmed. Current
  # placeholder prints UNRESOLVED so every call fails until wired up.
  if command -v claude >/dev/null 2>&1; then
    # NOTE: all CLI failures (auth, bad flags, network, missing plugin) echo UNRESOLVED.
    # If the gate fails unexpectedly, re-run with `claude plugin query ...` directly to see the actual exit code and message.
    claude plugin query \
      --marketplace "$MARKETPLACE" \
      --plugin "$plugin" \
      --field latest_version 2>/dev/null || echo "UNRESOLVED"
  else
    echo "UNRESOLVED"
  fi
}

for plugin in "${!EXPECTED[@]}"; do
  want="${EXPECTED[$plugin]}"
  have="$(query_marketplace "$plugin")"
  if [[ "$have" != "$want" ]]; then
    echo "FAIL: $plugin wanted $want, marketplace has $have"
    FAIL=1
  else
    echo "OK:   $plugin resolved at $want"
  fi
done

if [[ "$FAIL" -ne 0 ]]; then
  echo ""
  echo "One or more siblings did not resolve at their expected floor."
  echo "See skills/references/release-gates.md § 'Marketplace-resolution"
  echo "verification (Phase 6 sub-task, R12)' for the manual-checklist"
  echo "fallback. Do not tag orchestrator v1.0.0 until this script exits 0"
  echo "or the manual fallback is logged in cron-log.md."
fi

exit "$FAIL"
