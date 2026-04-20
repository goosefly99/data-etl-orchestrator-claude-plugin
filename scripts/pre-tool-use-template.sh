#!/usr/bin/env bash
# pre-tool-use-template.sh
#
# Opt-in pre-tool-use hook stub for the data-etl-orchestrator plugin.
# Blocks agent Write / Read attempts against payload-byte files
# (transcripts, tweet bodies, article bodies, scraped pages) before the
# tool call reaches the model. Complements the plugin's skills-level
# "agents never touch payload bytes" invariant with a harness-level
# hard stop.
#
# NOT registered by default. Users must opt in by copying this file
# under .claude/hooks/ and wiring it into settings.json (see
# README.md -> "Opt-in pre-tool-use hook" for the exact snippet).
#
# Exit codes:
#   0  — allow the tool call through
#   2  — block the tool call (hook-veto). Claude Code surfaces the
#        message on stderr to the agent so it can course-correct.
#
# The hook receives the pending tool-use JSON on stdin. Read once,
# inspect the path-like fields, and exit.

set -euo pipefail

# Slurp the tool-use JSON (single document) from stdin into a variable.
TOOL_JSON="$(cat)"

# Extract the target path if this tool call references a file path.
# Claude Code hooks spec: tool_input is the relevant field for Read /
# Write / Edit / MultiEdit. We grep a best-effort "file_path" value out
# of the JSON without requiring jq so the stub runs on a bare shell.
TARGET_PATH="$(
  printf '%s' "$TOOL_JSON" \
    | grep -oE '"(file_path|notebook_path|path)"\s*:\s*"[^"]+"' \
    | head -n1 \
    | sed -E 's/.*"[^"]+"\s*:\s*"([^"]+)"/\1/'
)"

if [ -z "${TARGET_PATH:-}" ]; then
  # No file target — not a write/read tool, let the call through.
  exit 0
fi

# Lower-case for pattern matching; keep the original for the message.
TARGET_LC="$(printf '%s' "$TARGET_PATH" | tr '[:upper:]' '[:lower:]')"

# Deny-list patterns — payload-byte filenames and known MCP cache DBs.
# Extend as new source types land. Match on path substring to cover
# both absolute and relative paths.
case "$TARGET_LC" in
  *transcript*|*.vtt|*.srt)
    echo "pre-tool-use-hook: blocked — transcript payload path ($TARGET_PATH)." >&2
    echo "Orchestrator skills must not Read/Write transcript text. Use the MCP tool surface." >&2
    exit 2
    ;;
  *tweet*|*x-article*|*article-body*)
    echo "pre-tool-use-hook: blocked — tweet/article payload path ($TARGET_PATH)." >&2
    echo "Orchestrator skills must not Read/Write tweet or article body text." >&2
    exit 2
    ;;
  *payload*|*body.txt|*scrape*.txt)
    echo "pre-tool-use-hook: blocked — generic payload path ($TARGET_PATH)." >&2
    exit 2
    ;;
  *youtube-data.db|*x-data.db|*crawler-data.db)
    echo "pre-tool-use-hook: blocked — direct MCP cache DB path ($TARGET_PATH)." >&2
    echo "Go through kb_ingest_batch(source_type=sql_database, uri=...) instead of a direct file op." >&2
    exit 2
    ;;
esac

# Default: allow the call through.
exit 0
