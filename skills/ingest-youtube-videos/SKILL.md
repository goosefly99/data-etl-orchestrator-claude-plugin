---
name: ingest-youtube-videos
description: "Ingest a user-supplied list of YouTube video IDs (or URLs) into an agent-knowledgebase, with transcripts. Uses get_video_details(includeTranscript=true) per item, then kb_ingest_batch. Trigger: 'ingest these videos into my KB', '/ingest-youtube-videos'."
---

## Preconditions

- `etl-overview` Stage 0 must have run and received explicit go-ahead before any data operation.
- If the user bypasses the router, still run Stage 0 questions (see `etl-overview`) first.
- Confirm the YouTube MCP DB path (default: `W:\youtube_mcp_db\youtube-data.db`; env: `YOUTUBE_MCP_DB_PATH`).
- Input may be raw video IDs, full YouTube URLs, or a channel handle + limit. Resolve all inputs to a flat list of video IDs before Stage 1.
  - Channel-based input: call `search_videos` with `channelId` + `maxResults` to resolve to video IDs, then follow the same flow.

---

## Stage 1 — Fetch

One call per video ID, sequential:

```
get_video_details(videoId=<id>, includeTranscript=true)
```

- Each call writes a `videos` row and, if available, a `transcripts` row.
- The API response IS the DB insert. Do not follow up with manual writes.
- `transcript: missing` in the response means only the `videos` row was written; treat as info, not error.
- Process the full ID list before moving to Stage 2.

---

## Stage 2 — Verify DB state

1. For each video ID, call `get_saved_videos(query=<video_id>)` (or pass the full ID list if the tool supports batch lookup).
2. Call `get_saved_transcripts` scoped to the same video IDs.
3. Diff row counts against the Stage 1 response statuses.
4. For any `video_id` absent from `get_saved_videos`, re-call `get_video_details(videoId=<id>, includeTranscript=true)`.

---

## Stage 3 — Load DB to KB

1. **Resolve target KB** — call `kb_list`; match against Stage 0 answer.
   - If new: call `kb_create`, then immediately create/update `memory/kb_<slug>.md` (frontmatter: `type: reference`) and add/update the index line in `MEMORY.md`. Verify with `kb_info`.
   - See `references/kb-memory-pointer-protocol.md` for the full update spec.

2. **Check dedup** — call `kb_list_pages` with `metadata.video_id` filter for each ID. Apply Stage 0 dedup policy (skip / re-ingest / force-add).

3. **Ingest** — call `kb_ingest_batch` sequentially, batches of ≤50 rows:

   ```json
   {
     "source_type": "sql_database",
     "uri": "sqlite:///<youtube-data.db>",
     "metadata": {
       "table": "videos",
       "row_selector": "video_id IN (...)"
     }
   }
   ```

   Second pass for `transcripts` table with the same `video_id IN (...)` filter, skipping IDs with `transcript: missing`.

4. **Delegate bulk ingestion** to a Sonnet subagent. Pass: video ID list, target KB id, DB path, dedup policy. Sub-agent must not echo transcript text in its report.

---

## Dedup

- Dedup key: `video_id`.
- Check `kb_list_pages` and `kb_list_sources` before each batch.
- Honor Stage 0 dedup policy; log every skip or re-ingest in the deliverable.

---

## Partial success

- A video with `transcript: missing` is ingested as a metadata-only KB source from the `videos` table.
- Log each partial entry in the deliverable under "Partial failures" with the reason.
- Do not treat missing transcripts as a blocking error.

---

## Deliverable

Follow the `etl-overview` deliverable format:
- Stage 0 echo (input list summary, target KB, DB path, dedup policy).
- Stage 1: item count, transcript coverage (ok / missing / failed).
- Stage 2: `get_saved_videos` row count vs. expected; delta re-fetched.
- Stage 3: KB sources created, dedup hits, batch calls made.
- Partial failures list.
- Memory pointer update confirmation.

---

## References

- `references/mcp-tool-contracts.md` — tool signatures and response shapes
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
- `references/subagent-dispatch-protocol.md` — subagent delegation spec
