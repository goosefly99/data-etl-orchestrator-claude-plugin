# Release gates — sibling plugin status mirror

**This document is a read-only mirror. Authoritative status lives in
the sibling repos listed below.** Refresh the table by reading each
sibling ROADMAP.md and updating the `status` and `upstream` columns.

Last refreshed: 2026-04-20 (Phase 5 — v0.3.0 ecosystem cutover, 16/16 target)

## Ecosystem version tags under this grid

- `agent-knowledgebase` — **v0.6.0** (kb ensemble-critical fixes: structured
  stderr helper, `kb_pipeline_status` v2 telemetry row, safe-where-clause
  grammar canonical ref, cross-process-lock recipe doc).
- `youtube-mcp` — **v0.5.0** (classifier helper, hydrate-loop reunify,
  channel_id normalization, retry-semantics doc, pinned fixture).
- `x-api-mcp` — **v0.4.0** (handler-layer wrapper + canary, Playwright
  soft-timeout canary, TweetArticlesEnvelope array reconciliation, zod
  schema, caller audit).
- `data-etl-orchestrator` — **v1.0.0** (contract probe extended to 4 probes
  ensemble, S13 unified-status-vocab grep, 16/16 release-gate grid,
  marketplace-resolution verification, rollback clause).

## Sibling repos

Paths are relative to the orchestrator repo root.

- agent-knowledgebase: `../agent_knowledge_base_plugin_dev/` (Python, Stage 1 — ships FIRST)
- youtube-mcp:         `../youtube-mcp-dev/` (TypeScript, Stage 2)
- x-api-mcp:           `../x-api-mcp-dev/` (TypeScript, Stage 2)

## 16-task status

| Task | Description | Status | Upstream (commit/PR) | Verification |
|------|-------------|--------|----------------------|--------------|
| A1   | Expose dedup_key and dedup_policy as first-class metadata fields | [x] | green — ../agent_knowledge_base_plugin_dev/src/agent_knowledgebase/server.py L108,109,132-140; models.py L117; database.py L42 — ROADMAP L18 [x] verified 2026-04-17 | `rg -n "dedup_key" ../agent_knowledge_base_plugin_dev/src/` |
| A2   | Augment kb_list_pages and kb_list_sources with new response fields | [x] | green — models.py L111,121,139-165 (source_type, uri, page_id, source_id); server.py L340-368 docs, L387-398 — ROADMAP L19 [x] verified 2026-04-17 | `rg -n "source_type\|dedup_key\|page_id" ../agent_knowledge_base_plugin_dev/src/agent_knowledgebase/server.py` |
| A3   | Per-kb_id serialization via asyncio.Lock (single-process-only) | [x] | green — threading.Lock used (justified in docstring L13); knowledgebase.py L133,134,143-158,312-320 — ROADMAP L20 [x] verified 2026-04-17 | `rg -n "threading.Lock" ../agent_knowledge_base_plugin_dev/src/agent_knowledgebase/services/knowledgebase.py` |
| A4   | Record embedding model per page; dominant_embedding_model in kb_info | [x] | green — models.py L96-103; knowledgebase.py L604,607 — ROADMAP L21 [x] verified 2026-04-17 | `rg -n "dominant_embedding_model" ../agent_knowledge_base_plugin_dev/src/` |
| A5   | Structured `knowledgebase_stderr_log` helper + per-source ingest routing (v0.6.0) | [x] | green — services/stderr_log.py (single-line JSON stderr emitter); lock diagnostics + ingest-source outcomes routed through helper (kb CHANGELOG v0.6.0 § Added/Changed) — verified 2026-04-20 | `rg -n "knowledgebase_stderr_log" ../agent_knowledge_base_plugin_dev/src/` |
| A6   | Expanded `pipeline_runs` telemetry row (9 additive nullable cols) (v0.6.0) | [x] | green — 9 new columns (ended_at, ingested, skipped, replaced, failed, batch_size, dedup_policy, request_id, tool_caller_version); idempotent migration; `kb_pipeline_status(kb_id)` signature preserved — verified 2026-04-20 | `rg -n "ended_at\|tool_caller_version\|request_id" ../agent_knowledge_base_plugin_dev/src/` |
| A7   | Cross-process-lock recipe doc (single-process limit + sentinel file recipe) (v0.6.0) | [x] | green — doc ships in kb repo; references `threading.Lock` single-process scope + advisory-lock fallback recipe — verified 2026-04-20 | `test -f ../agent_knowledge_base_plugin_dev/docs/cross-process-lock-recipe.md` |
| Y1   | Batch up to 50 videoIds per videos.list call in hydrate path | [x] | green — src/services/videoBatchFetcher.ts L18 BATCH_SIZE=50; L114 chunking loop; L41 batch call — ROADMAP L14 [x] verified 2026-04-17 | `rg -n "BATCH_SIZE\|batch" ../youtube-mcp-dev/src/services/videoBatchFetcher.ts` |
| Y2   | Schema migration — additive nullable status columns on videos table | [x] | green — src/db/schema.ts L80-81,83-84,86-87 (metadata_status, transcript_status, transcript_reason); L76-88 idempotent migration — ROADMAP L23 [x] verified 2026-04-17 | `rg -n "metadata_status\|transcript_status" ../youtube-mcp-dev/src/db/schema.ts` |
| Y3   | Demote get_transcript to cache-read-only (zero outbound HTTP) | [x] | green — src/tools/get-transcript.ts: no transcriptService or youtube-api imports; L5 imports DB repo only; L47 "ZERO outbound HTTP" — ROADMAP L24 [x] verified 2026-04-17 | `rg -n "transcriptService\|youtube-api" ../youtube-mcp-dev/src/tools/get-transcript.ts` |
| Y4   | Defaults includeTranscript=true, hydrate=true; AGENTS.md alignment | [x] | green — get-video-details.ts L144 `.default(true)`; get-playlist-items.ts L56 `hydrate.default(true)`; L19 HYDRATE_TRANSCRIPT_CONCURRENCY=1 — ROADMAP L15 [x] (concurrency pinning) verified 2026-04-17 | `rg -n "default.*true\|includeTranscript\|hydrate" ../youtube-mcp-dev/src/tools/` |
| Y5   | Shared `classifyTranscriptError` classifier helper (v0.5.0) | [x] | green — src/services/transcriptClassifier.ts consolidates the two previously duplicated inline matcher blocks (get-video-details.ts + get-playlist-items.ts); narrowed vocabulary: only `no captions`/`captions disabled`/`http 404` route to `missing`; everything else `failed` — verified 2026-04-20 | `rg -n "classifyTranscriptError" ../youtube-mcp-dev/src/` |
| Y6   | Hydrate-loop reunify + `channelId` normalization (v0.5.0) | [x] | green — get-playlist-items.ts hydrate loop delegates to `fetchAndStoreVideo(id, true, {preFetchedDetails, source: "get_playlist_items"})`; videos repo writes `video.channelId ?? null` (hardcoded null + multi-line TODO removed); HYDRATE_TRANSCRIPT_CONCURRENCY=1 preserved; `2*ceil(N/50)` quota formula preserved via preFetchedDetails — verified 2026-04-20 | `rg -n "fetchAndStoreVideo\|preFetchedDetails\|channelId" ../youtube-mcp-dev/src/` |
| Y7   | Transcript retry-semantics doc + pinned fixture (v0.5.0) | [x] | green — docs/transcript-retry-semantics.md (authoritative retry table, caller retry policy, DB-mapping notes); additive `summary` block on `get_playlist_items` response; pinned fixture test `src/tests/aDWJ6lLemJU.test.ts` — verified 2026-04-20 | `test -f ../youtube-mcp-dev/docs/transcript-retry-semantics.md && test -f ../youtube-mcp-dev/src/tests/aDWJ6lLemJU.test.ts` |
| X0   | Crawler-integration decision doc (blocking gate for X1-X6) | [x] | green — ../x-api-mcp-dev/docs/crawler-integration-decision.md exists (81 lines); adopts option (a) direct library import — ROADMAP L14 [x] verified 2026-04-17 | `test -f ../x-api-mcp-dev/docs/crawler-integration-decision.md` |
| X1   | articleIngestService with concurrency cap of 4 concurrent crawls | [x] | green — services/articleIngestService.ts L25 DEFAULT_CONCURRENCY=4; L101 cap override; L111 new Semaphore(cap) — ROADMAP L15 [x] verified 2026-04-17 | `rg -n "DEFAULT_CONCURRENCY\|Semaphore" ../x-api-mcp-dev/services/articleIngestService.ts` |
| X2   | Soft-timeout 15s per article crawl via Promise.race | [x] | green — articleIngestService.ts L26 DEFAULT_TIMEOUT_MS=15_000; L125 Promise.race; L88-91 timeoutResolution() resolves with status=failed,reason=timeout — ROADMAP L16 [x] verified 2026-04-17 | `rg -n "Promise.race\|15_000" ../x-api-mcp-dev/services/articleIngestService.ts` |
| X3   | One-to-many tweet_articles join table and articles array envelope | [x] | green — db/schema.ts L149-157 CREATE TABLE tweet_articles (composite PK on tweet_id+article_id) — ROADMAP L17 [x] verified 2026-04-17 | `rg -n "tweet_articles" ../x-api-mcp-dev/db/schema.ts` |
| X4   | Wire articles array envelope through all 5 tweet-returning tools | [x] | green — tools/bookmarks.ts L5,L52; search.ts L5,L41; thread.ts L5,L125; tweets.ts L5,L36,L96 (covers x_get_tweet + x_get_user_tweets) all import resolveArticlesForTweets — ROADMAP L18 [x] verified 2026-04-17 | `rg -n "resolveArticlesForTweets" ../x-api-mcp-dev/tools/` |
| X5   | Demote x_get_article to cache-read-only (no crawler or X-API calls) | [x] | green — tools/article.ts: zero matches for crawler/xApiService/xApiRequest; L3 imports only DB repo — ROADMAP L20 [x] verified 2026-04-17 | `rg -n "crawler\|xApiService\|xApiRequest" ../x-api-mcp-dev/tools/article.ts` |
| X6   | Demote x_crawl_article to manual-override with stderr note | [x] | green — tools/crawl.ts L23 `process.stderr.write('[x_crawl_article] manual override — not called by ingest pipeline\n')` — ROADMAP L20 (shared row with X5) [x] verified 2026-04-17 | `rg -n "manual override" ../x-api-mcp-dev/tools/crawl.ts` |
| X7   | Handler-layer `withFailureIsolation` wrapper + metric row (v0.4.0) | [x] | green — services/handlerWrapper.ts `withFailureIsolation<T>(name, tweetCount, fn, opts?)`; soft-timeout race (default 15_000 ms); parent-tweet upsert always runs; structured JSON stderr metric row per call — verified 2026-04-20 | `rg -n "withFailureIsolation\|articles_attempted" ../x-api-mcp-dev/services/` |
| X8   | TweetArticlesEnvelope array-shape reconciliation + zod schema (v0.4.0) | [x] | green — envelope is `Array<{ tweetId: string; articles: ArticleResolution[] }>` (no longer Map); `tweetArticlesEnvelopeSchema` zod schema exported from `types.ts`; all 5 tweet-returning handlers updated; `articleResolutionSchema` exported from `services/articleTypes.ts` — verified 2026-04-20 | `rg -n "tweetArticlesEnvelopeSchema\|ArticleResolution\[\]" ../x-api-mcp-dev/` |
| X9   | `PLAYWRIGHT_SOFT_TIMEOUT_WIN` canary metric emission (v0.4.0) | [x] | green — services/articleIngestService.ts emits structured stderr JSON on soft-timeout win: `{plugin:'x-api', error_code:'PLAYWRIGHT_SOFT_TIMEOUT_WIN', open_sockets_count, browser_context_id, tweet_id, elapsed_ms}`; `browser_context_id` coarse `ctx-N` counter from `getBrowserContextId()`; test `tests/services/playwright-canary.test.ts` asserts one emission per soft-timeout win, none on clean resolver win — verified 2026-04-20 | `rg -n "PLAYWRIGHT_SOFT_TIMEOUT_WIN\|browser_context_id" ../x-api-mcp-dev/services/` |
| E1   | Ensemble contract-probe (probe 4) — envelope zod, unified status vocab, stderr shape, silent-DB-failure canary, dedup_key polymorphism | [x] | green — `skills/references/contract-probe-protocol.md` Probe 4 lands 5 assertions (a-e) on a shared canary call; 100 ms stderr deadline on assertion (d) turns silent-DB failure into surfaced failure; failure template names kb/yt/x-api version floors; version-floor line `kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0` (Phase 4, commits dd7dc51 + 6d37626) — verified 2026-04-20 | `rg -n "Probe 4\|ensemble-contract" skills/references/contract-probe-protocol.md` |

## Aggregate status

**16/16 green.** Orchestrator v1.0.0 publish gate unblocked pending marketplace-resolution + week-one monitoring (see Phase 6 subsections below).

### Breakdown by repo

| Repo | Green | In progress | Not started | Total |
|------|-------|-------------|-------------|-------|
| agent-knowledgebase (A1-A7) | 7 | 0 | 0 | 7 |
| youtube-mcp (Y1-Y7)         | 7 | 0 | 0 | 7 |
| x-api-mcp (X0-X9)           | 10 | 0 | 0 | 10 |
| Ensemble probe (E1)         | 1 | 0 | 0 | 1 |
| **Total**                   | **16** | **0** | **0** | **16** |

Note: the grid contains 25 rows (A1-A7 + Y1-Y7 + X0-X9 + E1) but the
release-gate headline is 16/16. The 16 reflects the pre-Phase-5 gate
scope (A1-A4 + Y1-Y4 + X0-X6 = 15 original tasks, plus E1 the new
ensemble probe). The 9 rows added in Phase 5 (A5-A7, Y5-Y7, X7-X9)
are v0.3.0 implementation tasks tracked here for completeness but
counted separately from the 16 gate tasks. All 25 rows are green;
the 16/16 gate count is met.

### Release order reminder

1. A1-A4 (agent-knowledgebase, Stage 1) must land first — gates all downstream.
2. Y1-Y4 and X0-X6 (Stage 2) run in parallel after Stage 1 is live.
3. X0 must merge before X1-X6 within x-api-mcp (internal gate).
4. Phase 8 orchestrator publish is Stage 4 — happens last.

**Ecosystem v0.3.0 order (extends the above):**
5. A5-A7 ship inside kb v0.6.0 — part of the kb-first Stage 1 drop.
6. X7-X9 ship inside x-api v0.4.0 — gates the yt v0.5.0 drop (Phase 2a → Phase 2b).
7. Y5-Y7 ship inside yt v0.5.0 — runs after X7-X9 since yt tests consume the
   x-api handler-layer metric vocabulary.
8. E1 (probe 4) ships inside orchestrator v1.0.0 — requires all three
   sibling v0.3.0 tags to exist so the failure template can name them by floor.
9. Orchestrator v1.0.0 tag lands only after the marketplace-resolution
   verification gate (Phase 6 subsection below) confirms all three sibling
   v0.3.0 tags have resolved in marketplace `goosefly99-plugins-auto-dev`.

## Install-order cross-check (Phase 5 sub-task)

**Purpose.** The probe-4 failure template in
`skills/references/contract-probe-protocol.md` names three sibling version
floors that users must install before re-running. If any sibling README
drifts from those floors — by typo or accidental version bump — probe 4
will tell the user to install a version that does not exist, or worse, a
floor that does not match the actual invariant the probe enforces.

This sub-task is a **character-for-character** gate (SC12): each sibling
README must contain its exact version floor, matching the probe-4 upgrade
message text verbatim.

### Expected matches

| Sibling | Probe-4 upgrade text | Sibling README must contain |
|---------|----------------------|------------------------------|
| agent-knowledgebase | `kb >= 0.6.0` | `0.6.0` (reference to v0.6.0 version floor) |
| youtube-mcp         | `yt >= 0.5.0` | `0.5.0` (reference to v0.5.0 version floor) |
| x-api-mcp           | `x-api >= 0.4.0` | `0.4.0` (reference to v0.4.0 version floor) |

Source of truth for probe-4 upgrade text: `skills/references/contract-probe-protocol.md` L120 "Probe 4 requires `kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0` simultaneously" and L112-114 ("Required sibling version floors" block).

### Cross-check procedure

Run from the orchestrator repo root (requires siblings checked out alongside
per `README.md § Install`):

```bash
# Probe-4 version-floor strings present in contract-probe-protocol.md?
rg "kb >= 0\.6\.0"      skills/references/contract-probe-protocol.md  # expect >= 1
rg "yt >= 0\.5\.0"      skills/references/contract-probe-protocol.md  # expect >= 1
rg "x-api >= 0\.4\.0"   skills/references/contract-probe-protocol.md  # expect >= 1

# Sibling READMEs reference their version floors?
rg "0\.6\.0" ../agent_knowledge_base_plugin_dev/README.md              # expect >= 1
rg "0\.5\.0" ../youtube-mcp-dev/README.md                              # expect >= 1
rg "0\.4\.0" ../x-api-mcp-dev/README.md                                # expect >= 1
```

Zero hits on any of the six probes FAILS the phase. Cross-check must pass
before the orchestrator v1.0.0 tag is cut.

## Marketplace-resolution verification (Phase 6 sub-task, R12)

**Purpose.** Marketplace publish is not atomic — the three sibling v0.3.0 tags
land over multiple minutes, and the orchestrator contract-probe expects all
three to be resolvable from `goosefly99-plugins-auto-dev` before it runs.
Tagging orchestrator v1.0.0 while any sibling tag is still unresolved would
ship a contract probe that tells users to install a version that marketplace
cannot serve yet (R12 — marketplace publish partial atomicity).

**Gate.** `scripts/verify-marketplace-resolution.sh` MUST exit 0 before the
orchestrator v1.0.0 tag is cut. The script queries marketplace for each of
the three sibling plugin latest versions and fails if any one differs from
the expected floor (`agent-knowledgebase=0.6.0`, `youtube-mcp=0.5.0`,
`x-api-mcp=0.4.0`).

### Manual fallback (until marketplace CLI lands)

If `claude plugin query` (or the equivalent marketplace CLI) is not yet
available, run the fallback checklist manually:

1. Open the `goosefly99-plugins-auto-dev` marketplace entry for
   `agent-knowledgebase-auto-dev`. Confirm latest published version is
   `0.6.0` (or higher).
2. Repeat for `youtube-mcp-auto-dev` — expect `0.5.0` (or higher).
3. Repeat for `x-api-mcp-auto-dev` — expect `0.4.0` (or higher).
4. In a clean install environment (fresh `~/.claude/plugins/`), run
   `/plugin install agent-knowledgebase-auto-dev`, then `youtube-mcp-auto-dev`,
   then `x-api-mcp-auto-dev`, then `data-etl-orchestrator` (per README
   install order), and confirm each sibling self-reports its version floor
   via `kb_info` / `get_video_details` / `x_get_tweet` probes (see Probes 1-3).
5. Log the manual verification timestamp + operator in `cron-log.md` with
   the decision record.

Fallback completion is equivalent to the script exiting 0.

## Pre-tag checklist (Phase 6)

Before cutting the orchestrator v1.0.0 tag, confirm each item in the same
commit as the tag (or immediately preceding):

- [ ] Bump `.claude-plugin/plugin.json` version from `0.2.0` to `1.0.0` in the same commit as the v1.0.0 tag (or immediately preceding).
- [ ] `scripts/verify-marketplace-resolution.sh` exits 0 (or the manual fallback above is logged in `cron-log.md`).
- [ ] `CHANGELOG.md` v1.0.0 section is promoted out of `Unreleased` with the tag date.
- [ ] Install-order cross-check (six `rg` probes above) all return at least one hit.

## Rollback clause (Phase 6)

**Trigger.** If week-one post-cutover monitoring surfaces any probe-4
regression — assertion (a), (b), (c), (d), or (e) failing on live user
runs — the orchestrator tag STAYS at `v0.3.0-rc.1` (the pre-cutover
release-candidate) until a patched v1.0.x ships with the regression
closed.

**Scope.** Rollback applies to the orchestrator plugin only. The sibling
plugins (kb v0.6.0, yt v0.5.0, x-api v0.4.0) are not rolled back — their
contract surfaces are already live and consumers depend on the new
behavior (envelope shape, unified status vocabulary, structured stderr).

**Rollback record.** Log the rollback decision in `cron-log.md`:

- Date of decision + monitoring window (e.g. `2026-04-21..2026-04-28`).
- Failing assertion (a/b/c/d/e) and observed value.
- Affected sibling (if the root cause isolates to one).
- Patch target (v1.0.1, v1.1.0, or v0.3.0-rc.2) and expected ETA.
- Link to the bug ticket or issue that tracks the fix.

**Monitoring scope.** Week-one monitoring draws from:

- Consumer-side every-call stderr capture logs (R1 mitigation) — siblings'
  AGENTS.md / README.md explicitly instruct callers to tee stderr per
  request and never fire-and-forget.
- User bug reports filed against the orchestrator repo within 7 days of
  the v1.0.0 tag.
- The 100 ms stderr deadline in probe-4 assertion (d) — any user report of
  the deadline firing on a write that should have succeeded is a regression
  signal.

If no regression surfaces by the end of the week-one window, the rollback
clause is marked `HONORED — no action` and v1.0.0 remains the stable tag.

## Verification audit trail (2026-04-17 + 2026-04-20 refresh)

All 15 original items re-verified 2026-04-17 by parallel Explore subagents
(one per sibling). The 9 new rows (A5-A7, Y5-Y7, X7-X9, E1) were verified
2026-04-20 as part of the Phase 5 grid refresh. Findings:

- **agent-knowledgebase (A1-A7):** 7/7 code PASS. A1-A4 from 2026-04-17
  audit still green; A5 (structured stderr helper), A6 (9-column telemetry
  row with preserved `kb_pipeline_status` signature), A7 (cross-process-lock
  recipe doc) added 2026-04-20 per kb CHANGELOG v0.6.0 § Added/Changed.
  `threading.Lock` still accepted as equivalent to asyncio.Lock per module
  docstring justification.
- **youtube-mcp (Y1-Y7):** 7/7 code PASS. Y1-Y4 from 2026-04-17 audit still
  green; Y5 (classifier helper — single source of truth), Y6 (hydrate-loop
  reunify + `channelId ?? null`), Y7 (retry-semantics doc + pinned fixture)
  added 2026-04-20 per yt CHANGELOG v0.5.0. `HYDRATE_TRANSCRIPT_CONCURRENCY=1`
  and `2*ceil(N/50)` quota formula preserved via `preFetchedDetails` seam.
- **x-api-mcp (X0-X9):** 10/10 code PASS. X0-X6 from 2026-04-17 audit still
  green; X7 (`withFailureIsolation` wrapper), X8 (array-shape envelope +
  zod schema), X9 (`PLAYWRIGHT_SOFT_TIMEOUT_WIN` canary) added 2026-04-20
  per x-api CHANGELOG v0.4.0. X5/X6 still share ROADMAP L20 checkbox.
- **Ensemble (E1):** 1/1 code PASS. Probe 4 with assertions (a)-(e) landed
  in `skills/references/contract-probe-protocol.md` in Phase 4; version
  floor line `kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0` present at L120
  and L136. 100 ms stderr deadline on assertion (d) is the BUG-6 mitigation.

Sibling ROADMAP checkboxes flipped `[ ] → [x]` on the following lines after
verification (2026-04-17 baseline preserved):

- `../agent_knowledge_base_plugin_dev/ROADMAP.md` L18, L19, L20, L21 (A1-A4)
- `../youtube-mcp-dev/ROADMAP.md` L14, L15, L23, L24 (Y1-Y4)
- `../x-api-mcp-dev/ROADMAP.md` L14, L15, L16, L17, L18, L20 (X0-X6)

No partial-publish exception taken — all sibling code was already shipped;
this refresh closed a documentation-sync gap between verified implementation
and sibling ROADMAP status markers.
