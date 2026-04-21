# Subagent Dispatch Protocol

## Purpose

Stage 3 batch ingestion can be large (hundreds of rows across multiple tables). Delegating this work to a Sonnet subagent keeps the parent agent's context clean and costs down. This document pins the contract between the parent agent and the dispatched subagent: what goes in, what comes out, and what is forbidden.

---

## Prompt template

The parent agent constructs a subagent prompt containing ONLY:

| Field | Description |
|---|---|
| `kb_id` | Target KB identifier (verified via `kb_info` before dispatch) |
| `db_path` | Absolute path to the source SQLite DB (resolved in Stage 0) |
| `tables` | Table names and row ID lists, grouped by table (e.g., `tweets: [id1, id2, ...]`, `articles: [id3, id4, ...]`) |
| `batch_size` | Rows per `kb_ingest_batch` call (default 50, max 50) |
| `dedup_policy` | One of: `skip`, `re-ingest`, `force-add` |
| `dedup_hits` | List of IDs the parent already identified as dedup hits (to be skipped or handled per policy) |
| `kb_source_label` | Value for the `kb_source_label` metadata field (e.g., `x_user_tweets:@handle`, `youtube_playlist:PLxxxxx`) |

The subagent receives structured data — IDs and metadata only. It orchestrates `kb_ingest_batch` calls using these IDs to point the KB at existing DB rows.

---

## Forbidden inputs

The subagent prompt MUST NOT contain:

- Raw transcript text (from YouTube videos)
- Raw tweet text or article body (from X API)
- Full API response payloads (from any MCP)
- DB file contents (binary or text dumps)
- Any payload bytes from any source

The subagent never needs content bytes. It constructs `kb_ingest_batch` calls with `source_type: "sql_database"` and row selectors — the KB server reads the content directly from the DB at ingest time.

---

## Required report shape

The subagent MUST return a structured report containing:

**Per-table summary:**

| Field | Description |
|---|---|
| `table` | Table name (e.g., `tweets`, `articles`, `videos`, `transcripts`) |
| `total_targeted` | Total rows targeted for ingestion |
| `rows_ingested` | Rows successfully ingested |
| `failures` | Count of failed rows |

**Per-batch log:**

| Field | Description |
|---|---|
| `batch_index` | Sequential batch number (1-based) |
| `rows_in_chunk` | Number of rows in this batch |
| `result` | `ok`, `partial`, or `failed` |
| `elapsed_time` | Wall-clock time for this batch call |

**Dedup summary:**

- Total dedup hits applied (count)
- Dedup policy used (`skip` / `re-ingest` / `force-add`)

**Failure detail:**

- For each failed row: row ID + reason string

**Totals:**

- Total elapsed time across all batches

The subagent MUST NOT echo any row content (tweet text, transcript body, article text) in its report. IDs and metadata only.

---

## Max context size

The subagent should be dispatched with `model: "sonnet"`.

If the total row ID list across all tables exceeds **500 items**, the parent MUST split the work into multiple subagent dispatches, each receiving at most 500 IDs. Each dispatch is independent and produces its own report. The parent agent merges the reports into the final deliverable.

Splitting strategy:
- Partition by table first, then by ID count within each table.
- Each subagent dispatch gets a contiguous slice of IDs for one or more tables, totaling at most 500 IDs.

---

## Error handling

If the subagent fails outright (crash, timeout, context overflow) or reports partial success:

1. The parent agent treats the failure as a **non-fatal delta** — items not yet ingested.
2. The parent can re-dispatch a follow-up subagent for the failed chunk, using the same protocol.
3. The follow-up subagent receives only the IDs that failed or were not attempted.
4. The parent logs the failure in the deliverable with the subagent's error output (if any).
5. If two consecutive subagent dispatches fail on the same chunk, the parent escalates to the user rather than retrying indefinitely.

---

## Parallel-subagent boundary (FIELD-8)

`kb_ingest_batch` calls are sequential **within a single subagent** to
avoid MCP contention at the agent-knowledgebase per-`kb_id` write
lock. They are NOT absolutely forbidden across subagents. The
parallelism boundary is **scope disjointness**:

- **Safe:** two subagents each dispatched with a disjoint ID-list
  chunk of the same staging DB (e.g., subagent A gets
  `video_id IN ('a','b','c')`, subagent B gets
  `video_id IN ('d','e','f')`). Their `row_selector` values match
  no overlapping rows, so the server's per-`kb_id` write lock
  queues them harmlessly.
- **Safe:** two subagents targeting different `kb_id`s in parallel.
  The per-`kb_id` lock does not serialize across KBs.
- **Not safe:** two subagents with overlapping ID lists and
  `dedup_policy = "force-add"`. The KB will contain duplicate
  source records and retrieval will return correlated duplicates.
- **Not safe without coordination:** overlapping ID lists under
  `re-ingest`. The second subagent's insert overwrites the first's,
  but both runs pay the embed cost and the order of final state is
  not deterministic.

Worked example of a safe parallel dispatch:

```
Subagent A:
  kb_id       = <shared kb_id>
  tables      = { "videos": ["vid_001", ..., "vid_200"] }
  kb_source_label = "load-kb-from-sql:playlist-A:batch-1"
  row_selector    = "video_id IN (<200 ids>)"

Subagent B (dispatched in parallel):
  kb_id       = <shared kb_id>
  tables      = { "videos": ["vid_201", ..., "vid_400"] }
  kb_source_label = "load-kb-from-sql:playlist-A:batch-2"
  row_selector    = "video_id IN (<different 200 ids>)"
```

The two ID lists are disjoint. The agent-knowledgebase per-`kb_id`
lock queues the two subagents' `kb_ingest_batch` calls without data
corruption.

Counter-example of an unsafe parallel dispatch:

```
Subagent A: row_selector = "saved_at >= '2026-01-01'", dedup_policy = "force-add"
Subagent B: row_selector = "author_id = '12345'",      dedup_policy = "force-add"
```

If any row matches both predicates, it is ingested twice with
`force-add` — duplicate KB sources with duplicate embeddings.
Disjointness must be provable from the `row_selector` expressions,
not just "probably disjoint".

The parent agent is responsible for proving disjointness before
dispatching parallel subagents. When in doubt, prefer sequential.

---

## Concurrent KB-query cost (FIELD-14 interim)

Parallel subagents doing RETRIEVAL (`kb_query` / `kb_search`) on
the same KB are NOT free. When the embedder is a single-GPU Ollama
backend, embed requests serialize at the embedder — N concurrent
`kb_query` calls each pay the full serialized embed latency and
amplify wall-clock time instead of reducing it. Observed: 4
concurrent `kb_query` calls against a shared KB blocked the full
RPC window for ~30 min with no tool results delivered.

Caller-side contract (interim):

- Prefer sequential retrieval inside a single subagent unless the
  embedder backend is known to be parallel-safe (e.g., multi-GPU
  or a hosted embedding API with sufficient concurrency).
- For CPU-bound fast backends (small local models, or an OpenAI-
  style hosted endpoint with generous rate limits), parallel
  retrieval is fine — but validate with a cold-run benchmark
  before committing.
- Ingest parallelism (FIELD-8 § Parallel-subagent boundary above)
  is orthogonal — disjoint-scope ingest subagents remain safe to
  run in parallel regardless of retrieval backend characteristics.

Once agent-knowledgebase v0.7.0 ships a backend-parallelism
contract (serialized-at-embedder vs parallel-safe), this section is
replaced with a hard rule referencing that contract.
