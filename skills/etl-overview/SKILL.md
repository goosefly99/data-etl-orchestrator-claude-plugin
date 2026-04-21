---
name: etl-overview
description: "Router + Stage-0 questionnaire for ETL into the agent-knowledgebase. Use when the user asks to ingest YouTube videos/playlists, X bookmarks/threads/user tweets, local files, or crawled pages into a KB. Asks full config up front via AskUserQuestion, then dispatches to the right sub-skill."
---

## When to use this skill

Invoke when the user says any of:
- "ingest [source] into my KB / knowledgebase"
- "load [playlist / videos / bookmarks / tweets] into [KB name]"
- "add these YouTube videos / X bookmarks to my knowledge base"
- `/etl-overview`
- Alternatively, run `/etl-config` to answer only the Stage-0 questionnaire, then `/etl-overview` to execute with those answers.

Do not invoke if a more specific sub-skill is already running and Stage 0 is complete.

---

## Stage 0 — Preflight questionnaire (mandatory)

Issue ALL questions via `AskUserQuestion` before touching any data tool. Do not proceed to Stage 1 until explicit confirmation is received.

**Question groups** (ask as a single multi-part prompt or sequentially as needed):

1. **Target KB** — Which KB should this go into? List existing KBs from `kb_list`. If new, what name/slug?
2. **Source selection** — What are you ingesting? (YouTube playlist URL/ID, list of video IDs/URLs, X bookmarks, X user tweets, local files, crawled pages.) Collect all per-source params (playlist ID, video IDs, X handle, page count, date range, etc.).
3. **DB path override** — Confirm or override the source DB path:
   - YouTube MCP default: `W:\youtube_mcp_db\youtube-data.db` (env: `YOUTUBE_MCP_DB_PATH`)
   - X API MCP default: `~/.x-api-mcp/x-data.db` (env: `X_API_DB_PATH`)
4. **KB ingest granularity** — One KB source per item (video/tweet) or one per batch?
5. **Dedup policy** — If an item already exists in the KB: skip / re-ingest / force-add?
6. **Embeddings model** — Which embeddings model endpoint to use for the KB records if the default ollama embeddings model is not available?
7. **Confirmation** — Echo the resolved plan (source, item count estimate, target KB, DB path, granularity, dedup policy, embeddings model). Ask for explicit go-ahead.

**Stage-0 warmup (pre-Q1).** Before Q1, run the 4 pre-Q1 environment
probes documented in `references/preflight-questionnaire.md` §
Stage-0 warmup: (1) embedder reachability via
`scripts/check-embedder.{sh,ps1}`; (2) Ollama cold-start warmup for
local embedders; (3) routing canary (`row_selector="1=0"` single-
source `kb_ingest_batch`) in lieu of the uninformative
`kb_config_show scope=env`; (4) retrieval-flow gate for runs that
will call `kb_query`/`kb_search`. Halt Stage-0 on any probe failure.

Block all Stage 1+ operations until the go-ahead is received.

See `references/preflight-questionnaire.md` for the canonical question spec.

---

## Contract probe (post-Stage-0, pre-dispatch)

After Stage-0 confirmation is received (Q7 go-ahead), but BEFORE dispatching to any sub-skill:

1. Run the 4 contract probe calls defined in `references/contract-probe-protocol.md`.
   - Probes 1-3 exercise the 3 sibling MCPs individually (kb, yt, x-api).
   - Probe 4 runs only if probes 1-3 all pass, and asserts the 5 ensemble invariants (envelope shape, unified status vocabulary, kb stderr log shape, silent-DB-failure canary within 100 ms, and `dedup_key` polymorphism) on the same canary call.
2. If any probe fails, halt immediately and emit the structured error message specified in that document. Do not dispatch to a sub-skill.
3. If the user said "skip contract probe" during Stage 0, skip this step but log a warning in the deliverable noting that probes were skipped.

See `references/contract-probe-protocol.md` for the full probe spec (tool names, expected responses, and error message format, including probe-4's 5 assertions and the `kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0` version floor).

---

## Routing table

After Stage 0 confirms the source type, dispatch to:

| Source | Sub-skill |
|---|---|
| YouTube playlist (ID or URL) | `ingest-youtube-playlist` |
| YouTube video list (IDs / URLs / channel) | `ingest-youtube-videos` |
| X bookmarks | `ingest-x-bookmarks` |
| X user tweets | `ingest-x-user-tweets` |
| X thread (tweet URL/ID with thread intent) | `ingest-x-thread` |
| DB-to-KB standalone ("load DB into KB") | `load-kb-from-sql` |
| Local files | `ingest-local-files` |
| Crawled pages | _(not yet implemented — inform user)_ |

---

## Router contract

This section defines the invariants a future agent can rely on when
invoking the etl-overview router.

### Single sub-skill per run

Every invocation dispatches to exactly one of the 7 ingest sub-skills
(`ingest-local-files`, `ingest-x-bookmarks`, `ingest-x-thread`,
`ingest-x-user-tweets`, `ingest-youtube-playlist`,
`ingest-youtube-videos`, `load-kb-from-sql`). Composite runs that
chain multiple sub-skills within a single etl-overview dispatch are
explicitly out of v1 scope. To ingest multiple source types into the
same knowledge base, invoke etl-overview multiple times.

### Concurrent knowledge-base serialization

When two runs target the same `kb_id`, the agent-knowledgebase MCP's
per-`kb_id` lock serializes them (queue-then-retry). The orchestrator
itself does not coordinate — it relies on agent-knowledgebase to
reject concurrent writes and to retry on the caller's behalf. See
the A3 per-`kb_id` lock in `agent_knowledge_base_plugin_dev/`.

### Article-subfetch partial success

For X ingest sub-skills that trigger server-side article auto-crawl,
the per-tweet `articles: Article[]` envelope reports mixed outcomes
without failing the parent tweet insert. The semantics are
normatively documented in
[mcp-tool-contracts.md](../references/mcp-tool-contracts.md) (article
envelope section); do not re-inline that text here.

### Stage-0 / deliverable-format invariants

Every dispatch first runs the Stage-0 questionnaire
([preflight-questionnaire.md](../references/preflight-questionnaire.md))
and then the contract probe
([contract-probe-protocol.md](../references/contract-probe-protocol.md)).
Every sub-skill emits a deliverable conforming to
[deliverable-format.md](../references/deliverable-format.md).
Per-source dedup semantics are pinned in
[idempotency-and-dedup.md](../references/idempotency-and-dedup.md).

---

## Deliverable format

Every dispatch emits the standard ETL deliverable. See
[deliverable-format.md](../references/deliverable-format.md) for the 6-section template
and the per-item partial-success row shape.

---

## Critical — do not do these things

- Do NOT read or write payload bytes (transcripts, tweet text, article body) to `.md` files as an intermediate step.
- Do NOT use `source_type="file"` for transcripts, tweets, or articles fetched from the MCP servers.
- Do NOT call `get_transcript` or `x_get_article` / `x_crawl_article` in the main ingest path; those are standalone accessors.
- Do NOT interleave Stage 1 fetch and Stage 3 ingest; collect the full work list first.
- Do NOT invoke Stage 1+ before Stage 0 confirmation is received.

---

## References

- `references/preflight-questionnaire.md` — canonical Stage 0 question spec
- `references/contract-probe-protocol.md` — contract probe spec
- `references/mcp-tool-contracts.md` — authoritative tool signatures and response envelopes (including articles: Article[])
- `references/deliverable-format.md` — canonical 6-section output format
- `references/idempotency-and-dedup.md` — dedup keys per source and re-run policy
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/INDEX.md` — discoverability index of all reference docs (added by Phase 4)
