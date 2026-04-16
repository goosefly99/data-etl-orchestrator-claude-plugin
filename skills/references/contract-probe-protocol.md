# Contract Probe Protocol

## Purpose

Before dispatching Stage 1, the router runs lightweight probe calls against the 3 sibling MCPs (agent-knowledgebase, youtube-mcp, x-api-mcp). If any probe fails — wrong response shape, missing field, or outright error — refuse to proceed and emit a structured error telling the user which plugin to upgrade. This catches contract drift before it causes silent data loss mid-pipeline.

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

## Failure behavior

If any probe fails, the router MUST NOT dispatch to a sub-skill. Instead, emit a structured error message identifying the exact mismatch.

**Possible failure messages:**

1. `"Contract mismatch detected. agent-knowledgebase response is missing 'dominant_embedding_model'. Install/upgrade agent-knowledgebase to version >= 0.5.0 before using this plugin."`

2. `"Contract mismatch detected. youtube-mcp response is missing 'statuses' envelope. Install/upgrade youtube-mcp to version >= 0.4.0 before using this plugin."`

3. `"Contract mismatch detected. x-api-mcp response is missing 'articles' array. Install/upgrade x-api-mcp to version >= 0.3.0 before using this plugin."`

The router logs the failure in the deliverable and halts. No partial dispatch is attempted.

---

## When to skip

If the user explicitly states "skip contract probe" during Stage 0, the probe phase is bypassed. However:

- A warning line is appended to the deliverable: `"Contract probe skipped by user override. Response shape mismatches may cause silent failures during ingestion."`
- The warning is logged regardless of whether the pipeline ultimately succeeds.
- Skipping the probe does not suppress contract errors that arise later during Stage 1 — those are still fatal.
