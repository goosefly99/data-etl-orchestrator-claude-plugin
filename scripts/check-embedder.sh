#!/usr/bin/env bash
# Temporary stopgap — remove once sibling kb_embedder_health lands in
# agent-knowledgebase v0.7.0. Tracking: data-etl-orchestrator ROADMAP.md FIELD-11.
#
# Usage:
#   ./check-embedder.sh [--url <url>] [--timeout <seconds>]
#
# Emits a single JSON line to stdout:
#   {"up": true,  "latency_ms": 42,   "endpoint": "http://..."}
#   {"up": false, "latency_ms": null, "endpoint": "http://...", "error": "..."}
# Exit 0 if up, exit 1 if down.

set -euo pipefail

# Defaults
URL="http://localhost:11434/api/tags"
TIMEOUT=5

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      URL="${2:?--url requires a value}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:?--timeout requires a value}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--url <url>] [--timeout <seconds>]" >&2
      exit 2
      ;;
  esac
done

# Measure wall time using date +%s%N (nanoseconds); fall back to $SECONDS if
# nanosecond resolution is unavailable (e.g. macOS without coreutils).
_now_ns() {
  local t
  t=$(date +%s%N 2>/dev/null) || true
  # If date +%s%N is unsupported it may echo literal '%s%N' or similar
  if [[ "$t" =~ ^[0-9]+$ ]]; then
    echo "$t"
  else
    echo $(( SECONDS * 1000000000 ))
  fi
}

START_NS=$(_now_ns)

HTTP_CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time "${TIMEOUT}" "${URL}" 2>/tmp/_check_embedder_err$$) || CURL_EXIT=$?
CURL_EXIT="${CURL_EXIT:-0}"

END_NS=$(_now_ns)
LATENCY_MS=$(( (END_NS - START_NS) / 1000000 ))

# Clean up temp error file
rm -f /tmp/_check_embedder_err$$

# Determine success: HTTP 2xx considered up
if [[ "${CURL_EXIT}" -eq 0 && "${HTTP_CODE}" =~ ^2 ]]; then
  printf '{"up": true, "latency_ms": %d, "endpoint": "%s"}\n' "${LATENCY_MS}" "${URL}"
  exit 0
else
  # Determine a human-readable error
  if [[ "${CURL_EXIT}" -ne 0 ]]; then
    ERROR_MSG="curl exited with code ${CURL_EXIT} (connection refused or timeout)"
  else
    ERROR_MSG="unexpected HTTP status ${HTTP_CODE}"
  fi
  # JSON-escape the error message (simple: replace " with \")
  ERROR_MSG="${ERROR_MSG//\"/\\\"}"
  printf '{"up": false, "latency_ms": null, "endpoint": "%s", "error": "%s"}\n' "${URL}" "${ERROR_MSG}"
  exit 1
fi
