# Idempotency and Dedup

## Purpose

Ensures repeat runs do not duplicate rows in source DBs or pages in the KB. Without strict dedup, retried Stage-3 batches inflate KB page counts and produce redundant vector index entries. Defines the dedup key per source type and the sequence for applying Stage-0 dedup policy.

---

## Dedup keys by source

| Source | Dedup key | Notes |
|---|---|---|
| YouTube videos | `video_id` | 11-char YouTube ID. One key per row in `videos`. |
| YouTube transcripts | `(video_id, language)` | Composite. Supports multi-language; each language is a separate KB source. |
| X tweets | `tweet_id` (`id` column) | Thread identity is `conversation_id`; individual tweet identity is `tweet_id`. |
| X articles | `article_id` (`id` column) | Polymorphic: `tweet_id` for API-sourced note-tweet articles; URL for crawler-sourced. Ref: `x-api-mcp-dev/db/repos/articles.ts` line 36. |
| Local files | `sha256` of file bytes | Computed via Bash (`certutil -hashfile <path> SHA256` on Windows). File bytes never enter the agent context. |
| Crawled pages | `canonical_url` | After redirect resolution. |

---

## Dedup check sequence (Stage 3)

1. Collect all dedup keys for the current work list.
2. Call `kb_list_pages(kb_id)` — returns existing pages with their metadata, including the dedup key field.
3. Apply the Stage-0 dedup policy:
   - **skip** — remove any work-list item whose dedup key already appears in `kb_list_pages`. Log the hit count.
   - **re-ingest** — pass all items to `kb_ingest_batch`; the server replaces or updates the existing source.
   - **force-add** — pass all items; accept duplicate pages in the KB.
4. Log total dedup hits and their disposition in the deliverable.

---

## Source-side dedup

Source MCPs upsert on primary key. Repeating a Stage-1 fetch for the same `video_id` or `tweet_id` is harmless to DB state — the existing row is overwritten with identical data.

Skipping Stage 1 when rows already exist is a secondary optimization, not a correctness requirement. Correctness (no missing rows) takes priority over cost savings.

---

## Idempotent Stage 0

The preflight questionnaire is itself idempotent. Re-running it with identical answers must produce the same resolved plan. If the user re-invokes the skill in the same or a new session, re-ask Stage 0 from scratch rather than reusing earlier answers from conversation memory. Conversation memory of prior Stage-0 answers is not reliable and must not substitute for a fresh questionnaire.

See also: [preflight-questionnaire.md#re-run-and-persistence-policy](preflight-questionnaire.md#re-run-and-persistence-policy)
for the same policy stated in the Stage-0 questionnaire's own reference doc.

---

## Why this matters for this plugin

Stage-3 batch failures are recoverable by retrying only the delta (items not yet successfully ingested). This only works if the dedup check reliably identifies already-ingested items. Without it, retries re-ingest the full set and balloon KB page counts. The dedup sequence above is the mechanism that makes partial retries safe.

---

## Partial-success report shape

When a sub-skill's ingest has mixed outcomes, each item's row conforms to:

    { item_id: string,
      status: "ok" | "missing" | "failed",
      error: string | null,
      dedup_result: "new" | "duplicate" }

"missing" indicates the upstream MCP could not fetch the item (e.g., an
X article that failed server-side auto-crawl). The parent insert still
succeeds; only the sub-item row is marked.

See also: `deliverable-format.md` for the surrounding 6-section deliverable format.
