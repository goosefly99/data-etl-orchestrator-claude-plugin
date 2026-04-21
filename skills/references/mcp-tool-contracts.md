# MCP Tool Contracts

## Purpose

This document pins the tool-level contract the orchestrator assumes at runtime. It is maintained alongside the source MCPs (youtube-mcp, x-api-mcp) so that edits to one surface as an obvious mismatch. If any SKILL.md in this plugin references a tool signature that does not match what is documented here, stop and resolve the discrepancy before proceeding.

---

## youtube-mcp

### `get_video_details(videoId, includeTranscript=true)`

- Returns `{ metadata, transcript, statuses: { metadata: "ok", transcript: "ok" | "missing" | "unavailable" } }`.
- Writes both a `videos` row and a `transcripts` row in a single DB transaction.
- `includeTranscript` defaults to **true**. Callers must not omit it or set it to false in the ingest path.
- The caller never has to call `get_transcript` separately.

### `get_playlist_items(playlistId, hydrate=true, maxResults=500)`

- With `hydrate=true` (default): server fetches metadata and transcript for each playlist item, writes rows as they arrive, and returns a per-item status array `[{ video_id, position, metadata, transcript }]`.
- With `hydrate=false`: reverts to legacy snippet-only behavior; playlist_items rows are written but `videos` and `transcripts` rows are not.
- `hydrate` defaults to **true**. Do not set `hydrate=false` in the ingest path.
- `maxResults` caps the number of items retrieved (default 500, max 500).

### `get_transcript(videoId, language, listLanguages)`

- **Cache-read accessor only.** Reads the `transcripts` table; does not trigger an API fetch.
- Not a fetch entrypoint. Do not call this in the Stage 1 ingest path.
- Use for on-demand inspection, debugging, or post-ingest verification only.

### Read-only cache queries (Stage 2)

- `get_saved_videos(query, channel, source, limit, offset)` — query the `videos` table.
- `get_saved_transcripts(query, language, snippetLength, limit, offset)` — query the `transcripts` table.
- `get_saved_playlists(...)` — query the `playlists` table.

These are used in Stage 2 to verify DB state after Stage 1 writes.

### Failure semantics

- A video with `transcript: "missing"` (captionless video) still produces a `videos` row. The orchestrator logs this as "metadata-only" and ingests the `videos` row without a corresponding `transcripts` row.
- This is the documented behavior for videos such as `aDWJ6lLemJU`. Partial success is not a failure.
- `transcript: "unavailable"` means the transcript API call was attempted but returned no data. Same handling as `"missing"`.

### Transcript-status semantics

| Status | Meaning | Retry? |
|---|---|---|
| `ok` | Transcript fetched and stored | No |
| `missing` | Video has no captions | No — permanent |
| `unavailable` | Transcript API returned no data | Yes — transient |
| `failed` | Transcript fetch threw an error | Yes — transient |
| `skipped` | Fetch was intentionally skipped | No |

---

## x-api-mcp

### Fetch tools

- `x_get_tweet(tweet_id)` — fetch a single tweet by id.
- `x_get_user_tweets(user_id, max_results, next_token)` — paginated user timeline.
- `x_get_thread(tweet_id, max_results)` — full conversation thread rooted at `tweet_id`.
- `x_get_bookmarks(max_results, next_token)` — authenticated user's bookmarks.
- `x_search_tweets(query, max_results, next_token)` — search API.

All five return full tweet metadata and text body, and write a `tweets` row with the appropriate `source` value.

**X Article auto-crawl:** When a fetched tweet links one or more X Articles, the server automatically crawls each via its in-process Playwright crawler and inserts an `articles` row per article with `source="crawl"`, keyed by `tweet_id`. A tweet can link multiple articles, so the per-tweet response includes an array:

```json
"articles": [
  {
    "status": "ok" | "missing" | "failed",
    "url": "<...>",        // present if status != "missing"
    "article_id": "<...>"  // present if status == "ok"
  }
]
```

**TweetArticlesEnvelope array shape (X3 refactor):** The orchestrator-visible return shape of `articleIngestService.ingestForTweets` / `resolveArticlesForTweets` is `TweetArticlesEnvelope = { tweetId, articles: Article[] }[]` — zod-validated via `tweetArticlesEnvelopeSchema`, reused by contract-probe-protocol probe-4 in Phase 4. See `x-api-mcp/types.ts` for the canonical definition (replaces the prior `Map<tweetId, Article[]>` return shape so downstream consumers can `.map()` uniformly).

### Read-only / manual-override accessors (not in ingest path)

- `x_get_article(article_id)` — read an article row from cache.
- `x_crawl_article(url)` — manually trigger article crawl. Not called during orchestrated ingest.

### User resolution

- `x_get_user(username)` — resolve a handle to `user_id`. Required before calling `x_get_user_tweets`.

### Read-only cache queries (Stage 2)

- `x_get_saved_tweets` — query the `tweets` table.
- `x_get_saved_articles` — query the `articles` table.
- `x_get_saved_users` — query the `users` table.

### Failure semantics

- Article auto-crawl failure does **not** fail the parent tweet insert. The `tweets` row is written; the `articles` row is skipped. The per-tweet `articles` array records the entry with `status = "failed"` plus a reason string.
- Log article crawl failures per tweet in the Stage 1 status report. Do not treat them as blocking errors.

---

## agent-knowledgebase

### Management

- `kb_create(name, description)` — create a new KB; returns its `id`.
- `kb_list()` — list all KBs with id, name, description.
- `kb_info(kb_id)` — retrieve metadata for a single KB; use to verify pointer accuracy. Response includes `dominant_embedding_model` field indicating the embeddings model used for the majority of the KB's indexed pages.

### Ingest

- `kb_ingest(kb_id, source_type, uri, metadata)` — ingest a single source.
- `kb_ingest_batch(kb_id, sources)` — ingest an array of `{ source_type, uri, metadata }` objects. Processing is sequential server-side. Recommended batch size: ≤50 sources per call. All `kb_ingest_batch` calls for a given `kb_id` are serialized server-side. Concurrent calls targeting the same KB will queue. Batch size hard-reject threshold: 50 rows per call.

  The `row_selector` field accepts a WHERE clause fragment validated by the sqlparse-AST allow-list. See `safe-where-clause-grammar.md` for accepted `row_selector` grammar.

### Verification and dedup

- `kb_list_pages(kb_id, page_type)` — list KB pages; includes per-page metadata (used to check dedup keys).
- `kb_list_sources(kb_id)` — list ingested sources.

### Pipeline status (v2 telemetry row)

- `kb_pipeline_status(kb_id)` — returns a JSON array of `PipelineRun` records.
- **Tool signature unchanged** from v0.5.x; only the per-run payload is expanded. v0.6.0 adds nine additive, optional fields to each run: `ingested`, `skipped`, `replaced`, `failed`, `batch_size`, `dedup_policy`, `request_id`, `tool_caller_version`, and `ended_at`. All default to `null` on pre-migration rows so historical runs deserialize unchanged.
- Source: `agent-knowledgebase/src/agent_knowledgebase/server.py::kb_pipeline_status` (model `PipelineRun` in `models.py`).
- Consumers MUST treat every v0.6.0 field as optional — do not assume presence when reading older rows.

---

## better-sqlite3 (x-api-mcp) vs node:sqlite (youtube-mcp) asymmetry

The two TypeScript sibling MCPs ship distinct SQLite bindings. The matrix below pins the runtime differences the orchestrator's skills must assume. Zero-code-change doc. Normalization timeline is a carried-forward OQ for v0.4.0.

| Dimension | better-sqlite3 (x-api-mcp) | node:sqlite (youtube-mcp) |
|---|---|---|
| WAL mode | `db.pragma('journal_mode = WAL')` at init; stable | `db.exec('PRAGMA journal_mode=WAL')`; same syntax, different semantics around checkpoint |
| Transaction isolation | `db.transaction(fn)(...)` wraps with IMMEDIATE | explicit `BEGIN/COMMIT/ROLLBACK` via withTransaction helper |
| Lock granularity | Full-database lock on writes; synchronous API | Same on-disk semantics; different async interop |
| API shape | Sync | Sync |

Zero-code-change doc. Normalization timeline is a carried-forward OQ for v0.4.0.

---

## Transcript retry semantics (youtube-mcp)

The `transcript: "unavailable"` and `transcript: "failed"` statuses are transient and retriable. The retry cadence (attempt count, backoff curve, cache eviction policy) is pinned in `docs/transcript-retry-semantics.md` (ships in youtube-mcp v0.5.0). Orchestrator skills defer retry decisions to the MCP server rather than re-calling from the agent context.

See `docs/transcript-retry-semantics.md` (ships in youtube-mcp v0.5.0).

---

## Drift prevention

Before implementing any change to a SKILL.md that references a tool signature, verify the signature against this document. If the source MCP has been updated and this document is stale, update this document first (with justification), then update the SKILL.md files in a separate commit.

---

## Known runtime hazard: `kb_query` / `kb_search` silent blocking (FIELD-14, interim)

Until agent-knowledgebase v0.7.0 lands with bounded timeouts and
progress events, both `kb_query` and `kb_search` can block the RPC
indefinitely when the embedder is cold, serialized on single-GPU
Ollama, or unreachable. Observed blocking windows: 30+ minutes with
no tool result delivered. This starves the agent loop and compounds
with FIELD-9 (interrupt tears down the MCP server entirely).

**Caller-side contract (interim):**

- Run the Stage-0 embedder-health probe
  (`scripts/check-embedder.{sh,ps1}`) before any retrieval call.
- Bound your own wall-clock budget for retrieval calls; escalate to
  the recovery recipe in `session-hygiene.md` if the budget expires.
- Parallel `kb_query` calls against the same KB are NOT free on a
  single-GPU Ollama backend — the embedder serializes, and each
  concurrent call pays the full serialized latency. See
  `subagent-dispatch-protocol.md` § Concurrent KB-query cost.
- Prefer sequential retrieval inside a single subagent unless the
  embedder backend is known to be parallel-safe.

**Sibling-side fix (tracked for v0.7.0):**

- Bounded server-side embed timeout with a structured error
  `{"error":"embed_timeout","model":...,"phase":"embed_query","latency_ms":...}`.
- Progress / heartbeat events distinguishing `embed_query`,
  `ann_search`, and `hydrate_chunks` phases.
- Internal embedder preflight that short-circuits when the embedder
  is unreachable.
- Interrupt semantics that cancel the in-flight embed without
  killing the MCP server (coordinates with FIELD-9).
- A documented backend-parallelism contract (serialized-at-embedder
  vs parallel-safe) so `subagent-dispatch-protocol.md` can pin an
  accurate concurrency rule.

Once v0.7.0 lands, this section is deleted and the relevant
contract details are pinned in the kb_query / kb_search sub-section
of the agent-knowledgebase contract block above.
