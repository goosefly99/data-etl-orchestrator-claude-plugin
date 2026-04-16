---
name: ingest-youtube-playlist
description: "Ingest a full YouTube playlist (metadata + transcripts) into an agent-knowledgebase. Uses get_playlist_items(hydrate=true) for the consolidated fetch, then kb_ingest_batch with source_type=sql_database. Trigger: 'ingest the <name> playlist into my <kb> KB', '/ingest-youtube-playlist'."
---

## Preconditions

- `etl-overview` Stage 0 must have run and received explicit go-ahead before this skill executes any data operation.
- If the user bypasses the router with a direct playlist request, still run Stage 0 questions (see `etl-overview`) before proceeding.
- Confirm the YouTube MCP DB path (default: `W:\youtube_mcp_db\youtube-data.db`; env: `YOUTUBE_MCP_DB_PATH`).

---

## Stage 1 — Fetch

**One consolidated call:**

```
get_playlist_items(playlistId=<id>, hydrate=true)
```

- The server writes every item's `videos` row and `transcripts` row atomically.
- The response includes a per-item status array: `{video_id, title, transcript: ok|missing|failed, ...}`.
- Do NOT follow up with a `get_transcript` loop. If `hydrate=true` is set, the single call is authoritative.
- Partial success is expected: `transcript: missing` means the video was inserted without a transcript row; treat as info, not error.

---

## Stage 2 — Verify DB state

1. Call `get_saved_videos(source="playlist_items")` filtered to the playlist ID.
2. Call `get_saved_transcripts` scoped to the playlist's video ID list.
3. Diff the returned row counts against the Stage 1 per-item status array.
4. For any video in the Stage 1 response whose `videos` row is absent from `get_saved_videos`, re-fetch via:

   ```
   get_video_details(videoId=<id>, includeTranscript=true)
   ```

   This is the only case where a per-item call is appropriate.

---

## Stage 3 — Load DB to KB

1. **Resolve target KB** — call `kb_list`; match against Stage 0 answer.
   - If new: call `kb_create`, then immediately create/update `memory/kb_<slug>.md` (frontmatter: `type: reference`) and add/update the index line in `MEMORY.md`. Verify with `kb_info`.
   - See `references/kb-memory-pointer-protocol.md` for the full update spec.

2. **Check dedup** — for each `video_id` in the work list, call `kb_list_pages` with `metadata.video_id` filter. Apply Stage 0 dedup policy (skip / re-ingest / force-add).

3. **Ingest** — call `kb_ingest_batch` sequentially, batches of ≤50 rows:

   ```json
   {
     "source_type": "sql_database",
     "uri": "sqlite:///<youtube-data.db>",
     "metadata": {
       "table": "videos",
       "row_selector": "video_id IN (...)",
       "playlist_id": "<id>",
       "playlist_position_range": [1, 50]
     }
   }
   ```

   Run a second pass for the `transcripts` table using the same `video_id IN (...)` filter.

4. **Delegate bulk ingestion** to a Sonnet subagent. Pass: video ID list, target KB id, DB path, dedup policy. The sub-agent must not echo transcript text in its report.

---

## Dedup

- Dedup key: `video_id`.
- Check `kb_list_pages` and `kb_list_sources` for existing entries before each batch.
- Honor the Stage 0 dedup policy; log every skip or re-ingest in the deliverable.

---

## Partial success

- A video where `transcript: missing` still has a `videos` row and is ingested as a metadata-only KB source.
- Log each partial entry in the deliverable under "Partial failures" with the reason.
- Do not treat missing transcripts as a blocking error.

---

## Deliverable

Follow the `etl-overview` deliverable format:
- Stage 0 echo (playlist ID, target KB, DB path, dedup policy).
- Stage 1: item count, transcript coverage (ok / missing / failed).
- Stage 2: `get_saved_videos` count vs. expected; delta re-fetched.
- Stage 3: KB sources created, dedup hits, batch calls made.
- Partial failures list.
- Memory pointer update confirmation.

---

## References

- `references/mcp-tool-contracts.md` — tool signatures and response shapes
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/subagent-dispatch-protocol.md` — subagent delegation spec
