# Changelog

All notable changes to `data-etl-orchestrator` are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/); this
project ships as a skills-only Claude Code plugin (Markdown + JSON +
optional Bash), so "changes" are almost exclusively documentation and
harness surface — there is no runtime code to semver.

## [1.1.0] — 2026-04-21 (plugin-side field-notes patch)

*Patch release on top of v1.0.0. All changes are plugin-side documentation
and skill edits plus three stdlib-only helper scripts; the sibling version
floor is unchanged (`kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0`), so
this unblocks users today without re-running the v1.0.0 ecosystem cutover.
Five findings (FIELD-1, FIELD-2 final, FIELD-3 final, FIELD-5, FIELD-6
final, FIELD-7, FIELD-11 final, FIELD-12 final, FIELD-14 final) require
sibling-MCP changes to fully close and are tracked for v1.2.0, gated on
`agent-knowledgebase v0.7.0`. FIELD-9 is a priority debug item; the
investigation spike with symptom, repro plan, localization hypotheses,
proposed fix shape, exit criteria, and regression guard is landed in
`docs/field-9-repro.md`.*

### Added

- **FIELD-2 interim** — routing-canary (`row_selector="1=0"`) Stage-0
  probe in `skills/references/preflight-questionnaire.md` replaces the
  uninformative `kb_config_show scope=env` check. Confirms the MCP routing
  path is live before any real ingest rows are committed.
- **FIELD-3 interim** — "Cleanup pass (FIELD-3 interim)" section in
  `skills/load-kb-from-sql/SKILL.md` documents the `status: "failed",
  chunk_count: 0` silent-data-loss hazard and the `kb_list_sources` /
  `kb_remove_source` retry sequence. Companion "Failure-state semantics"
  section added to `skills/references/idempotency-and-dedup.md` with
  explicit prune-and-retry recipe.
- **FIELD-4** — "Dependency-change warning" subsection in `README.md`
  and `uv sync` pause protocol in NEW `skills/references/session-hygiene.md`.
  Describes safe mid-session reconnect flow: `/mcp disconnect` → `uv sync`
  → `/mcp connect`.
- **FIELD-6 interim** — Ollama cold-start warmup step added to Stage-0
  in `skills/references/preflight-questionnaire.md`; issues a throwaway
  `ollama run qwen3-embedding:8b "hello"` call before the first real
  embedding request to avoid silent first-batch timeout.
- **FIELD-8** — Parallelism rule reconciled from absolute-form "Do not
  parallelize" to "All `kb_ingest_batch` calls within a single subagent
  are sequential"; NEW `skills/references/subagent-dispatch-protocol.md`
  § "Parallel-subagent boundary" documents the disjoint-scope rule with
  worked safe and unsafe examples.
- **FIELD-9 (priority)** — Investigation spike in NEW `docs/field-9-repro.md`
  (symptom, repro plan, localization hypotheses, proposed fix shape, exit
  criteria, regression guard). Plugin-side recovery recipe in NEW
  `skills/references/session-hygiene.md`.
- **FIELD-10** — `kb_info` liveness check + stale-pointer prune/abort
  branch added to `skills/references/preflight-questionnaire.md` Q1;
  new step 6 ("Prune-or-abort user prompt") added to
  `skills/references/kb-memory-pointer-protocol.md` § "Stale-pointer
  recovery flow".
- **FIELD-11 interim** — NEW `scripts/check-embedder.sh` and
  `scripts/check-embedder.ps1` (stdlib-only embedder health probes);
  Stage-0 probe step added to
  `skills/references/preflight-questionnaire.md`.
- **FIELD-12 interim** — NEW `scripts/build_staging_db_template.py`
  (stdlib-only staging DB template builder with no external dependencies).
- **FIELD-13** — Memory pointer emission auto-template in
  `skills/load-kb-from-sql/SKILL.md` replaces the hand-substitution step;
  grep-audited so no `<new_kb_id>` literal placeholders survive in
  `skills/`.
- **FIELD-14 interim** — Silent-blocking hazard section added to
  `skills/references/mcp-tool-contracts.md`; "Concurrent KB-query cost"
  section added to `skills/references/subagent-dispatch-protocol.md`;
  retrieval-flow embedder-health gate added to
  `skills/references/preflight-questionnaire.md`.

### Changed

- `skills/load-kb-from-sql/SKILL.md` "Memory pointer update" section
  renamed to "Memory pointer emission (FIELD-13)" and now auto-emits the
  pointer file rather than requiring hand-substitution of `<new_kb_id>`.
- `skills/references/kb-memory-pointer-protocol.md` Stale-pointer recovery
  flow gains step 6 (prune/abort user-prompt); former steps 6 and 7
  renumbered to 7 and 8.
- `skills/load-kb-from-sql/SKILL.md` parallelism bullets in "Batch
  construction and ingestion" and "Do not do these things" reworded to
  within-subagent scoping (sequential within a subagent; cross-subagent
  parallelism allowed when scopes are disjoint).
- `skills/references/INDEX.md` updated to list `session-hygiene.md`.

### Preserved

- `plugin.json` invariant: 8 skills + 1 command + 0 tools + 0 mcpServers.
- Sibling version floors unchanged (`kb >= 0.6.0 / yt >= 0.5.0 /
  x-api >= 0.4.0`).
- `/etl-config` + `/etl-overview` entry-point contract unchanged.
- Four-stage flow (Clarify → Fetch → Verify → Load) unchanged.
- Memory-pointer ritual (`memory/kb_<slug>.md` + `MEMORY.md` + `kb_info`
  verification) refined but not replaced.
- 50-row cap on `kb_ingest_batch` unchanged.

### Sibling-gated follow-on (tracked for v1.2.0, gated on agent-knowledgebase v0.7.0)

- **FIELD-1** — consume sibling `openai_available` flag; remove interim
  `import openai` probe.
- **FIELD-2 (final)** — restore `kb_config_show scope=env` once sibling
  echoes inherited env vars.
- **FIELD-3 (final)** — remove plugin-side cleanup pass once sibling rolls
  back failed source records automatically.
- **FIELD-5** — update `skills/references/mcp-tool-contracts.md` and
  `load-kb-from-sql` patterns once wiki index builder honors
  `kb_source_label`.
- **FIELD-6 (final)** — replace warmup script with `kb_warmup` tool call.
- **FIELD-7** — pin `kb_ingest_batch` response schema (`embedding_complete`
  / `chunks_embedded`).
- **FIELD-11 (final)** — replace `check-embedder` scripts with
  `kb_embedder_health` MCP tool.
- **FIELD-12 (final)** — replace `build_staging_db_template.py` with
  `kb_stage_from_sql` MCP tool.
- **FIELD-14 (final)** — consume bounded timeout + progress events +
  internal embedder preflight; remove interim silent-blocking warnings.
- **Contract-probe-protocol** — add probe-5 for health/warmup/stage-from-sql
  and probe-6 for retrieval timeout / progress-event shape.

## [1.0.0] — 2026-04-20 (ecosystem release)

*Tag lands after sibling v0.6.0/v0.5.0/v0.4.0 tags resolve in marketplace.
Rollback floor: v0.3.0-rc.1 (see release-gates.md rollback clause).*

Ecosystem cutover from the 2026-04 v0.2.0 baseline to v1.0.0, landing
alongside the sibling v0.3.0 drop (agent-knowledgebase v0.6.0,
youtube-mcp v0.5.0, x-api-mcp v0.4.0). The tag is held until the Phase 6
marketplace-resolution gate passes AND week-one post-cutover monitoring
surfaces no probe-4 regression. If a regression surfaces, the
orchestrator stays at `v0.3.0-rc.1` until a patched v1.0.x ships — see
`skills/references/release-gates.md` § "Rollback clause (Phase 6)".

### Added

- **Safe-where-clause grammar canonical reference** — `skills/references/
  safe-where-clause-grammar.md` lands as the single source of truth for
  the three canned WHERE patterns (ID list, date range, author) plus the
  "no free-form filters" warning. Mirrored from the kb repo so the
  orchestrator's `load-kb-from-sql` skill and the sibling tool contract
  both reference the same document.
- **Stage-0 defaults reference** — `skills/references/stage-0-defaults.md`
  notes how `/etl-config` reuses the last confirmed plan (YAML file under
  `.claude/etl-orchestrator/last-plan.yaml`) and re-states the
  `AskUserQuestion` 1-4-questions-per-call limit verified in Phase 0.
- **better-sqlite3 / node:sqlite asymmetry section** in
  `skills/references/mcp-tool-contracts.md` — documents the platform
  split between `x-api-mcp` (better-sqlite3) and `youtube-mcp` (node:sqlite)
  so orchestrator skills pick the right repo API when reasoning about
  transaction semantics.
- **Ensemble contract probe (Probe 4)** in
  `skills/references/contract-probe-protocol.md` — the 4th probe runs
  after probes 1-3 pass and asserts 5 invariants on a shared canary call
  (envelope zod parse, unified status vocabulary, kb stderr log shape,
  silent-DB-failure canary with 100 ms stderr deadline, `dedup_key`
  polymorphism). Structured failure template names the three sibling
  version floors (`kb >= 0.6.0 / yt >= 0.5.0 / x-api >= 0.4.0`).
- **S13 unified-status-vocabulary grep** in
  `skills/references/phase-8-review-checklist.md` — new row asserts zero
  hits on `crawled|scraped|queued|in_progress` status-comparison forms
  across `skills/` (broader than S9 which only covers `crawled|scraped`).
  Harness-doc excludes documented inline.
- **Pre-tool-use hook template stub** — `scripts/pre-tool-use-template.sh`
  blocks `Read`/`Write`/`Edit` on transcript, tweet-body, article-body,
  or MCP cache DB paths. Opt-in; documented in README § "Opt-in pre-tool-
  use hook".
- **16/16 release-gate grid** in `skills/references/release-gates.md` —
  refresh from the v0.2.0 15/15 baseline to 16 distinct tasks (A1-A7,
  Y1-Y7, X0-X9, E1 ensemble probe). Adds install-order cross-check
  subsection, marketplace-resolution verification subsection, and
  rollback-clause subsection.
- **Marketplace-resolution verification gate** — new placeholder script
  `scripts/verify-marketplace-resolution.sh` enforces the R12 mitigation
  invariant: before the orchestrator v1.0.0 tag is cut, all three
  sibling plugins MUST resolve at their expected floor from
  `goosefly99-plugins-auto-dev`. Bash-only; Windows operators run via
  Git Bash or WSL. Placeholder because `claude plugin query` CLI does
  not yet exist — fails closed until wired up. Manual-checklist fallback
  documented in `release-gates.md`.
- **Rollback clause** — if week-one post-cutover monitoring surfaces any
  probe-4 regression, the orchestrator tag STAYS at `v0.3.0-rc.1` until
  a patched v1.0.x ships. Scope is orchestrator-only; sibling v0.3.0
  tags are not rolled back. Decision + monitoring-window record logged
  in `cron-log.md`.

### Changed

- `skills/references/release-gates.md` grid header updated from
  "15-task status" to "16-task status"; aggregate count updated to 16/16
  green; breakdown table adds ensemble probe row; release-order reminder
  extended with the v0.3.0 ordering (A5-A7 inside kb v0.6.0; X7-X9
  gate yt v0.5.0; Y5-Y7 consume x-api handler-layer metric vocabulary;
  E1 inside orchestrator v1.0.0).
- Contract-probe version-floor phrase `kb >= 0.6.0 / yt >= 0.5.0 /
  x-api >= 0.4.0` is the canonical character-for-character string that
  the install-order cross-check (SC12) asserts sibling READMEs contain
  verbatim.

### Preserved

- The `/etl-config` + `/etl-overview` entry-point contract is unchanged.
- 8-skill layout (1 router + 7 ingest/load) unchanged.
- No MCP tool surface (`plugin.json` still declares no `mcpServers`, no
  `tools`). Install order preserved: agent-knowledgebase first, then
  youtube-mcp + x-api-mcp in any order, then data-etl-orchestrator, then
  optional crawler-mcp.

### Phase 6 gates pending

- Marketplace-resolution gate (`scripts/verify-marketplace-resolution.sh`
  exits 0, or manual-checklist fallback logged in `cron-log.md`).
- Week-one post-cutover monitoring (stderr sweep + user bug reports).
  Rollback clause honored on any probe-4 regression.

## [0.2.0] — 2026-04-18

Baseline for the cutover grid above. 15/15 sibling-gate tasks green
(A1-A4 agent-knowledgebase, Y1-Y4 youtube-mcp, X0-X6 x-api-mcp); all 8
dry-run walkthroughs green; S1-S12 static skill-body sweep clean; BUG-1
through BUG-4 + CON-1 through CON-3 all closed. Tagged on commit
`700d67e`. See `ROADMAP.md` § "Phase 8 — Dry-run walkthrough + publish"
for the full exit-criterion evidence.

[1.1.0]: https://example.invalid/data-etl-orchestrator/compare/v1.0.0...v1.1.0
[1.0.0]: https://example.invalid/data-etl-orchestrator/compare/v0.2.0...v1.0.0
[0.2.0]: https://example.invalid/data-etl-orchestrator/releases/tag/v0.2.0
