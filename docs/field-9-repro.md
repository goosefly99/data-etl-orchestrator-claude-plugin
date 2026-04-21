# FIELD-9 — MCP interrupt kills server (investigation plan)

## Symptom

Interrupting a long-running MCP tool call (Ctrl+C on a slow `kb_query`,
a 35-min embed, or a hung `kb_ingest_batch`) disconnects the MCP server
process entirely. The harness loses the subprocess, forces `/mcp reconnect`
and a full schema reload, and discards all in-flight state. This blocks
bounded-wall-clock recovery from FIELD-6 (cold start), FIELD-8 (parallel
subagents), and FIELD-14 (retrieval hangs).

## Priority rationale

FIELD-9 is the biggest UX amplifier in the roadmap. Every long-running
retrieval or ingest operation becomes unrecoverable on interrupt — the user
loses the session and must re-run from the beginning of the affected batch.
This is not an external filing candidate: the failure mode is reproducible,
the blast radius spans every sibling MCP, and a fix exists at the
server-side layer regardless of harness behavior. It must be treated as a
blocking fix, not a low-priority cleanup.

## Repro steps

1. Stand up a minimal stub MCP server exposing one deliberately slow tool
   (e.g., `sleep 60 && return "ok"`). This isolates the behavior from any
   kb/yt/x-api sibling specifics.
2. From a Claude Code session, invoke the slow tool. While it is in flight,
   send Ctrl+C (or the harness interrupt).
3. Capture, before and after the interrupt:
   - The MCP server's PID (e.g., via `ps aux | grep <server_name>` or
     `Get-Process`).
   - The MCP server's stderr (redirect to a file when spawning:
     `python server.py 2>server_stderr.txt`).
   - The harness-side `/mcp` status (connected vs disconnected, PID shown
     in the status output).
4. Repeat against a sibling MCP server (agent-knowledgebase) with a real
   long-running tool call (a cold `kb_query`) to confirm the behavior is
   not stub-specific.

## Localization hypotheses

Two hypotheses to disprove before committing to a fix shape:

**Server-side:** the sibling MCP server lacks a `CancelledNotification`
handler (per the MCP spec). When the harness cancels the in-flight RPC,
it closes stdio instead of sending the notification; the server's stdio
event loop exits on EOF → the process exits.

**Harness-side:** the Claude Code MCP client tears down the subprocess on
RPC cancel rather than sending a `CancelledNotification` and awaiting a
graceful response. The server never gets a chance to handle the cancel
cleanly regardless of whether it has a handler.

The repro in step 3 (PID before vs after) distinguishes the two: if the
server PID changes (or the process is gone) immediately on interrupt
regardless of server implementation, the cause is harness-side. If the PID
survives only when the server installs a SIGINT/cancellation handler, the
cause is server-side.

## Proposed fix shape

**Server-side (if localized there):**
- Implement a `CancelledNotification` handler in the sibling MCP servers.
  The handler terminates the in-flight unit of work without exiting the
  process and emits a structured `{"error": "cancelled", "phase": "..."}` 
  payload so the caller can reconstruct partial progress.
- Add a ship-gate test that interrupts an in-flight tool call and asserts
  the server PID is unchanged after the interrupt.

**Harness-side (if localized there):**
- File upstream with the full repro trace (PIDs, stderr tails, timestamps
  from step 3) so the Claude Code team can address the subprocess teardown
  behavior.
- In parallel, ship an MCP-server-level mitigation: detach stdio from
  in-flight handlers and re-establish on reconnect, so the plugin remains
  usable without waiting for a harness fix.

## Exit criteria

The investigation is done when all four conditions are met:

1. The repro output from step 3 is captured in this doc: PIDs before and
   after interrupt, stderr tails, and wall-clock timestamps.
2. A single sentence names the owning side (sibling MCP server vs harness).
3. A tracking issue or patch link is filed on the owning side's repo.
4. `skills/references/session-hygiene.md` is updated from "interrupt = full
   disconnect" to the post-fix phrasing: "interrupt cancels the RPC; server
   stays up; verify with `/mcp` status (PID unchanged)."

## Regression guard

Once fixed, `scripts/verify-session-hygiene.sh` (optional; roadmap
§ "Recommended") can include:

```
spawn MCP server → record PID
→ invoke slow tool
→ interrupt
→ assert PID unchanged
```

Ship this test alongside the fix so future harness or server changes that
re-introduce subprocess teardown on cancel are caught immediately.
