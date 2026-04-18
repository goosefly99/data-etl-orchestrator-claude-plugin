# Deliverable Format — Canonical Reference

## Requirement

PLAN.md requirement #10 mandates a **fixed deliverable format** per run:
> Fixed deliverable format per run: Stage-0 answers echoed; per-stage counts; dedup hits; per-field statuses (transcript/article coverage); failures with reason; updated memory pointers.

Every sub-skill's final report must conform to this format without omission or reordering.

---

## The 6 Required Sections

Final report must include all six sections, in this order:

1. **Stage-0 echo** — source, target KB, DB path, granularity, dedup policy.
2. **Stage-1 counts** — items fetched, transcript/article coverage (ok / missing / failed per item).
3. **Stage-2 diff** — desired vs. saved row counts; delta re-fetched.
4. **Stage-3 counts** — KB sources created, dedup hits skipped/updated, batch call count.
5. **Partial failures** — list each failed item with reason (e.g., `video_id=abc123: transcript missing, metadata-only ingested`).
6. **Memory pointers updated** — confirm `memory/kb_<slug>.md` and `MEMORY.md` index line reflect the KB state.

These sections are extracted verbatim from `etl-overview/SKILL.md` (lines 70–79) and reproduced here as the canonical source of truth. Do not reorder or omit sections.

---

## Partial-Success Report Shape (NEW)

Stage 1 and Stage 3 per-item coverage rows must conform to this shape:

```
Per-item row: { item_id: string, status: "ok"|"missing"|"failed",
                error: string|null, dedup_result: "new"|"duplicate" }
```

Field semantics:

- `"missing"` — upstream MCP could not fetch the item (e.g., transcript unavailable, article URL unreachable). The parent row (video, tweet) still lands in the DB; log as metadata-only.
- `"failed"` — downstream processing error after a successful fetch (e.g., KB ingest call rejected, DB write failed). This indicates a pipeline fault requiring investigation.
- `"ok"` — fetch and ingest completed without error.
- `error` — `null` when `status` is `"ok"`; a short human-readable reason string when `status` is `"missing"` or `"failed"`.
- `dedup_result` — `"new"` if the item was inserted; `"duplicate"` if it was skipped or updated per the dedup policy set in Stage 0.

Parent insert still succeeds when sub-items are marked `"missing"` or `"failed"`. Do not fail the batch for partial coverage.

> Cross-link: the `dedup_result` field and idempotency contract are specified in full in [`idempotency-and-dedup.md`](./idempotency-and-dedup.md), which also references the partial-success shape.

---

## How to Reference This Document

Skill authors: do not duplicate the 6-section list or the per-item row shape in individual SKILL.md files. Instead add a single pointer:

> See [deliverable-format.md](../references/deliverable-format.md).

This keeps the format as a single source of truth and ensures any future changes propagate automatically to all sub-skills.
