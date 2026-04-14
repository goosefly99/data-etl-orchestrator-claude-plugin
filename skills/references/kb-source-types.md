# KB Source Types

Decision table for which `source_type` to pass to `kb_ingest` or `kb_ingest_batch`. The orchestrator's canonical path is `sql_database` for all MCP-cached content.

---

## Decision table

| `source_type` | When to use | When NOT to use |
|---|---|---|
| `file` | User-supplied files on disk (Markdown, PDF, etc.). Pass absolute path as `uri`. | Never for data that came from an MCP cache — use `sql_database` instead. |
| `directory` | Bulk ingest of a local folder tree. | Same — only for literal user-supplied files, never MCP-cached data. |
| `codebase` | Ingesting a source-code repository. | Not for prose or metadata. |
| `website` | Live scrape via a URL at ingest time. | Not for content already cached in an MCP DB — use `sql_database`. |
| `sql_database` | **ANY data that originated from a source MCP's cache.** YouTube videos, transcripts, playlists; X tweets, articles, users. This is the canonical path for the data-etl-orchestrator. | Do not use for schema-only introspection of arbitrary DBs unrelated to KB ingest. |
| `git_history` | Extracting commit history from a repository. | — |
| `api_endpoint` | Live JSON/REST pull at ingest time. | Not for content already cached in a source MCP's DB. |

---

## Canonical `sql_database` URI format

```
sqlite:///W:\youtube_mcp_db\youtube-data.db
sqlite:///~/.x-api-mcp/x-data.db
```

The `metadata` object must include at minimum:
- `table` — name of the source table (e.g., `videos`, `transcripts`, `tweets`, `articles`)
- `row_selector` — a `WHERE` clause fragment scoping the rows to ingest (e.g., `video_id IN ('abc123', 'def456')`)

---

## Forbidden pattern

> Writing transcripts, tweet text, or article body to intermediate `.md` files and re-ingesting with `source_type="file"` is explicitly forbidden.

This pattern was the root cause of the failure mode documented in `db_operations_plugins_claude_errors.txt`. It bypasses the MCP layer, produces orphaned files, breaks dedup (no stable key), inflates KB sources with duplicated content, and means payload bytes pass through the agent context — which this plugin is specifically designed to prevent. If you find yourself writing MCP-fetched content to disk as a staging step, stop and use `source_type="sql_database"` instead.
