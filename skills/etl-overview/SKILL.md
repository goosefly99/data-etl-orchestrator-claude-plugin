---
name: etl-overview
description: "Router + Stage-0 questionnaire for ETL into the agent-knowledgebase. Use when the user asks to ingest YouTube videos/playlists, X bookmarks/threads/user tweets, local files, or crawled pages into a KB. Asks full config up front via AskUserQuestion, then dispatches to the right sub-skill."
---

## When to use this skill

Invoke when the user says any of:
- "ingest [source] into my KB / knowledgebase"
- "load [playlist / videos / bookmarks / tweets] into [KB name]"
- "add these YouTube videos / X bookmarks to my knowledge base"
- `/etl-overview`

Do not invoke if a more specific sub-skill is already running and Stage 0 is complete.

---

## Stage 0 — Preflight questionnaire (mandatory)

Issue ALL questions via `AskUserQuestion` before touching any data tool. Do not proceed to Stage 1 until explicit confirmation is received.

**Question groups** (ask as a single multi-part prompt or sequentially as needed):

1. **Target KB** — Which KB should this go into? List existing KBs from `kb_list`. If new, what name/slug?
2. **Source selection** — What are you ingesting? (YouTube playlist URL/ID, list of video IDs/URLs, X bookmarks, X user tweets, local files, crawled pages.) Collect all per-source params (playlist ID, video IDs, X handle, page count, date range, etc.).
3. **DB path override** — Confirm or override the source DB path:
   - YouTube MCP default: `W:\youtube_mcp_db\youtube-data.db` (env: `YOUTUBE_MCP_DB_PATH`)
   - X API MCP default: `~/.x-api-mcp/x-data.db` (env: `X_API_DB_PATH`)
4. **KB ingest granularity** — One KB source per item (video/tweet) or one per batch?
5. **Dedup policy** — If an item already exists in the KB: skip / re-ingest / force-add?
6. **Confirmation** — Echo the resolved plan (source, item count estimate, target KB, DB path, granularity, dedup policy). Ask for explicit go-ahead.

Block all Stage 1+ operations until the go-ahead is received.

See `references/preflight-questionnaire.md` for the canonical question spec.

---

## Routing table

After Stage 0 confirms the source type, dispatch to:

| Source | Sub-skill |
|---|---|
| YouTube playlist (ID or URL) | `ingest-youtube-playlist` |
| YouTube video list (IDs / URLs / channel) | `ingest-youtube-videos` |
| X bookmarks | `ingest-x-bookmarks` |
| X user tweets | `ingest-x-bookmarks` (with `source=user_tweets` param) |
| Local files | _(not yet implemented — inform user)_ |
| Crawled pages | _(not yet implemented — inform user)_ |

---

## Deliverable format

Final report must include:

- **Stage 0 echo** — source, target KB, DB path, granularity, dedup policy.
- **Stage 1 counts** — items fetched, transcript/article coverage (ok / missing / failed per item).
- **Stage 2 diff** — desired vs. saved row counts; delta re-fetched.
- **Stage 3 counts** — KB sources created, dedup hits skipped/updated, batch call count.
- **Partial failures** — list each failed item with reason (e.g., `video_id=abc123: transcript missing, metadata-only ingested`).
- **Memory pointers updated** — confirm `memory/kb_<slug>.md` and `MEMORY.md` index line reflect the KB state.

---

## Critical — do not do these things

- Do NOT read or write payload bytes (transcripts, tweet text, article body) to `.md` files as an intermediate step.
- Do NOT use `source_type="file"` for transcripts, tweets, or articles fetched from the MCP servers.
- Do NOT call `get_transcript` or `x_get_article` / `x_crawl_article` in the main ingest path; those are standalone accessors.
- Do NOT interleave Stage 1 fetch and Stage 3 ingest; collect the full work list first.
- Do NOT invoke Stage 1+ before Stage 0 confirmation is received.

---

## References

- `references/preflight-questionnaire.md` — canonical Stage 0 question spec
- `references/mcp-tool-contracts.md` — authoritative tool signatures and response contracts
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
