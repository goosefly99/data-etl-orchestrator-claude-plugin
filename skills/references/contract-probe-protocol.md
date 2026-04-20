# Contract Probe Protocol

## Purpose

Before dispatching Stage 1, the router runs lightweight probe calls against the 3 sibling MCPs (agent-knowledgebase, youtube-mcp, x-api-mcp). If any probe fails — wrong response shape, missing field, or outright error — refuse to proceed and emit a structured error telling the user which plugin to upgrade. This catches contract drift before it causes silent data loss mid-pipeline.

The protocol runs 4 probes in sequence. Probes 1-3 exercise one sibling each (shape/field smoke tests). Probe 4 runs after 1-3 pass and exercises the full ensemble (envelope schema parse, unified status vocabulary, stderr log shape, silent-DB-failure canary, and dedup_key polymorphism) on a shared canary call. Any single probe failure halts dispatch.

---

## Probe 1: agent-knowledgebase

Call `kb_info` on any known KB (pick one from `kb_list` if available; skip this probe if no KBs exist yet).

Confirm the response includes the `dominant_embedding_model` field:

```json
{
  "id": "...",
  "name": "...",
  "description": "...",
  "dominant_embedding_model": "nomic-embed-text",
  "page_count": 42,
  "source_count": 12
}
```

**Pass condition:** `dominant_embedding_model` is present and is a non-empty string.

---

## Probe 2: youtube-mcp

Call `get_video_details(videoId='dQw4w9WgXcQ', includeTranscript=true)` (trivially public video; always available).

Confirm the response includes the `statuses` envelope with per-field status strings:

```json
{
  "metadata": { "video_id": "dQw4w9WgXcQ", "title": "...", "..." : "..." },
  "transcript": "...",
  "statuses": {
    "metadata": "ok",
    "transcript": "ok"
  }
}
```

**Pass condition:** `statuses` is present and contains both `metadata` and `transcript` keys with string values.

---

## Probe 3: x-api-mcp

Call `x_get_tweet(tweet_id='<known public tweet>')` on a trivially public tweet.

Confirm the response includes the `articles` field as an **array** (not a singular object):

```json
{
  "id": "...",
  "text": "...",
  "author_id": "...",
  "articles": []
}
```

**Pass condition:** `articles` is present and is an array (empty or populated). A response that omits `articles` entirely or returns it as a non-array indicates an outdated x-api-mcp version.

---

## Probe 4: ensemble-contract

### Purpose

After probes 1-3 pass in isolation, run the ensemble probe on a **shared canary call** to assert five invariants that cross sibling boundaries: envelope shape, unified status vocabulary, stderr log shape, silent-DB-failure detection, and `dedup_key` polymorphism. Probe 4 is the mitigation for BUG-5 (envelope-shape drift) and BUG-6 (silent-DB-failure blind spot); the 100 ms stderr deadline in assertion (d) is what turns a silent failure into a surfaced one.

### Canary call pattern

Reuse the resources from probes 1-3 so the call is idempotent:

- any known KB id from Probe 1 (for the `kb_pipeline_status` stderr emission path)
- `videoId='dQw4w9WgXcQ'` from Probe 2 (for the transcript status enum check)
- any trivially public tweet id from Probe 3 (for the articles envelope check)

Wire these into a single dispatch of the x-api-mcp auto-crawl path that triggers `articleIngestService` and in turn a kb write, then observe both the returned envelope and the captured stderr stream. Schemas referenced below are hosted in `references/mcp-tool-contracts.md` (landed in Phase 3).

### Assertions (a)-(e)

- **(a) Envelope shape (zod parse).** The `articleIngestService` envelope returned by the shared canary call MUST parse cleanly as the documented `tweetArticlesEnvelopeSchema` zod schema in `mcp-tool-contracts.md`. It MUST NOT be a Map-valued object. Any parse error — unknown keys, missing required fields, wrong value types — fails the probe.
- **(b) Transcript status vocabulary (unified set).** The youtube transcript status on the canary video MUST be a member of the unified set `ok | missing | failed | unavailable | skipped` (pydantic `Literal` enum in kb sibling; equivalent TypeScript union in TS siblings). Any string outside this set — including legacy tokens like `crawled`, `scraped`, `queued`, `in_progress` — fails the probe.
- **(c) kb stderr log shape.** The `knowledgebase_stderr_log` stderr emission from the canary kb write MUST be valid JSON and MUST conform to the documented `kbPipelineStatusSchema` (pydantic v2 in `mcp-tool-contracts.md`). Free-text log lines or missing required fields fail the probe.
- **(d) Silent-DB-failure canary.** Issue a known-bad idempotent write that violates the composite PRIMARY KEY on the x-api-mcp `tweets` table (e.g., duplicate `tweet_id` upsert). The probe MUST observe a SCREAMING_SNAKE_CASE `error_code` (e.g., `TWEET_UPSERT_CONFLICT`) on stderr **within 100 ms**. Empty stderr, free-text-only stderr, or an emission delayed beyond 100 ms fails the probe.
- **(e) `dedup_key` polymorphism.** Inspect the `articles[]` entries returned by the canary:
  - For a **note-tweet-resolved** article: assert `article_id === tweet_id` (string equality).
  - For a **crawler-resolved** article: assert `article_id` matches the RFC 4122 v4 UUID regex `/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i`.
  Any `article_id` that matches neither rule fails the probe. See `references/idempotency-and-dedup.md` for the polymorphism rationale.

All five assertions run against the same canary response so a single dispatch costs one round trip. Assertions (a)-(c) and (e) inspect the returned envelope; (d) is a separate deliberate-error call against x-api-mcp.

### Failure message template

On any assertion failure, emit a structured upgrade message that names the specific assertion, the offending value (redacted if it contains payload), and the exact sibling version floor to install:

```
Contract mismatch detected in probe 4 (ensemble).
Assertion: <a|b|c|d|e> — <one-line description>
Observed:  <redacted observed value or "no stderr within 100 ms">
Required sibling version floors:
  - agent-knowledgebase (kb)  >= 0.6.0
  - youtube-mcp (yt)          >= 0.5.0
  - x-api-mcp                 >= 0.4.0
Upgrade all three siblings to at least these versions before re-running.
```

### Version floor

Probe 4 requires `kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0` simultaneously. Any lower version on any sibling fails the probe with the message above.

---

## Failure behavior

If any probe fails, the router MUST NOT dispatch to a sub-skill. Instead, emit a structured error message identifying the exact mismatch.

**Possible failure messages:**

1. `"Contract mismatch detected. agent-knowledgebase response is missing 'dominant_embedding_model'. Install/upgrade agent-knowledgebase to version >= 0.6.0 before using this plugin."`

2. `"Contract mismatch detected. youtube-mcp response is missing 'statuses' envelope. Install/upgrade youtube-mcp to version >= 0.5.0 before using this plugin."`

3. `"Contract mismatch detected. x-api-mcp response is missing 'articles' array. Install/upgrade x-api-mcp to version >= 0.4.0 before using this plugin."`

4. Probe-4 (ensemble) failures use the structured template shown in that probe's "Failure message template" section; all four sibling version floors (`kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0`) are named together since a probe-4 failure usually indicates at least one sibling is below floor.

The router logs the failure in the deliverable and halts. No partial dispatch is attempted.

---

## When to skip

If the user explicitly states "skip contract probe" during Stage 0, the probe phase is bypassed. However:

- A warning line is appended to the deliverable: `"Contract probe skipped by user override. Response shape mismatches may cause silent failures during ingestion."`
- The warning is logged regardless of whether the pipeline ultimately succeeds.
- Skipping the probe does not suppress contract errors that arise later during Stage 1 — those are still fatal.
