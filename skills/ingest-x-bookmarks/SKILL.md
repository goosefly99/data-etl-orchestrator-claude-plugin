---
name: ingest-x-bookmarks
description: "Ingest the authenticated user's X bookmarks (tweets + auto-crawled articles) into an agent-knowledgebase. Uses x_get_bookmarks with server-side article auto-crawl, then kb_ingest_batch. Trigger: 'ingest my X bookmarks into my KB', '/ingest-x-bookmarks'."
---

## Preconditions

- `x_authorize` must have been called and the session is authenticated before any X data operation.
- `etl-overview` Stage 0 must have run and received explicit go-ahead.
- Confirm the X API MCP DB path (default: `~/.x-api-mcp/x-data.db`; env: `X_API_DB_PATH`).

---

## Stage 1 — Fetch

**One consolidated call:**

```
x_get_bookmarks(max_results=<n>)
```

- The server writes `tweets` rows for every bookmark.
- For every tweet that links one or more X Articles, the server **auto-crawls** and writes an `articles` row server-side per article. Each tweet in the response includes `articles: [{status: ok|missing|failed, url, article_id}, ...]`.
- Do NOT call `x_get_article` or `x_crawl_article` in the ingest path. Those are cache-read / manual-override accessors only.
- An empty `articles` array means the tweet has no linked article. Entries in `articles` with `status=failed` mean the crawl was attempted but failed; the `tweets` row is still written.
- Process the full bookmark window before moving to Stage 2.

---

## Stage 2 — Verify DB state

1. Call `x_get_saved_tweets(source="bookmarks")` scoped to the same bookmark window (date range or result count).
2. Call `x_get_saved_articles(source="crawl")` scoped to the article IDs from the Stage 1 response.
3. Diff row counts against Stage 1 per-tweet statuses.
4. Log entries in the `articles` array with `status=missing` or `status=failed` as info — do not treat as a blocking failure.
5. If a `tweet_id` is absent from `x_get_saved_tweets`, re-call `x_get_bookmarks` with a narrower window or call `x_get_tweet(id=<tweet_id>)` for the specific miss.

---

## Stage 3 — Load DB to KB

1. **Resolve target KB** — call `kb_list`; match against Stage 0 answer.
   - If new: call `kb_create`, then immediately create/update `memory/kb_<slug>.md` (frontmatter: `type: reference`) and add/update the index line in `MEMORY.md`. Verify with `kb_info`.
   - See `references/kb-memory-pointer-protocol.md` for the full update spec.

2. **Check dedup** — call `kb_list_pages` with `metadata.tweet_id` and `metadata.article_id` filters. Apply Stage 0 dedup policy (skip / re-ingest / force-add).

3. **Ingest** — two parallel batch tracks, each sequential with ≤50 rows per `kb_ingest_batch` call:

   **Track A — tweets:**
   ```json
   {
     "source_type": "sql_database",
     "uri": "sqlite:///~/.x-api-mcp/x-data.db",
     "metadata": {
       "table": "tweets",
       "row_selector": "tweet_id IN (...)"
     }
   }
   ```

   **Track B — articles** (skip IDs where the `articles` entry `status != ok`):
   ```json
   {
     "source_type": "sql_database",
     "uri": "sqlite:///~/.x-api-mcp/x-data.db",
     "metadata": {
       "table": "articles",
       "row_selector": "article_id IN (...)"
     }
   }
   ```

4. **Delegate bulk ingestion** to a Sonnet subagent. Pass: tweet ID list, article ID list, target KB id, DB path, dedup policy. Sub-agent must not echo raw tweet text or article body in its report.

---

## Dedup

- Dedup keys: `tweet_id` (tweets table), `article_id` (articles table).
- Check `kb_list_pages` and `kb_list_sources` before each batch track.
- Honor Stage 0 dedup policy; log every skip or re-ingest in the deliverable.

---

## Partial success

- A tweet whose linked article has `status=failed` still has a `tweets` row and is ingested as tweet-only; the `articles` row is skipped.
- An empty `articles` array (tweet has no article link) is not a failure at all.
- Log each skipped article in the deliverable under "Partial failures" with the `articles` entry `status=failed`.

---

## Deliverable

Follow the `etl-overview` deliverable format:
- Stage 0 echo (bookmark count, target KB, DB path, dedup policy).
- Stage 1: tweet count, article coverage breakdown (ok / missing / failed).
- Stage 2: `x_get_saved_tweets` and `x_get_saved_articles` counts vs. expected; delta re-fetched.
- Stage 3: KB sources created (tweets + articles separately), dedup hits, batch calls made.
- Partial failures list (failed article crawls with tweet ID and article URL).
- Memory pointer update confirmation.

---

## References

- `references/mcp-tool-contracts.md` — tool signatures and response shapes
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
