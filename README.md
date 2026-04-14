# data-etl-orchestrator

A **skills-only** Claude Code plugin that teaches agents a deterministic ETL flow across the existing data-source MCPs (`youtube-mcp`, `x-api-mcp`, `crawler-mcp`) and the `agent-knowledgebase` MCP.

## What this plugin enforces

1. **Agents never touch data.** No `Read` of transcripts, tweets, articles, or scraped pages. No `Write` of those payloads to disk. All movement is MCP-tool-to-MCP-tool.
2. **API call == DB insert.** A successful fetch response from a source MCP is itself the insert into that MCP's cache DB; no follow-up manual write by the agent.
3. **One consolidated fetch per logical item.** `get_video_details(videoId, includeTranscript=true)` returns metadata + transcript. `get_playlist_items(playlistId, hydrate=true)` hydrates every item. Tweet fetchers auto-crawl any linked article.
4. **KB ingestion is `source_type=sql_database`.** The only path from a source-MCP cache DB to the KB is a `kb_ingest(source_type="sql_database", uri=...)` call. Writing transcripts/tweets/articles to intermediate `.md` files and re-ingesting as `source_type=file` is **forbidden**.
5. **Stage-0 questionnaire is mandatory.** Every ETL run starts by collecting target KB, source, DB path, granularity, and dedup policy via `AskUserQuestion`.

## Skills

| Skill | Purpose |
|---|---|
| `etl-overview` | Router. Runs the Stage-0 questionnaire and dispatches to the right sub-skill. |
| `ingest-youtube-playlist` | Full-playlist fetch via `get_playlist_items(hydrate=true)` + KB load. |
| `ingest-youtube-videos` | Per-video fetch via `get_video_details(includeTranscript=true)` + KB load. |
| `ingest-x-bookmarks` | `x_get_bookmarks()` with server-side article auto-crawl + KB load. |
| `ingest-x-user-tweets` | `x_get_user_tweets(handle)` with server-side article auto-crawl + KB load. |
| `ingest-x-thread` | `x_get_thread(id)` with server-side article auto-crawl + KB load. |
| `ingest-local-files` | Reference local files by absolute path; KB ingests via `source_type=file`. |
| `load-kb-from-sql` | The batch DB -> KB step used by all ingest skills. |

Shared references live in `skills/references/`.

## Install

Install via the `goosefly99-plugins-auto-dev` marketplace. Requires these sibling plugins to be installed and loaded first:

- `agent-knowledgebase-auto-dev` (the ingest target)
- `youtube-mcp-auto-dev` (for YouTube sources)
- `x-api-mcp-auto-dev` (for X sources)
- `crawler-mcp-auto-dev` (for standalone web sources; optional if you never ingest web pages)

## When to invoke

Ask for `/etl-overview` any time you want to pull data from one of the supported sources into a knowledgebase. The router handles the rest.

## Design note

Pure skills, no MCP server of its own. That keeps the "agents never touch data" constraint honest — the plugin physically cannot expose a tool that would let an agent read or write payload bytes.
