---
name: load-kb-from-sql
description: "Load SQLite cache DB rows into an agent-knowledgebase via kb_ingest_batch(source_type=sql_database). Stage-3 helper for all ingest-* skills; also standalone. Trigger: 'load DB into KB', '/load-kb-from-sql'."
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

For each chunk, issue one sequential `kb_ingest_batch` call:

```
kb_ingest_batch([
  {
    source_type: "sql_database",
    uri: "sqlite:///<db_path>",
    metadata: {
      table: "<table_name>",
      where: "<narrowed SQL fragment, e.g. id IN ('a','b','c')>",
      granularity: "<row|batch>",
      kb_source_label: "<caller_skill>:<scope_identifier>"
    }
  }
])
```

- All calls are **sequential**. Do not parallelize — serialization avoids MCP contention.
- Process all chunks for table 1 before moving to table 2.
- Narrow the `where` clause to only the IDs in the current chunk; do not pass unbounded queries.

---

## Progress logging

After each `kb_ingest_batch` call, record:

- Elapsed time for the call.
- Number of rows ingested (from response).
- Dedup hits in this chunk.
- Any failures (row ID + reason).

**Never echo row content (tweet text, transcript body, article text) in logs or reports.**

---

## Memory pointer update

After all batches for all tables complete successfully:

1. Call `kb_info(kb_id)` to get the current page count and source count.
2. Compare to the value recorded in `memory/kb_<slug>.md`.
3. If the pointer has drifted (page count changed), update `memory/kb_<slug>.md` with the current `kb_info` output.
4. Confirm the `MEMORY.md` index line for this KB is still accurate.

---

## Delegation

When invoked by a parent ingest skill, the parent should already have spawned a Sonnet subagent to run this skill. The subagent receives only the inputs listed above plus any resolved KB id.

When invoked standalone, offer to delegate the batch loop to a Sonnet subagent before starting, especially if the total row count exceeds 200.

---

## Deliverable format

Final report must include:

- **Per-table summary** — table name, total rows targeted, dedup hits (count + policy), rows ingested, failures.
- **Per-batch log** — batch index, rows in chunk, ingestion result (ok / partial / failed), elapsed time.
- **Final `kb_list_pages` count** — total KB pages after ingestion vs. before.
- **Memory pointer status** — updated / already current / update failed (with reason).
- **Failures** — list each failed row/chunk with reason. Partial success is not treated as overall failure.

---

## Do not do these things

- Do NOT use `source_type="file"` here. This skill is exclusively for `source_type="sql_database"`.
- Do NOT issue unbounded SQL queries — always narrow `where` to the current chunk's IDs.
- Do NOT run `kb_ingest_batch` calls in parallel.
- Do NOT echo row content in logs or reports.
- Do NOT skip the KB resolution step — stale memory pointers cause silent double-ingestion.
- Do NOT proceed if Stage-2 counts are zero — ingesting an empty DB is a no-op that should be flagged to the user.

---

## References

- `references/mcp-tool-contracts.md` — tool signatures and response contracts
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/preflight-questionnaire.md` — Stage 0 canonical spec
- `references/subagent-dispatch-protocol.md` — subagent delegation spec
