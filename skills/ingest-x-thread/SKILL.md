---
name: ingest-x-thread
description: "Ingest a full X thread (replies + ancestors) into an agent-knowledgebase, with auto-crawled linked articles. Uses x_get_thread, then kb_ingest_batch. Trigger: 'ingest this X thread into my KB', '/ingest-x-thread'."
---

## When to use this skill

- "ingest this X thread into my KB"
- "save this tweet thread / conversation to my knowledgebase"
- "load thread starting from tweet <url/id>"
- `/ingest-x-thread`

Do not invoke if `etl-overview` Stage 0 is not yet complete.

---

## Stage-0 prerequisites

Before dispatch, run the Stage-0 questionnaire — see
[preflight-questionnaire.md](../references/preflight-questionnaire.md).

## Preconditions

- X account must be connected. If `x_get_thread` returns an auth error, call `x_authorize` (or `x_browser_login` as fallback).
- Stage 0 must be complete (see `skills/etl-overview/SKILL.md`). Required answers: target KB, root tweet ID or URL, `max_results`, dedup policy.
- **7-day limit:** the X API only surfaces thread history up to 7 days old. Warn the user if the thread root is older than 7 days — ingestion may be incomplete.

---

## Stage 1 — Fetch

Single consolidated call:

```
x_get_thread(tweet_id=<root_id>, max_results=<N>)
```

- This writes all thread tweets (ancestors + replies) plus auto-crawled article rows to the source DB in one operation.
- The response includes a `conversation_id` that groups all tweets in this thread.
- Each tweet may include `articles: [{status, url, article_id}, ...]`. Do NOT call `x_get_article` or `x_crawl_article` separately.

**What counts as a Stage 1 success:** the call returned a 2xx response and at least the root tweet was written to the DB.

---

## Stage 2 — Verify DB state

```
x_get_saved_tweets(query=<conversation_id>)
x_get_saved_articles()   # filter client-side by tweet_id IN <thread tweet set>
```

- Diff desired tweet IDs (from Stage 1 response) vs. saved tweet IDs.
- If any tweets are missing from the DB, re-call `x_get_thread` with the same parameters (the operation is idempotent).
- Log article coverage per tweet: `ok` / `failed` / `none`.

---

## Stage 3 — Load DB to KB

**KB resolution.**

1. Call `kb_list` and match against the Stage-0 KB name or memory pointer.
2. If the KB is new: `kb_create`, then create `memory/kb_<slug>.md` and update `MEMORY.md` index. Verify with `kb_info`.

**Dedup check.**

Call `kb_list_pages(kb_id)` and `kb_list_sources(kb_id)`. Filter out tweet IDs and article IDs already present per Stage-0 dedup policy.

**Batch ingestion.**

Split remaining IDs into chunks of at most 50. For each chunk:

```
kb_ingest_batch([
  {
    source_type: "sql_database",
    uri: "sqlite:///<db_path>",
    metadata: {
      table: "tweets",
      row_selector: "conversation_id = '<conversation_id>' AND id IN ('<id1>',...)",
      granularity: "<row|batch>",
      kb_source_label: "x_thread:<conversation_id>",
      thread_order: "chronological"
    }
  }
])
```

Follow with a separate batch for the `articles` table:

```
metadata: { table: "articles", row_selector: "tweet_id IN (...)", ... }
```

- **Ordering:** include `thread_order: "chronological"` in metadata so the KB preserves temporal sequence. This is important for retrieval quality in conversation threads.
- Calls are sequential, not parallel.
- Default DB path: `~/.x-api-mcp/x-data.db` (env `X_API_DB_PATH`). Use Stage-0 override if provided.

**Dedup keys:** `tweet_id` for tweets table; `article_id` for articles table.

---

## Partial success handling

- A thread with some missing replies (e.g., deleted tweets, API gaps) is not fatal. Log the gap and continue.
- A tweet with a failed article crawl — ingest the tweet row; log the article as `skipped (crawl_failed)`.
- If a `kb_ingest_batch` call fails, log the chunk and reason. Continue with the next chunk.

---

## Delegation

Delegate the Stage 3 batch loop to a Sonnet subagent. Provide it: KB id, DB path, conversation_id, list of tweet IDs and article IDs, batch size, dedup policy.

The subagent reports per-batch counts; the parent agent assembles the final deliverable. Neither agent echoes tweet or article text.

---

## Deliverable

This skill emits the standard ETL deliverable. See
[deliverable-format.md](../references/deliverable-format.md).

---

## Idempotency and envelopes

Dedup behaviour per source is documented in
[idempotency-and-dedup.md](../references/idempotency-and-dedup.md).
Sibling MCP response envelopes (including `articles: Article[]`) are
pinned in [mcp-tool-contracts.md](../references/mcp-tool-contracts.md).

## Do not do these things

- Do NOT call `x_get_article` or `x_crawl_article` during ingest. Articles are fetched server-side.
- Do NOT write tweet or article content to `.md` files.
- Do NOT use `source_type="file"` for tweets or articles.
- Do NOT start Stage 1 before Stage 0 confirmation.
- Do NOT run `kb_ingest_batch` calls in parallel.
- Do NOT assume a thread older than 7 days will be fully retrievable — warn the user.

---

## References

- `references/deliverable-format.md` — standard ETL deliverable format
- `references/idempotency-and-dedup.md` — dedup behaviour per source
- `references/mcp-tool-contracts.md` — tool signatures and response contracts
- `references/preflight-questionnaire.md` — Stage 0 canonical spec
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/subagent-dispatch-protocol.md` — subagent delegation spec
- `skills/load-kb-from-sql/SKILL.md` — reusable Stage 3 batch helper
