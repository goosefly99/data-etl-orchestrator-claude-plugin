---
name: ingest-x-user-tweets
description: "Ingest tweets from an X user into an agent-knowledgebase, with auto-crawled articles. Uses x_get_user + x_get_user_tweets, then kb_ingest_batch. Trigger: 'ingest tweets from @handle into KB', '/ingest-x-user-tweets'."
---

## When to use this skill

- "ingest tweets from @handle into my KB"
- "fetch user tweets and load into [KB name]"
- "save all tweets from @user to my knowledgebase"
- `/ingest-x-user-tweets`

Do not invoke if `etl-overview` Stage 0 is not yet complete.

---

## Preconditions

- X account must be connected. If `x_get_user` returns an auth error, call `x_authorize` (or `x_browser_login` as fallback) before proceeding.
- Stage 0 must be complete (see `skills/etl-overview/SKILL.md`). Required answers: target KB, X handle or user_id, `max_results` per page, pagination intent, dedup policy.

---

## Stage 1 — Fetch

**Step 1a — Resolve user identity.**

Call `x_get_user(username=<handle>)` to get the canonical `user_id`. Store both `user_id` and `username`.

- Do NOT skip this step even if the caller provides a numeric ID — confirm the account is reachable.

**Step 1b — Fetch tweets.**

```
x_get_user_tweets(user_id=<id>, max_results=<N>, next_token=<token|null>)
```

- One call per page. Paginate using `next_token` from the response until the desired count is reached or the feed is exhausted.
- The server auto-crawls any linked X Articles per tweet. Each tweet in the response may include `articles: [{status, url, article_id}, ...]`.
- Do NOT call `x_get_article` or `x_crawl_article` in the ingest path. Article rows are written server-side.

**What counts as a Stage 1 success:** the API call returned a 2xx response and rows were written to the source DB. Partial pages are acceptable.

---

## Stage 2 — Verify DB state

After all fetch pages complete:

```
x_get_saved_tweets(author=<username>, source="user_tweets")
x_get_saved_articles()   # filter client-side by tweet_id IN <fetched set>
```

- Diff desired tweet IDs vs. saved tweet IDs. Re-fetch any delta with a targeted `x_get_user_tweets` call (narrow date range or explicit IDs if the API supports it).
- Log article coverage: for each tweet with articles entries with `status == "ok"`, confirm a matching row in saved articles.

---

## Stage 3 — Load DB to KB

**KB resolution.**

1. Call `kb_list` and match against the Stage-0 KB name or memory pointer.
2. If the KB is new: `kb_create`, then create `memory/kb_<slug>.md` and update `MEMORY.md` index. Verify with `kb_info`.

**Dedup check.**

Call `kb_list_pages(kb_id)` and `kb_list_sources(kb_id)`. Filter out tweet IDs and article IDs already present according to the Stage-0 dedup policy (skip / re-ingest / force-add).

**Batch ingestion.**

Split remaining IDs into chunks of at most 50. For each chunk:

```
kb_ingest_batch([
  {
    source_type: "sql_database",
    uri: "sqlite:///<db_path>",
    metadata: {
      table: "tweets",
      row_selector: "author_id = '<id>' AND id IN ('<id1>','<id2>',...)",
      granularity: "<row|batch>",
      kb_source_label: "x_user_tweets:<username>"
    }
  }
])
```

Follow with a separate batch for the `articles` table using the same ID chunks:

```
metadata: { table: "articles", row_selector: "tweet_id IN (...)", ... }
```

- Calls are sequential, not parallel.
- Default DB path: `~/.x-api-mcp/x-data.db` (env `X_API_DB_PATH`). Use Stage-0 override if provided.

**Dedup keys:** `tweet_id` for tweets table; `article_id` for articles table.

---

## Partial success handling

- A tweet with no linked article is not a failure. Log it as `articles: []`.
- A tweet whose article crawl failed (no `articles` entries with `status == "ok"`) — ingest the tweet row; log the article as `skipped (crawl_failed)`.
- If a `kb_ingest_batch` call fails, log the chunk IDs and reason. Continue with the next chunk. Do not abort the run.

---

## Delegation

Delegate the Stage 3 batch loop to a Sonnet subagent. Provide it: KB id, DB path, user_id/username, list of tweet IDs to ingest, article IDs to ingest, batch size, dedup policy.

The subagent reports per-batch counts; the parent agent assembles the final deliverable. Neither agent echoes tweet or article text in any report.

---

## Deliverable format

Final report must include:

- **Stage 0 echo** — handle, user_id, max_results, target KB, DB path, dedup policy.
- **Stage 1 counts** — pages fetched, tweets returned, articles auto-crawled (ok / failed / none per tweet).
- **Stage 2 diff** — desired vs. saved counts; delta re-fetched.
- **Stage 3 counts** — KB sources created, dedup hits (skipped/updated), batch call count, failures with reason.
- **Memory pointer** — confirm `memory/kb_<slug>.md` and `MEMORY.md` reflect current KB state.

---

## Do not do these things

- Do NOT call `x_get_article` or `x_crawl_article` during ingest. Articles are fetched server-side.
- Do NOT write tweet or article content to `.md` files.
- Do NOT use `source_type="file"` for tweets or articles.
- Do NOT start Stage 1 before Stage 0 confirmation.
- Do NOT run `kb_ingest_batch` calls in parallel.

---

## References

- `references/mcp-tool-contracts.md` — tool signatures and response contracts
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/preflight-questionnaire.md` — Stage 0 canonical spec
- `references/subagent-dispatch-protocol.md` — subagent delegation spec
- `skills/load-kb-from-sql/SKILL.md` — reusable Stage 3 batch helper
