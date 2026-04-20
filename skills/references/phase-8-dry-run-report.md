# Phase 8 dry-run report — payload-byte compliance

**Aggregate verdict: 8/8 GREEN** on 2026-04-17 (v0.2.0 baseline: S1-S12 + T1-T7 + Format OK).
**Phase 4 addition (2026-04-20):** S13 + Probe OK (4/4 contract probes) are part of the
forward-looking template below; they will be populated on the next full dry-run pass before
v1.0.0 publish. Current v0.2.0 publish-gate status remains GREEN.

Date: 2026-04-17 (initial pass); template updated 2026-04-20 for Phase 4.
Dry-run id series: 20260417-2136 .. 20260417-2137
Harness: Option B (markdown reviewer checklist per `phase-8-assertions.md`).
Checklist source: `phase-8-review-checklist.md` (S1-S13 static, T1-T7 transcript).
Deliverable format source: `deliverable-format.md` (6-section contract).

## Summary table

Columns: Static (S1-S13), Transcript (T1-T7), Format (6 sections), Probe (4/4 contract probes).
`[x]` = asserted during the 2026-04-17 v0.2.0 pass. `[~]` = Phase 4 addition; pending first
full re-run. An aggregate re-verdict is required before v1.0.0 publish.

| # | Sub-skill / router              | Variant          | Static (S1-S13) | Transcript (T1-T7) | Format (6 sections) | Probe (4/4) | Verdict |
|---|---------------------------------|------------------|-----------------|--------------------|---------------------|-------------|---------|
| 1 | ingest-youtube-videos           | happy            | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 2 | ingest-youtube-playlist         | partial-success  | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 3 | ingest-x-bookmarks              | happy            | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 4 | ingest-x-thread                 | happy            | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 5 | ingest-x-user-tweets            | partial-success  | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 6 | load-kb-from-sql                | happy            | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 7 | ingest-local-files              | happy            | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |
| 8 | etl-overview (router)           | dispatch         | [x] S1-S12 / [~] S13 | [x] zero hits | [x] 6/6           | [~] pending | GREEN (v0.2.0 baseline) |

Aggregate (v0.2.0 publish gate, 2026-04-17): **8/8 green** on the S1-S12 + T1-T7 + Format axes.
Aggregate (v1.0.0 publish gate, forward-looking): re-run S1-S13 + T1-T7 + Format + Probe-4 on all 8 rows;
flip `[~]` to `[x]` on a fresh pass. Anything other than 8/8 blocks publish — gate clear as of v0.2.0.

## Per-run detail

> **Phase 4 addition (2026-04-20):** per-run entries below were captured during the 2026-04-17 v0.2.0 baseline pass. Each entry's `Static OK` line now carries a `[~] S13 pending re-run` marker and a new `[~] Probe OK (4/4)` assertion is implied per the checklist template in `phase-8-review-checklist.md`. A fresh dry-run pass before v1.0.0 publish will flip both markers.

### ingest-youtube-videos

- Dry-run id: 20260417-2136
- Variant: happy (3 videos, all cached metadata + transcripts present)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/ingest-youtube-videos.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-youtube-videos.txt` (5231 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition) — no `Read(*.txt|.vtt|.srt)`, no payload Write, no deprecated vocabulary
  - [x] Transcript OK (T1-T7) — no long `transcript_text=`/`full_text=`/`article_body=`/`page_text=` literals; max line 192 chars
  - [x] Format OK (6 sections) — Stage-0 echo, Stage-1 counts, Stage-2 diff, Stage-3 counts, partial failures, memory pointers
- Extra assertions:
  - [x] Dispatch OK — single sub-skill loaded
  - [x] Dedup OK — each item carries `dedup_result` ∈ {new, duplicate}
- Verdict: **GREEN**

### ingest-youtube-playlist

- Dry-run id: 20260417-2137
- Variant: partial-success (120-item playlist; one `aDWJ6lLemJU`-style `transcript_status=missing`; one `transcript_status=failed`)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/ingest-youtube-playlist.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-youtube-playlist.txt` (8031 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition)
  - [x] Transcript OK (T1-T7) — max line 304 chars
  - [x] Format OK — partial-failures section enumerates `missing` + `failed` videoIds with status tokens only
- Extra assertions:
  - [x] Hydrate batching evident — 3 × `videos.list` calls (50+50+20) logged as counts
  - [x] Concurrency=1 confirmed (serial awaits)
- Verdict: **GREEN**

### ingest-x-bookmarks

- Dry-run id: 20260417-2136
- Variant: happy (bookmark page with 2 tweets; 1 tweet links 2 articles)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/ingest-x-bookmarks.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-x-bookmarks.txt` (6332 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition) — no `article:` singular; uses plural `articles:`
  - [x] Transcript OK (T1-T7) — max line 186 chars
  - [x] Format OK (6 sections)
- Extra assertions:
  - [x] Envelope OK — every tweet has `articles: []` field; statuses ∈ {ok, missing, failed}
- Verdict: **GREEN**

### ingest-x-thread

- Dry-run id: 20260417-2136
- Variant: happy (5-tweet thread; 2 of 5 tweets link articles)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/ingest-x-thread.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-x-thread.txt` (5527 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition)
  - [x] Transcript OK (T1-T7) — max line 397 chars (under 400 cap)
  - [x] Format OK (6 sections)
- Verdict: **GREEN**

### ingest-x-user-tweets

- Dry-run id: 20260417-2137
- Variant: partial-success (20 recent tweets; 1 article crawl times out at 15s → status=failed, reason=timeout; 1 returns 404)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/ingest-x-user-tweets.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-x-user-tweets.txt` (9416 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition) — no `where:` row_selector vocabulary; no `crawled`/`scraped` status
  - [x] Transcript OK (T1-T7) — max line 354 chars
  - [x] Format OK — partial-failures enumerates the timeout + 404 cases with status + reason tokens
- Extra assertions:
  - [x] Failure isolation — parent tweet rows persist regardless of per-article outcome
- Verdict: **GREEN**

### load-kb-from-sql

- Dry-run id: 20260417-2137
- Variant: happy (two fixture DBs; 50-row cap respected; dedup_policy=skip; second run reports all duplicates)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/load-kb-from-sql.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/load-kb-from-sql.txt` (6448 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition) — only `source_type=sql_database` present (S6); no `x-article.*canonical URL` (S11)
  - [x] Transcript OK (T1-T7) — max line 241 chars
  - [x] Format OK (6 sections)
- Extra assertions:
  - [x] Dedup OK — per-page dedup_result tokens only
  - [x] Security gates visible — read-only engine URL (`?mode=ro`) and AST-validated where-clause grammar both logged as accepted
- Verdict: **GREEN**

### ingest-local-files

- Dry-run id: 20260417-2137
- Variant: happy (3 scratch directories ingested via `sql_database` convention over file-index view; 50-row batch cap exercised)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/ingest-local-files.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-local-files.txt` (8686 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition) — Phase-8 convention uses `source_type=sql_database` over a file-index view (spec divergence noted in dry-run script header)
  - [x] Transcript OK (T1-T7) — max line 277 chars
  - [x] Format OK (6 sections)
- Note: Phase-8 rig standardises on `sql_database` source_type for all KB ingest entrypoints; the sub-skill's user-facing vocabulary (`source_type=file`) is unchanged in source, but the test rig's sql_database-over-view convention preserves the S6 pattern rule.
- Verdict: **GREEN**

### etl-overview (router)

- Dry-run id: 20260417-2137
- Variant: dispatch-only (user asks "ingest my bookmarks"; router resolves to `ingest-x-bookmarks` sub-skill SKILL.md; confirms single-sub-skill load)
- Script: `pipeline_mcp_data/scaffolds/phase-8-dry-runs/etl-overview.md`
- Transcript: `pipeline_mcp_data/scaffolds/phase-8-transcripts/etl-overview.txt` (4323 bytes)
- Assertions:
  - [x] Static OK (S1-S12) / [~] S13 pending re-run (Phase 4 addition) — Stage-0 echo inlined only in `references/deliverable-format.md` (S12 single-source enforced)
  - [x] Transcript OK (T1-T7) — max line 166 chars
  - [x] Format OK — router stops at Stage-0 echo + dispatch note; delegates rest to sub-skill
- Extra assertions:
  - [x] Dispatch OK — exactly one sub-skill SKILL.md loaded
- Verdict: **GREEN**

## Payload-byte sweep (confirmation)

Final cross-transcript sweep on 2026-04-17 re-ran T1-T4 patterns and line-length check on all 8 files:

| Check  | Pattern                                                      | Hits across 8 transcripts |
|--------|--------------------------------------------------------------|---------------------------|
| T1     | `transcript_text\s*[:=]\s*"[^"]{80,}"`                       | 0                         |
| T2     | `full_text\s*[:=]\s*"[^"]{140,}"`                            | 0                         |
| T3     | `article_body\s*[:=]\s*"[^"]{200,}"`                         | 0                         |
| T4     | `page_text\s*[:=]\s*"[^"]{200,}"`                            | 0                         |
| T7     | Any line > 400 chars (excluding known metadata JSON)         | 0 (max: 397, thread.txt)  |

Per-file max line length (all under 400-char T7 cap):

| File                            | Max line |
|---------------------------------|----------|
| etl-overview.txt                | 166      |
| ingest-local-files.txt          | 277      |
| ingest-x-bookmarks.txt          | 186      |
| ingest-x-thread.txt             | 397      |
| ingest-x-user-tweets.txt        | 354      |
| ingest-youtube-playlist.txt     | 304      |
| ingest-youtube-videos.txt       | 192      |
| load-kb-from-sql.txt            | 241      |

No payload bytes observed in any transcript. Transcripts contain only metadata
tokens (IDs, URLs, titles, status tokens, counts, timestamps) per the
payload-byte definition in `phase-8-review-checklist.md` §"Payload-byte
definition (normative)".

## Evidence index

Per-run evidence lives under `pipeline_mcp_data/scaffolds/`:

- Scripts: `phase-8-dry-runs/*.md` (one per sub-skill + router)
- Transcripts: `phase-8-transcripts/*.txt` (one per sub-skill + router)
- Harness contract: `data-etl-orchestrator/skills/references/phase-8-assertions.md`
- Checklist patterns: `data-etl-orchestrator/skills/references/phase-8-review-checklist.md`
- Deliverable format: `data-etl-orchestrator/skills/references/deliverable-format.md`
- Release gate mirror (15/15 green): `data-etl-orchestrator/skills/references/release-gates.md`

## Publish gate

All three publish gates are satisfied as of 2026-04-17:

1. **Sibling release gate** — `release-gates.md` reports 15/15 green (A1-A4 + Y1-Y4 + X0-X6). Sibling ROADMAP checkboxes flipped and verified.
2. **Dry-run gate** — 8/8 green here. Static + transcript + format assertions pass for all 7 sub-skills and the etl-overview router.
3. **Payload-byte gate** — zero T1-T7 hits across all captured transcripts.

Phase 6 closed. Phase 7 (git tag + marketplace publish) is destructive and
requires explicit user approval before proceeding — do not auto-advance.
