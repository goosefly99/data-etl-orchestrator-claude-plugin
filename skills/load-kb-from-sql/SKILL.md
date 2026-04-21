---
name: load-kb-from-sql
description: "Load SQLite cache DB rows into an agent-knowledgebase via kb_ingest_batch(source_type=sql_database). Stage-3 helper for all ingest-* skills; also standalone. Trigger: 'load DB into KB', '/load-kb-from-sql'."
---

## Stage-0 prerequisites

Before dispatch, run the Stage-0 questionnaire — see
[preflight-questionnaire.md](../references/preflight-questionnaire.md).

---

## When to use this skill

- Called by `ingest-x-user-tweets`, `ingest-x-thread`, `ingest-x-bookmarks`, `ingest-youtube-videos`, `ingest-youtube-playlist` as their Stage 3 step.
- "load the DB into my KB" (standalone invocation when the DB is already populated).
- `/load-kb-from-sql`

Do not invoke if Stage 0 is not yet complete and the source DB has not been verified populated.

---

## Preconditions

- `etl-overview` Stage 0 is complete.
- Source DB is confirmed populated — Stage-2 `get_saved_*` counts are nonzero for the relevant tables.
- Session hygiene is in force — see `../references/session-hygiene.md` for the `uv sync` pause protocol and the FIELD-9 interrupt-recovery recipe.

**Inputs expected from the calling skill (or from Stage 0 if standalone):**

| Input | Description |
|---|---|
| `kb_id` | Target KB identifier |
| `db_path` | Absolute path to source SQLite DB |
| `tables` | List of tables to ingest (e.g., `["tweets", "articles"]`) |
| `row_selector` | WHERE clause or explicit ID list per table |
| `dedup_policy` | `skip` / `re-ingest` / `force-add` |
| `batch_size` | Rows per `kb_ingest_batch` call (default: 50, max: 50) |
| `granularity` | `row` (one KB source per row) or `batch` (one per chunk) |

---

## KB resolution

1. Call `kb_info(kb_id=<id>)` to verify the KB exists and is reachable.
2. If the call fails or returns stale data, fall back to `kb_list` and re-match by name/slug.
3. If the memory pointer in `memory/kb_<slug>.md` does not match the `kb_info` result (e.g., `kb_id` has drifted), update the memory file before proceeding.

Do not proceed to batch construction if KB resolution fails.

---

## Dedup check

For each table in the input list:

1. Call `kb_list_pages(kb_id)` and `kb_list_sources(kb_id)`.
2. Extract existing dedup keys from source metadata:
   - `tweets` table → `tweet_id`
   - `articles` table → `article_id`
   - `videos` / `transcripts` tables → `video_id`
   - file sources → `sha256`
3. Apply Stage-0 dedup policy:
   - `skip` — remove already-present IDs from the ingest list.
   - `re-ingest` — include them; the KB updates the existing source record.
   - `force-add` — include them unconditionally; creates a duplicate source.

Log dedup hit counts per table before starting batch construction.

---

## Batch construction and ingestion

Split the filtered row IDs for each table into chunks of at most `batch_size` (default 50).

For each chunk, issue one sequential `kb_ingest_batch` call using one of the 3 canned `row_selector` patterns below.

**Pattern 1 — By ID list (most common):**
```json
{
  "source_type": "sql_database",
  "uri": "sqlite:///<db_path>",
  "metadata": {
    "table": "videos",
    "row_selector": "video_id IN ('abc123', 'def456', 'ghi789')",
    "granularity": "<row|batch>",
    "kb_source_label": "<caller_skill>:<scope_identifier>"
  }
}
```

**Pattern 2 — By date range:**
```json
{
  "source_type": "sql_database",
  "uri": "sqlite:///<db_path>",
  "metadata": {
    "table": "tweets",
    "row_selector": "saved_at >= '2026-01-01' AND saved_at < '2026-02-01'",
    "granularity": "<row|batch>",
    "kb_source_label": "<caller_skill>:<scope_identifier>"
  }
}
```

**Pattern 3 — By author:**
```json
{
  "source_type": "sql_database",
  "uri": "sqlite:///<db_path>",
  "metadata": {
    "table": "tweets",
    "row_selector": "author_id = '12345'",
    "granularity": "<row|batch>",
    "kb_source_label": "<caller_skill>:<scope_identifier>"
  }
}
```

> **WHERE-clause allow-list enforced server-side.** See `skills/references/safe-where-clause-grammar.md` for accepted `row_selector` grammar. The 3 canned patterns above cover the common cases; any expression inside the documented allow-list is accepted. Do not construct arbitrary WHERE clauses from unvalidated user input — rely on the server-side sqlparse-AST validator as the final gate.

- All `kb_ingest_batch` calls within a single subagent are **sequential** — serialization avoids MCP contention at the agent-knowledgebase per-`kb_id` write lock. No concurrent calls inside one subagent.
- Multiple subagents may run in parallel across **disjoint scopes** — i.e., each parallel subagent handles a disjoint slice of IDs (non-overlapping `row_selector` or disjoint `kb_source_label` values). See `../references/subagent-dispatch-protocol.md` § Parallel-subagent boundary for the worked example and safety rules.
- Process all chunks for table 1 before moving to table 2.
- Narrow the `row_selector` to only the IDs in the current chunk; do not pass unbounded queries.

---

## Cleanup pass (FIELD-3 interim)

`kb_ingest_batch` may partially succeed: a source-row record is
written before the embed phase, and an embed-phase failure (e.g.,
embedder 503, cold-start timeout, GPU OOM) leaves the row with
`status: "failed"` and `chunk_count: 0`. Under `skip` dedup policy
the next run treats the row as "already present" and the failed rows
are never re-ingested — silent data loss.

After any `kb_ingest_batch` call that returned a partial or failing
response, and before reporting success in the deliverable, run:

1. Call `kb_list_sources(kb_id)`.
2. Filter for rows where `status == "failed"` AND `kb_source_label`
   matches the current batch's label (or `row_selector` matches the
   current chunk's WHERE clause).
3. For each matching row, call `kb_remove_source(kb_id, source_id)`
   to drop the stale failed record.
4. Re-issue the failed chunk's `kb_ingest_batch` call with the same
   `row_selector` and `kb_source_label`.
5. Log each remove + retry pair in the deliverable (row ID,
   `kb_source_label`, original error, retry outcome).

If a chunk fails the same way twice in a row, escalate to the user
rather than retrying indefinitely — the failure is environmental
(embedder down, disk full) and must be fixed out-of-band.

> **Temporary stopgap.** Once agent-knowledgebase v0.7.0 rolls back
> source-row persistence on embed-phase failure (or accepts an
> explicit `persist_failed=true` flag defaulting false), this section
> is deleted and `kb_ingest_batch` failures become idempotent retry
> targets with no cleanup pass.

See also: `../references/idempotency-and-dedup.md` § Failure-state
semantics; `../references/session-hygiene.md` § FIELD-9 recovery
recipe (the FIELD-3 cleanup pass is invoked from both locations).

---

## Progress logging

After each `kb_ingest_batch` call, record:

- Elapsed time for the call.
- Number of rows ingested (from response).
- Dedup hits in this chunk.
- Any failures (row ID + reason).

**Never echo row content (tweet text, transcript body, article text) in logs or reports.**

---

## Memory pointer emission (FIELD-13)

After all batches for all tables complete successfully, the skill
auto-emits the memory pointer file from the template below rather
than asking the user (or a subagent) to hand-substitute an angle-bracketed
KB-id placeholder. The literal placeholder must never appear in a shipped pointer file.

### 1. Fetch authoritative KB state

Call `kb_info(kb_id)` and capture:

- `id` (the resolved KB id — canonical after any FIELD-10 stale-pointer recovery)
- `name`
- `description` (or derive a one-sentence purpose from the Stage-0 plan if absent)
- `page_count` and `source_count` (for the `Last verified` summary)

### 2. Render the pointer file

Write `memory/kb_<slug>.md` (where `<slug>` is the kebab-case form of
the KB name) with this exact body, substituting the placeholders via
the implementing agent or dispatched subagent — NEVER leaving any
angle-bracketed placeholder (such as the resolved kb_id token) literally in the
emitted file:

```markdown
---
name: <slug> KB pointer
description: Pointer to the <KB name> knowledgebase (id + one-line purpose)
type: reference
---

Knowledgebase name: <KB name>
Knowledgebase id: <resolved kb_id>
Purpose: <one-sentence purpose>
Last verified: <ISO date, e.g. 2026-04-21>
```

Every `<...>` token in the template above must be replaced with a
concrete value before the file is written. If any token remains,
halt and raise a deliverable error; do not ship the file.

### 3. Update the MEMORY.md index

Append (or update in place) a single line in `MEMORY.md`:

```
- [<slug> KB](kb_<slug>.md) — <one-line hook>
```

Keep the line under 150 characters.

### 4. Post-emission verification

- Grep the emitted pointer file for any angle-bracketed `<...>` token
  remnants — if any hit, fail the deliverable.
- Confirm `memory/kb_<slug>.md` and the new `MEMORY.md` line exist.
- Log the pointer emission (new vs updated, path, resolved id) in
  the deliverable's "Outputs" section.

### 5. Drift check (rerun case)

If the pointer file already existed before this run, compare the
old `Knowledgebase id` / `page_count` / `source_count` to the new
values. If the `id` differs, run the FIELD-10 stale-pointer
recovery flow (`../references/kb-memory-pointer-protocol.md` §
Stale-pointer recovery flow) before overwriting. If only counts
differ, overwrite in place and update `Last verified`.

See `../references/kb-memory-pointer-protocol.md` for the canonical
pointer file spec and MEMORY.md line rules.

---

## Delegation

When invoked by a parent ingest skill, the parent should already have spawned a Sonnet subagent to run this skill. The subagent receives only the inputs listed above plus any resolved KB id.

When invoked standalone, offer to delegate the batch loop to a Sonnet subagent before starting, especially if the total row count exceeds 200.

---

## Deliverable

This skill emits the standard ETL deliverable. See
[deliverable-format.md](../references/deliverable-format.md).

---

## Idempotency and envelopes

Dedup behaviour per source is documented in
[idempotency-and-dedup.md](../references/idempotency-and-dedup.md).
Sibling MCP response envelopes and kb_ingest_batch semantics are
pinned in [mcp-tool-contracts.md](../references/mcp-tool-contracts.md).

---

## Do not do these things

- Do NOT use `source_type="file"` here. This skill is exclusively for `source_type="sql_database"`.
- Do NOT issue unbounded SQL queries — always narrow `row_selector` to the current chunk's IDs.
- Do NOT run multiple `kb_ingest_batch` calls in parallel **within a single subagent**. (Multiple subagents with disjoint scopes may run in parallel — see `../references/subagent-dispatch-protocol.md` § Parallel-subagent boundary.)
- Do NOT echo row content in logs or reports.
- Do NOT skip the KB resolution step — stale memory pointers cause silent double-ingestion.
- Do NOT proceed if Stage-2 counts are zero — ingesting an empty DB is a no-op that should be flagged to the user.

---

## References

- `references/preflight-questionnaire.md` — Stage 0 canonical spec
- `references/deliverable-format.md` — standard ETL deliverable format
- `references/idempotency-and-dedup.md` — dedup behaviour per source
- `references/mcp-tool-contracts.md` — tool signatures and response contracts
- `references/kb-source-types.md` — source type registry (this skill: sql_database only)
- `references/source-db-schemas.md` — SQLite schema reference for all source DBs
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/subagent-dispatch-protocol.md` — subagent delegation spec
- `references/session-hygiene.md` — `uv sync` pause protocol and FIELD-9 interrupt-recovery recipe
