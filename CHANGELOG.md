# Changelog

All notable changes to `data-etl-orchestrator` are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/); this
project ships as a skills-only Claude Code plugin (Markdown + JSON +
optional Bash), so "changes" are almost exclusively documentation and
harness surface — there is no runtime code to semver.

## [1.0.0] — Unreleased (pending Phase 6 monitoring + rollback verdict)

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

[1.0.0]: https://example.invalid/data-etl-orchestrator/compare/v0.2.0...v1.0.0
[0.2.0]: https://example.invalid/data-etl-orchestrator/releases/tag/v0.2.0
