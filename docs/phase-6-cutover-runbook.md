# Phase 6 — Cutover Runbook (v1.0.0 ecosystem release)

**Spec lineage:** spec-4a2c91e7 | Phase 6 | Success Criteria: SC12, SC13, SC14 | Risk mitigation: R7, R12, R1, R5

This runbook is the **full manual sequence** the human operator follows to
cut over to the v1.0.0 orchestrator release alongside the sibling v0.3.0
drop (agent-knowledgebase v0.6.0, youtube-mcp v0.5.0, x-api-mcp v0.4.0).

AI execution stops at "local prep": the plugin.json bump, the CHANGELOG
date-stamp, this runbook, and the monitoring-log template are already in
the `v1.0.0/phase-6-cutover-prep` branch. The steps below — pushing
branches, tagging, running the marketplace-resolution script against a
live marketplace, and week-one monitoring — stay with the human operator.

---

## 1. Preconditions

Confirm **all** of the following before starting step 3.1:

- Phase 1 through Phase 5 merged on all 4 repos (orchestrator +
  3 siblings). No in-flight feature branches blocking main.
- All 4 sibling branches green locally on their project test runner
  (vitest for youtube-mcp and x-api-mcp; node:test also applies on the
  TS siblings; pytest for agent-knowledgebase). No skipped suites, no
  xfail leakage.
- `scripts/verify-marketplace-resolution.sh` is present in the
  orchestrator repo at its expected path and is executable (`test -x`).
- Reviewer approval recorded in session history. The approval anchor
  points at the Phase 5 commit SHAs across all four repos:
  - agent-knowledgebase: `8375c5c`
  - youtube-mcp:         `43f982a`
  - x-api-mcp:           `73aab79`
  - orchestrator:        `d2197e8` (Phase 5 head; `v1.0.0/phase-5-release-gate-rollup`)

---

## 2. Release-ordering gate (R7)

The ecosystem release sequence is enforced verbatim from
`skills/references/release-gates.md` § "Release order reminder":

**Stage 1 — Ships FIRST.** Only one tag in this stage; it gates everything else.

- `agent-knowledgebase` **v0.6.0**

**Stage 2 — In any order.** Both tags in this stage MUST land before Stage 3.

- `youtube-mcp` **v0.5.0**
- `x-api-mcp` **v0.4.0**

**Stage 3 — Ships LAST.** Requires all three Stage 1 + Stage 2 tags
resolvable from marketplace `goosefly99-plugins-auto-dev` (R12 gate).

- `data-etl-orchestrator` **v1.0.0**

**Stage 4 — Optional.** If the crawler-mcp plugin is part of this
ecosystem release, it tags AFTER the orchestrator v1.0.0 tag — never
before. No current blocker on v1.0.0 if crawler-mcp is deferred.

Violating this sequence risks shipping a contract probe that tells users
to install a sibling version the marketplace cannot yet serve. Do NOT
skip ahead.

---

## 3. Step-by-step cutover

Each step block: **Objective**, **Command**, **Expected result**,
**Rollback action**.

Substitute `<origin>` with the actual remote name (commonly `origin`).

### 3.1 Ship agent-knowledgebase v0.6.0 (Stage 1)

**Objective.** Push the kb Phase 2a head branch, merge to `main`, tag
v0.6.0, push the tag.

**Command.**
```bash
cd ../agent_knowledge_base_plugin_dev
git push <origin> v0.3.0/phase-1-kb-ensemble-fixes
git checkout main
git pull --ff-only <origin> main
git merge --no-ff v0.3.0/phase-1-kb-ensemble-fixes \
  -m "merge: kb v0.6.0 — ensemble-critical fixes (A5-A7)"
git tag -a v0.6.0 -m "agent-knowledgebase v0.6.0 — ensemble-critical fixes"
git push <origin> main
git push <origin> v0.6.0
```

**Expected result.** `main` has the merge commit; `v0.6.0` is pushed to
`<origin>`; marketplace entry for `agent-knowledgebase-auto-dev` updates
within the indexing window (see 3.4).

**Rollback action.** If the push fails mid-way: `git push <origin>
:refs/tags/v0.6.0` removes the remote tag. Leave the merge commit on
`main` — it carries no user-facing contract change until the tag is
advertised by marketplace.

### 3.2 Ship youtube-mcp v0.5.0 (Stage 2)

**Objective.** Push the yt Phase 2b head branch, merge to `main`, tag
v0.5.0, push the tag.

**Command.**
```bash
cd ../youtube-mcp-dev
git push <origin> v0.5.0/phase-2b-youtube-fixes
git checkout main
git pull --ff-only <origin> main
git merge --no-ff v0.5.0/phase-2b-youtube-fixes \
  -m "merge: yt v0.5.0 — classifier helper + hydrate reunify (Y5-Y7)"
git tag -a v0.5.0 -m "youtube-mcp v0.5.0 — classifier helper, hydrate-loop reunify, retry-semantics doc"
git push <origin> main
git push <origin> v0.5.0
```

**Expected result.** `main` has the merge commit; `v0.5.0` is pushed;
marketplace entry for `youtube-mcp-auto-dev` updates within the indexing
window.

**Rollback action.** Same pattern as 3.1: `git push <origin>
:refs/tags/v0.5.0` removes the remote tag.

### 3.3 Ship x-api-mcp v0.4.0 (Stage 2)

**Objective.** Push the x-api Phase 2a head branch, merge to `main`, tag
v0.4.0, push the tag.

**Command.**
```bash
cd ../x-api-mcp-dev
git push <origin> v0.4.0/phase-2a-xapi-handler-layer
git checkout main
git pull --ff-only <origin> main
git merge --no-ff v0.4.0/phase-2a-xapi-handler-layer \
  -m "merge: x-api v0.4.0 — handler-layer wrapper + envelope zod (X7-X9)"
git tag -a v0.4.0 -m "x-api-mcp v0.4.0 — withFailureIsolation, TweetArticlesEnvelope zod, Playwright canary"
git push <origin> main
git push <origin> v0.4.0
```

**Expected result.** `main` has the merge commit; `v0.4.0` is pushed;
marketplace entry for `x-api-mcp-auto-dev` updates within the indexing
window.

**Rollback action.** Same pattern: `git push <origin>
:refs/tags/v0.4.0` removes the remote tag.

### 3.4 Wait for marketplace indexing

**Objective.** Give `goosefly99-plugins-auto-dev` time to pick up the
three new sibling tags before the R12 gate runs.

**Command.** (No command — this is a wait step.)

**Expected result.** Per empirical observation, typical indexing window
is **5 to 15 minutes per sibling**. Three siblings in parallel: budget
**15 to 45 minutes** before step 3.5. Record the start-time of each push
and the observed resolution time in
`docs/phase-6-monitoring-log.md` (day-1 row) for future calibration.

**Rollback action.** N/A — indexing is async and idempotent; no
intervention possible from the operator side.

### 3.5 Run marketplace-resolution verification (R12 gate)

**Objective.** Confirm all three sibling tags resolve at their expected
floor from `goosefly99-plugins-auto-dev` BEFORE tagging the orchestrator.

**Command.**
```bash
cd ../data-etl-orchestrator
bash scripts/verify-marketplace-resolution.sh
```

**Expected result.** Exit code 0 with three lines of the form:
```
OK:   agent-knowledgebase resolved at 0.6.0
OK:   youtube-mcp resolved at 0.5.0
OK:   x-api-mcp resolved at 0.4.0
```

**Rollback action.** On any non-zero exit: **STOP**. Do NOT proceed to
3.6. Fall to the manual-checklist fallback in
`skills/references/release-gates.md` §
"Marketplace-resolution verification (Phase 6 sub-task, R12)" —
specifically the 5-item manual fallback sequence (open each marketplace
entry, confirm version floor, run probes 1-3 from a clean install, log
decision + timestamp + operator in `cron-log.md`). If the manual
fallback also fails, wait longer for indexing and re-run 3.5. If the
mismatch persists beyond 60 minutes past push, escalate to a sibling
re-tag — do NOT advance to orchestrator tagging while any sibling is
below floor.

*Note:* the script currently ships as a placeholder that fails closed
until the `claude plugin query` CLI lands. Operators will use the manual
fallback for this cutover unless the CLI is confirmed present before
step 3.5.

### 3.6 Tag v0.3.0-rc.1 rollback floor on orchestrator

**Objective.** Freeze a rollback anchor at the pre-Phase-6 Phase 5 head
(`v1.0.0/phase-5-release-gate-rollup`) BEFORE the Phase 6 plugin.json
bump. This is the public fallback point if week-one monitoring trips
the rollback clause.

**Command.**
```bash
cd ../data-etl-orchestrator
git tag -a v0.3.0-rc.1 d2197e8 \
  -m "Rollback floor for v1.0.0 ecosystem release (Phase 5 head, pre-Phase-6 bump)"
git push <origin> v0.3.0-rc.1
```

**Expected result.** Annotated tag `v0.3.0-rc.1` exists locally and on
`<origin>`, pointing at commit `d2197e8` — the Phase 5 rollup head,
before the Phase 6 plugin.json version bump.

**Rollback action.** Accidentally tagging the wrong commit:
`git tag -d v0.3.0-rc.1` locally, `git push <origin>
:refs/tags/v0.3.0-rc.1` remotely, then re-tag on the correct SHA.

### 3.7 Merge v1.0.0/phase-6-cutover-prep to main on orchestrator

**Objective.** Land the Phase 6 prep commits (plugin.json bump, CHANGELOG
date-stamp, this runbook, monitoring-log template) onto `main`.

**Command.**
```bash
cd ../data-etl-orchestrator
git checkout main
git pull --ff-only <origin> main
git merge --no-ff v1.0.0/phase-6-cutover-prep \
  -m "merge: orchestrator v1.0.0 — Phase 6 cutover prep"
git push <origin> main
```

**Expected result.** `main` now contains the plugin.json version bump
to 1.0.0, the date-stamped CHANGELOG entry, the runbook, and the
monitoring-log template — all on a single merge commit.

**Rollback action.** If the merge fails verification on main (CI,
branch protection): revert the merge commit (`git revert -m 1 <sha>`),
investigate, and re-merge. Do NOT tag v1.0.0 until this step is green.

### 3.8 Tag orchestrator v1.0.0 on the merge commit

**Objective.** Cut the public v1.0.0 tag on the merge commit from 3.7.

**Command.**
```bash
cd ../data-etl-orchestrator
# On main, with the Phase 6 merge commit as HEAD:
git tag -a v1.0.0 -m "data-etl-orchestrator v1.0.0 — ecosystem release (2026-04-20)"
git push <origin> v1.0.0
```

**Expected result.** Annotated tag `v1.0.0` pushed to `<origin>`. This
push is the **start of the week-one monitoring window** (see section 4).

**Rollback action.** Before week-one monitoring completes, the rollback
is `git tag -d v1.0.0` locally and `git push <origin>
:refs/tags/v1.0.0` remotely, leaving `v0.3.0-rc.1` as the advertised
floor. See section 5 for the full rollback procedure.

---

## 4. Week-one monitoring window

**Window start.** Timestamp of the `git push <origin> v1.0.0` in step
3.8. Record exactly in `docs/phase-6-monitoring-log.md` metadata table.

**Window end.** Window start + 7 days (calendar days, not business days).

**Record location.** All observations go in
`docs/phase-6-monitoring-log.md`. Do NOT scatter observations across
cron-log.md or individual bug-ticket threads — the monitoring log is
the single source of truth for the Day-7 verdict.

### Daily cadence

- **Day 1 (tag push + 24h).** Stderr sweep across consumer-side capture
  logs for the 5 probe-4 `error_code` patterns (see the watchlist in the
  monitoring-log template): zod envelope parse errors, legacy status
  vocabulary tokens (`crawled|scraped|queued|in_progress`), malformed
  `knowledgebase_stderr_log` entries, `TWEET_UPSERT_CONFLICT` beyond the
  100 ms deadline, and `dedup_key` polymorphism violations. Record in
  the Day-1 row of the monitoring log.
- **Days 2 through 6.** Check user bug reports on the orchestrator repo
  daily. Each day's row in the monitoring log captures: timestamp,
  observer (human name), stderr-sweep result (PASS/FAIL/N/A), count of
  new user reports, and free-text notes. N/A is acceptable on weekends
  only if the operator is explicitly off-rotation — document in notes.
- **Day 7 (window close).** Aggregate the week's rows into the Day-7
  verdict block at the bottom of the monitoring log.

### Day-7 verdict outcomes

- **CLEAN.** No probe-4 regression across the 7-day window. Announce
  the release stable — orchestrator v1.0.0 is the advertised floor; the
  v0.3.0-rc.1 rollback anchor can be preserved as an archival tag but
  is no longer the active rollback target.
- **REGRESSION.** Any probe-4 assertion (a/b/c/d/e) failing on live
  user runs. Activate the rollback clause per section 5; cite the
  offending assertion letter and the exact probe-4 failure message text
  in the monitoring log.

---

## 5. Rollback clause

The rollback clause is quoted verbatim from
`skills/references/release-gates.md` § "Rollback clause (Phase 6)":

> *"If week-one post-cutover monitoring surfaces any probe-4 regression,
> the orchestrator tag STAYS at v0.3.0-rc.1 until the regression is
> patched. Do not advance the public tag to v1.0.x without a clean
> re-run of probe-4 against the fixed sibling."*

### Rollback commands

If the Day-7 verdict is REGRESSION, or if a probe-4 regression surfaces
mid-week and the operator decides to pull the tag early:

```bash
# Remove the orchestrator v1.0.0 tag locally:
git tag -d v1.0.0

# Remove the orchestrator v1.0.0 tag from the remote:
git push <origin> :refs/tags/v1.0.0
```

After the tag removal, `v0.3.0-rc.1` (pushed in step 3.6) is the
advertised floor again. Marketplace should re-resolve within the same
5-15 minute indexing window per sibling.

### CHANGELOG disposition on rollback

The `CHANGELOG.md` v1.0.0 entry STAYS in the file. Append a "Recalled"
note at the top of the 1.0.0 entry with the rollback date and the
failing probe-4 assertion letter — do NOT delete the entry or rewrite
history. A patched v1.0.x release will carry its own CHANGELOG entry
below the recalled 1.0.0 block.

### Sibling tag disposition on rollback

The sibling tags `v0.6.0` (kb), `v0.5.0` (yt), and `v0.4.0` (x-api)
DO NOT get un-tagged. They are per-plugin releases that stand on their
own contract surfaces and are already live for other consumers. Only
the orchestrator v1.0.0 aggregate release is recalled. Rolling back a
sibling tag is a separate, per-plugin decision governed by that
plugin's own changelog and is out of scope for the orchestrator
rollback clause.

### Rollback record

Log the rollback decision in `cron-log.md` per
`skills/references/release-gates.md` § "Rollback clause (Phase 6)":

- Date of decision + monitoring window (e.g. `2026-04-20..2026-04-27`).
- Failing assertion (a/b/c/d/e) and observed value.
- Affected sibling (if the root cause isolates to one).
- Patch target (v1.0.1, v1.1.0, or v0.3.0-rc.2) and expected ETA.
- Link to the bug ticket or issue that tracks the fix.

---

## 6. Out-of-session actions (human operator)

Everything in this list is the operator's responsibility. The AI has
already completed the local prep (the 3 commits on
`v1.0.0/phase-6-cutover-prep` — see git log). The AI has NOT:

- Pushed any branch to any remote.
- Created or pushed any git tag (`v0.6.0`, `v0.5.0`, `v0.4.0`,
  `v0.3.0-rc.1`, `v1.0.0`).
- Run `scripts/verify-marketplace-resolution.sh` against a live
  marketplace (the script queries a live service and may cost real
  resolution attempts; this is operator-gated).
- Merged `v1.0.0/phase-6-cutover-prep` to orchestrator `main`.
- Run any part of the week-one monitoring window — stderr sweeps, bug
  report triage, Day-7 verdict aggregation are all human-driven.
- Activated the rollback clause.

The human operator performs every step in sections 3 (3.1 through 3.8),
4 (daily stderr sweeps + bug report checks), and 5 (if triggered).

---

## 7. Forward pointers

- **Release-gate grid.** `skills/references/release-gates.md` — specifically
  the "Pre-tag checklist (Phase 6)" and "Rollback clause (Phase 6)"
  subsections. The grid is the authoritative 16/16 status; this runbook
  only reflects it.
- **Marketplace query script.** `scripts/verify-marketplace-resolution.sh` —
  placeholder that fails closed until the `claude plugin query` CLI
  lands; operator-run only.
- **Monitoring log template.** `docs/phase-6-monitoring-log.md` — fill in
  every row during the week-one window; aggregate Day-7 verdict at
  window close.
- **Contract probe protocol.** `skills/references/contract-probe-protocol.md` —
  Probe 4 (assertions a-e) is the source of truth for the week-one
  stderr watchlist patterns.
- **Per-plugin CHANGELOGs.** Each sibling CHANGELOG documents its own
  v0.3.0-family release and does not depend on the orchestrator v1.0.0
  tag. Rolling back the orchestrator does NOT require rolling back any
  sibling CHANGELOG entry.
