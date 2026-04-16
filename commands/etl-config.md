---
name: etl-config
description: "Run the Stage-0 ETL questionnaire to configure a KB ingest run."
---

# /etl-config

Run the full 7-question Stage-0 questionnaire for configuring an ETL ingest into the agent-knowledgebase.

## Questions

Ask the following via `AskUserQuestion`, grouping related sub-questions to minimize round-trips:

1. **Target KB** — existing or new?
2. **Source selection** — YouTube playlist/videos, X bookmarks/user-tweets/thread, local files, crawled pages. Collect per-source params.
3. **DB path override** — confirm or override defaults (YouTube: `W:\youtube_mcp_db\youtube-data.db`, X: `~/.x-api-mcp/x-data.db`).
4. **KB ingest granularity** — per item or per batch?
5. **Dedup policy** — skip / re-ingest / force-add?
6. **Embeddings model** — which embeddings model endpoint, if the default ollama model is unavailable?
7. **Confirmation** — echo the resolved plan and require explicit go-ahead.

See `skills/references/preflight-questionnaire.md` for the canonical question spec with full sub-question details.

## After questionnaire

Once the user confirms, invoke `/etl-overview` to dispatch to the appropriate ingest sub-skill with the resolved answers. If the user only wanted to configure without executing, store the resolved plan for later use.
