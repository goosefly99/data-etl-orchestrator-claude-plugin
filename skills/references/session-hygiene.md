# Session Hygiene

## Purpose

These recipes recover from the two environment hazards that most often corrupt
an in-flight ETL session: `uv sync` restarts that nuke the running MCP server
subprocess (FIELD-4) and MCP-tool-call interrupts that drop the server
connection entirely (FIELD-9).

---

## FIELD-4 — `uv sync` pause protocol

`uv sync --directory <plugin_path>` rewrites the plugin's virtual environment
and terminates every Python process rooted in it — including the running MCP
server subprocess. The server's stdin/stdout pipes vanish mid-session, forcing
a full harness reconnect and KB state re-verification.

**Rule:** run all dependency changes before the session starts. If mid-session
changes are unavoidable, follow this pause protocol in order:

1. `/mcp disconnect` — drop the server connection cleanly before the venv is
   touched.
2. `uv sync --directory <plugin_path>` — safe to run now; no live process
   depends on the venv.
3. `/mcp reconnect` — the harness re-establishes the subprocess and connection.
4. Re-validate KB state: call `kb_info(kb_id)` to confirm the KB is reachable,
   then run the FIELD-3 cleanup pass (see `load-kb-from-sql/SKILL.md`
   § Cleanup pass) if any batch was in flight when the disconnect happened.

---

## FIELD-9 — interrupt-kills-server recovery

**Current (buggy) behavior:** interrupting a long-running MCP tool call
(Ctrl+C on a slow `kb_query`, a 35-min embed, or a hung `kb_ingest_batch`)
disconnects the MCP server process entirely, losing all in-flight state.
A full `/mcp reconnect` and schema reload is required before any further
tool calls succeed. This blocks bounded-wall-clock recovery from FIELD-6
(cold start), FIELD-8 (parallel subagents), and FIELD-14 (retrieval hangs).

Recovery recipe:

1. `/mcp reconnect` — re-attach to the server. If the subprocess exited, the
   harness will spawn a fresh one.
2. Call `kb_info(kb_id)` to verify KB state is intact.
3. Run the FIELD-3 cleanup pass:
   - `kb_list_sources(kb_id)` filtered on `status == "failed"` and matching
     the interrupted batch's `row_selector` or `kb_source_label`.
   - `kb_remove_source` on each matching failed source.
   - See `load-kb-from-sql/SKILL.md` § Cleanup pass (landing in Phase 2).
4. Re-run the interrupted operation from the beginning of the affected batch.

> **After the FIELD-9 root-cause fix lands (tracked in
> `docs/field-9-repro.md`), this section replaces "interrupt = full
> disconnect" with "interrupt cancels the RPC; server stays up; verify with
> `/mcp` status (PID unchanged)."**

---

## Cross-references

- [`../load-kb-from-sql/SKILL.md`](../load-kb-from-sql/SKILL.md) — batch
  ingestion skill; the cleanup pass described above lives here.
- [`../references/kb-memory-pointer-protocol.md`](kb-memory-pointer-protocol.md) —
  KB pointer verification after reconnect.
- [`../../docs/field-9-repro.md`](../../docs/field-9-repro.md) — investigation
  plan and exit criteria for the FIELD-9 root-cause fix.
