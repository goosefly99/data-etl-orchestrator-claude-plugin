# Release gates — sibling plugin status mirror

**This document is a read-only mirror. Authoritative status lives in
the sibling repos listed below.** Refresh the table by reading each
sibling ROADMAP.md and updating the `status` and `upstream` columns.

Last refreshed: 2026-04-17

## Sibling repos

- agent-knowledgebase: `agent_knowledge_base_plugin_dev/` (Python, Stage 1 — ships FIRST)
- youtube-mcp:         `youtube_dev_api/youtube-mcp-dev/` (TypeScript, Stage 2)
- x-api-mcp:           `x-api-mcp-dev/` (TypeScript, Stage 2)

## 15-task status

| Task | Description | Status | Upstream (commit/PR) | Verification |
|------|-------------|--------|----------------------|--------------|
| A1   | Expose dedup_key and dedup_policy as first-class metadata fields | [x] | green — agent_knowledge_base_plugin_dev/src/agent_knowledgebase/server.py L108,109,132-140; models.py L117; database.py L42 — ROADMAP L18 [x] verified 2026-04-17 | `rg -n "dedup_key" agent_knowledge_base_plugin_dev/src/` |
| A2   | Augment kb_list_pages and kb_list_sources with new response fields | [x] | green — models.py L111,121,139-165 (source_type, uri, page_id, source_id); server.py L340-368 docs, L387-398 — ROADMAP L19 [x] verified 2026-04-17 | `rg -n "source_type\|dedup_key\|page_id" agent_knowledge_base_plugin_dev/src/agent_knowledgebase/server.py` |
| A3   | Per-kb_id serialization via asyncio.Lock (single-process-only) | [x] | green — threading.Lock used (justified in docstring L13); knowledgebase.py L133,134,143-158,312-320 — ROADMAP L20 [x] verified 2026-04-17 | `rg -n "threading.Lock" agent_knowledge_base_plugin_dev/src/agent_knowledgebase/services/knowledgebase.py` |
| A4   | Record embedding model per page; dominant_embedding_model in kb_info | [x] | green — models.py L96-103; knowledgebase.py L604,607 — ROADMAP L21 [x] verified 2026-04-17 | `rg -n "dominant_embedding_model" agent_knowledge_base_plugin_dev/src/` |
| Y1   | Batch up to 50 videoIds per videos.list call in hydrate path | [x] | green — src/services/videoBatchFetcher.ts L18 BATCH_SIZE=50; L114 chunking loop; L41 batch call — ROADMAP L14 [x] verified 2026-04-17 | `rg -n "BATCH_SIZE\|batch" youtube_dev_api/youtube-mcp-dev/src/services/videoBatchFetcher.ts` |
| Y2   | Schema migration — additive nullable status columns on videos table | [x] | green — src/db/schema.ts L80-81,83-84,86-87 (metadata_status, transcript_status, transcript_reason); L76-88 idempotent migration — ROADMAP L23 [x] verified 2026-04-17 | `rg -n "metadata_status\|transcript_status" youtube_dev_api/youtube-mcp-dev/src/db/schema.ts` |
| Y3   | Demote get_transcript to cache-read-only (zero outbound HTTP) | [x] | green — src/tools/get-transcript.ts: no transcriptService or youtube-api imports; L5 imports DB repo only; L47 "ZERO outbound HTTP" — ROADMAP L24 [x] verified 2026-04-17 | `rg -n "transcriptService\|youtube-api" youtube_dev_api/youtube-mcp-dev/src/tools/get-transcript.ts` |
| Y4   | Defaults includeTranscript=true, hydrate=true; AGENTS.md alignment | [x] | green — get-video-details.ts L144 `.default(true)`; get-playlist-items.ts L56 `hydrate.default(true)`; L19 HYDRATE_TRANSCRIPT_CONCURRENCY=1 — ROADMAP L15 [x] (concurrency pinning) verified 2026-04-17 | `rg -n "default.*true\|includeTranscript\|hydrate" youtube_dev_api/youtube-mcp-dev/src/tools/` |
| X0   | Crawler-integration decision doc (blocking gate for X1-X6) | [x] | green — x-api-mcp-dev/docs/crawler-integration-decision.md exists (81 lines); adopts option (a) direct library import — ROADMAP L14 [x] verified 2026-04-17 | `test -f x-api-mcp-dev/docs/crawler-integration-decision.md` |
| X1   | articleIngestService with concurrency cap of 4 concurrent crawls | [x] | green — services/articleIngestService.ts L25 DEFAULT_CONCURRENCY=4; L101 cap override; L111 new Semaphore(cap) — ROADMAP L15 [x] verified 2026-04-17 | `rg -n "DEFAULT_CONCURRENCY\|Semaphore" x-api-mcp-dev/services/articleIngestService.ts` |
| X2   | Soft-timeout 15s per article crawl via Promise.race | [x] | green — articleIngestService.ts L26 DEFAULT_TIMEOUT_MS=15_000; L125 Promise.race; L88-91 timeoutResolution() resolves with status=failed,reason=timeout — ROADMAP L16 [x] verified 2026-04-17 | `rg -n "Promise.race\|15_000" x-api-mcp-dev/services/articleIngestService.ts` |
| X3   | One-to-many tweet_articles join table and articles array envelope | [x] | green — db/schema.ts L149-157 CREATE TABLE tweet_articles (composite PK on tweet_id+article_id) — ROADMAP L17 [x] verified 2026-04-17 | `rg -n "tweet_articles" x-api-mcp-dev/db/schema.ts` |
| X4   | Wire articles array envelope through all 5 tweet-returning tools | [x] | green — tools/bookmarks.ts L5,L52; search.ts L5,L41; thread.ts L5,L125; tweets.ts L5,L36,L96 (covers x_get_tweet + x_get_user_tweets) all import resolveArticlesForTweets — ROADMAP L18 [x] verified 2026-04-17 | `rg -n "resolveArticlesForTweets" x-api-mcp-dev/tools/` |
| X5   | Demote x_get_article to cache-read-only (no crawler or X-API calls) | [x] | green — tools/article.ts: zero matches for crawler/xApiService/xApiRequest; L3 imports only DB repo — ROADMAP L20 [x] verified 2026-04-17 | `rg -n "crawler\|xApiService\|xApiRequest" x-api-mcp-dev/tools/article.ts` |
| X6   | Demote x_crawl_article to manual-override with stderr note | [x] | green — tools/crawl.ts L23 `process.stderr.write('[x_crawl_article] manual override — not called by ingest pipeline\n')` — ROADMAP L20 (shared row with X5) [x] verified 2026-04-17 | `rg -n "manual override" x-api-mcp-dev/tools/crawl.ts` |

## Aggregate status

**15/15 green.** Phase 8 publish gate unblocked.

### Breakdown by repo

| Repo | Green | In progress | Not started | Total |
|------|-------|-------------|-------------|-------|
| agent-knowledgebase (A1-A4) | 4 | 0 | 0 | 4 |
| youtube-mcp (Y1-Y4)         | 4 | 0 | 0 | 4 |
| x-api-mcp (X0-X6)           | 7 | 0 | 0 | 7 |
| **Total**                   | **15** | **0** | **0** | **15** |

### Release order reminder

1. A1-A4 (agent-knowledgebase, Stage 1) must land first — gates all downstream.
2. Y1-Y4 and X0-X6 (Stage 2) run in parallel after Stage 1 is live.
3. X0 must merge before X1-X6 within x-api-mcp (internal gate).
4. Phase 8 orchestrator publish is Stage 4 — happens last.

## Verification audit trail (2026-04-17)

All 15 items re-verified today by parallel Explore subagents (one per sibling).
Findings:

- **agent-knowledgebase (A1-A4):** 4/4 code PASS. Line numbers match. threading.Lock
  accepted as equivalent to asyncio.Lock per module docstring justification
  (knowledgebase.py L13 documents rationale).
- **youtube-mcp (Y1-Y4):** 4/4 code PASS. Line numbers match.
  `HYDRATE_TRANSCRIPT_CONCURRENCY=1` confirmed at get-playlist-items.ts L19.
- **x-api-mcp (X0-X6):** 7/7 code PASS. Line numbers match. X5/X6 share
  ROADMAP L20 checkbox (both items in one sentence); checkbox check confirms both.

Sibling ROADMAP checkboxes flipped `[ ] → [x]` on the following lines after verification:

- `agent_knowledge_base_plugin_dev/ROADMAP.md` L18, L19, L20, L21
- `youtube_dev_api/youtube-mcp-dev/ROADMAP.md` L14, L15, L23, L24
- `x-api-mcp-dev/ROADMAP.md` L14, L15, L16, L17, L18, L20

No partial-publish exception taken — all sibling code was already shipped; this
refresh closed a documentation-sync gap between verified implementation and
sibling ROADMAP status markers.
