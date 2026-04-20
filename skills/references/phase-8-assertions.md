# Phase 8 assertions — harness contract

**Harness:** checklist (Option B)
**Reviewer checklist path:** `skills/references/phase-8-review-checklist.md`

## Rationale

Option B (markdown reviewer checklist) is chosen to preserve the skills-only / markdown-only invariant. Option A (Python script at `skills/references/verify/payload-byte-check.py`) is permitted by the spec but not elected; the only non-markdown file in the plugin remains zero.

## Forbidden-pattern regex set (normative)

Reference: `pipeline_mcp_data/scaffolds/verification-checklist.md` sections 2 and 3.

Static skill-text checks (S1-S13): see `phase-8-review-checklist.md` section "Static skill-text checks".
Transcript payload-byte checks (T1-T7): see `phase-8-review-checklist.md` section "Transcript payload-byte checks".

### S13 — Unified status vocabulary (Phase 4 addition)

```
S13 — Unified status vocabulary:
  Pattern: rg -n '\b(crawled|scraped|queued|in_progress)\b' skills/
  Expected: zero hits.
  Exclusions: skills/references/source-db-schemas.md (legitimate source='crawl' column value).
  Rationale: ensemble status vocabulary is ok|missing|failed; youtube adds unavailable|skipped at tool boundary only.
```

S13 is broader than S9: S9 targets status-comparison uses of `crawled`/`scraped` only; S13 additionally forbids `queued` and `in_progress` (pre-unification legacy tokens from sibling pipelines) anywhere in skill text. Prose adjective carve-outs inherited from S9 apply to S13 for `crawled`/`scraped` (e.g., "auto-crawled articles") — see `phase-8-review-checklist.md` for the exact exclusion set.

## Machine-verifiable assertion shape

Minimum 3 assertions per sub-skill dry-run, logged in `phase-8-dry-run-report.md`:

1. **Static OK:** S1-S13 patterns all zero hits against `data-etl-orchestrator/skills/` (S13 adds the unified status-vocabulary check).
2. **Transcript OK:** T1-T7 patterns all zero hits against the captured dry-run transcript.
3. **Format OK:** emitted deliverable contains all 6 sections from `deliverable-format.md`. Partial-success shape conforms if applicable.

Recommended extras (not required):
- Dispatch OK: exactly one sub-skill SKILL.md was loaded.
- Dedup OK: every item's `dedup_result` is one of `new` or `duplicate`.
- Envelope OK: for X sub-skills, every tweet has `articles: []` (possibly empty) with status `ok|missing|failed`.
- Probe OK: contract-probe-protocol returns 4/4 GREEN (probes 1-3 + probe-4 ensemble) per `references/contract-probe-protocol.md`.

## Harness choice contract

`harness: checklist`
`harness_path: skills/references/phase-8-review-checklist.md`

Both options encode the same S1-S13 and T1-T7 patterns. The script option may be added later without breaking the contract.
