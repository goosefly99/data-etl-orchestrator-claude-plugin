# Phase 6 — Week-One Monitoring Log (orchestrator v1.0.0)

**Spec lineage:** spec-4a2c91e7 | Phase 6 | Risk mitigation: R1 (consumer-side stderr capture), R5 (week-one observation)

This is the **single source of truth** for the week-one post-cutover
monitoring window. Fill in every row between window start (tag push of
orchestrator v1.0.0) and window close (start + 7 days). Aggregate the
Day-7 verdict in the block at the bottom.

Do NOT scatter observations across `cron-log.md` or individual bug-ticket
threads. All observations land here.

---

## 1. Release metadata

| Field | Value |
|---|---|
| Ecosystem release date | 2026-04-20 |
| Orchestrator v1.0.0 tag SHA | TBD (fill in after `git push <origin> v1.0.0`) |
| Rollback floor (v0.3.0-rc.1) SHA | d2197e8 (Phase 5 head, pre-Phase-6 bump) |
| Window start (tag-push timestamp, UTC) | TBD |
| Window end (window start + 7 days, UTC) | TBD |
| Operator rotation | TBD (list names/handles per day) |

---

## 2. Probe-4 assertion watchlist

Source of truth: `skills/references/contract-probe-protocol.md` § "Probe 4:
ensemble-contract" assertions (a) through (e). These are the five
invariants the week-one stderr sweep monitors. Any surfaced failure on
live user runs triggers the rollback clause in
`docs/phase-6-cutover-runbook.md` § 5.

Check the box when the assertion is verified clean across all 7 days. An
unchecked box at window close blocks the CLEAN verdict.

- [ ] **(a) zod envelope parse OK (articleIngestService).** The
  `tweetArticlesEnvelopeSchema` zod parse on every
  `articleIngestService` response succeeds. Zero parse errors observed
  on live user runs. Failure signal: stderr lines containing zod parse
  error messages against the envelope schema. Version floor on failure:
  `x-api >= 0.4.0`.

- [ ] **(b) yt status Literal OK (`ok|missing|failed|unavailable|skipped`).**
  Every youtube transcript status string in live responses is a member
  of the unified set. Zero legacy tokens (`crawled`, `scraped`,
  `queued`, `in_progress`) observed. Failure signal: grep on captured
  stderr or response bodies for any of the four legacy tokens. Version
  floor on failure: `yt >= 0.5.0`.

- [ ] **(c) kb stderr JSON shape OK (`knowledgebase_stderr_log`).** Every
  `knowledgebase_stderr_log` emission is valid JSON and conforms to
  `kbPipelineStatusSchema`. Zero free-text log lines, zero missing
  required fields. Failure signal: lines on stderr starting with
  `[knowledgebase_stderr_log]` that are not parseable as JSON, or JSON
  that fails the pydantic v2 schema. Version floor on failure:
  `kb >= 0.6.0`.

- [ ] **(d) silent-DB-failure canary: `TWEET_UPSERT_CONFLICT` within 100ms.**
  Every duplicate-key upsert on the x-api-mcp `tweets` table emits a
  SCREAMING_SNAKE_CASE `error_code` on stderr within 100 ms. Zero
  deadline-miss events, zero empty-stderr events. Failure signal: a
  duplicate-key upsert that produces empty stderr or an emission
  delayed beyond 100 ms (BUG-6 regression). Version floor on failure:
  `x-api >= 0.4.0`.

- [ ] **(e) `dedup_key` polymorphism: note-tweet `id == tweet_id` / crawler UUID v4.**
  Every article entry in the envelope carries a `dedup_key` (aka
  `article_id`) that either (a) equals the parent tweet id (for
  note-tweet-resolved articles) OR (b) matches the RFC 4122 v4 UUID
  regex (for crawler-resolved articles). Zero article entries match
  neither rule. Failure signal: an `article_id` that is neither a
  string-equal to `tweet_id` nor a valid UUID v4. Version floor on
  failure: depends on which branch fails — `x-api >= 0.4.0` for the
  note-tweet branch, `x-api >= 0.4.0` + crawler integration for the
  UUID branch.

All five assertions draw from
`skills/references/contract-probe-protocol.md` L92-99 and the failure
template at L107-116 of the same file.

---

## 3. Daily log rows

One row per calendar day during the window. Stderr-sweep result values:
`PASS` (no matches on the watchlist patterns), `FAIL` (one or more
matches — detail in notes), `N/A` (sweep intentionally deferred —
justify in notes; acceptable for weekends only if operator is
explicitly off-rotation).

| Day | Timestamp (UTC) | Observer | Stderr sweep | User reports | Notes |
|-----|-----------------|----------|--------------|--------------|-------|
| Day 1 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | Initial post-push sweep. Record marketplace-indexing observed times from step 3.4 here for future calibration. |
| Day 2 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | |
| Day 3 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | |
| Day 4 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | |
| Day 5 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | |
| Day 6 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | |
| Day 7 | TBD | TBD | TBD (PASS/FAIL/N/A) | TBD (count) | Final sweep before Day-7 verdict aggregation. |

### Row-fill notes

- **Timestamp.** Use ISO 8601 UTC (e.g. `2026-04-21T14:30:00Z`).
- **Observer.** Human name or handle of the operator who ran the sweep.
  Not "AI" or "agent" — the AI does not run live sweeps.
- **Stderr sweep.** Result of grepping captured consumer-side stderr
  logs for the 5 watchlist patterns from section 2. Every FAIL must be
  matched to a watchlist assertion letter in the notes column.
- **User reports.** Integer count of new orchestrator-repo bug reports
  filed within the last 24 hours. Zero counts acceptable; link to any
  non-zero ticket in the notes column.
- **Notes.** Free text. On FAIL rows, quote the offending stderr line
  (redact payload bytes) and the watchlist assertion letter.

---

## 4. Day-7 aggregate verdict

Fill in this block once, at window close (Day 7 sweep completed).

**Verdict:** TBD (CLEAN or REGRESSION)

**If CLEAN:**
- Declare orchestrator v1.0.0 the stable ecosystem tag.
- Preserve `v0.3.0-rc.1` as an archival rollback anchor (do NOT delete
  the tag; it stands as the pre-cutover release candidate).
- Append a one-line note to `cron-log.md`:
  `Phase 6 week-one monitoring CLEAN — v1.0.0 stable as of <window end timestamp>.`
- No further action required.

**If REGRESSION:**
- Cite the offending assertion letter(s) from section 2 (a/b/c/d/e).
- Quote the exact probe-4 failure message text (from
  `skills/references/contract-probe-protocol.md` § "Failure message
  template") observed on live user runs. Redact payload bytes.
- Identify the affected sibling (kb/yt/x-api) if the root cause
  isolates to one; otherwise mark `multi-sibling`.
- Activate the rollback clause per
  `docs/phase-6-cutover-runbook.md` § 5. Record the rollback commands
  executed and their timestamps.
- Append a multi-line block to `cron-log.md` per the release-gates.md
  rollback-record format:
  - Date of decision + monitoring window.
  - Failing assertion and observed value.
  - Affected sibling.
  - Patch target (v1.0.1, v1.1.0, or v0.3.0-rc.2) and ETA.
  - Link to the bug ticket.

---

## 5. Forward pointers

- **Runbook.** `docs/phase-6-cutover-runbook.md` — the step-by-step
  cutover sequence; this monitoring log is consumed by section 4 of the
  runbook.
- **Release-gate grid.** `skills/references/release-gates.md` — the
  rollback clause subsection is the canonical wording; all deviations
  in this log defer to that wording.
- **Probe protocol.** `skills/references/contract-probe-protocol.md` —
  source of truth for assertion definitions, failure message template,
  and version-floor strings.
