# Stage-0 defaults and last-plan reuse

This document pins the orchestrator's Stage-0 resume behaviour — how
the 7-question questionnaire's resolved plan is cached on disk and
how the `/etl-config` slash command offers reuse on the next
invocation. It also records the AskUserQuestion limit verification
that was the Phase-0 gate for the v1.0.0 release.

## `last-plan` cache

Path: `.claude/etl-orchestrator/last-plan.yaml` — project-local, never
committed to a repo, never shared across projects. The path is
relative to the project root (i.e. the directory containing
`.claude/`), not the user home.

### Write semantics

On Q7 confirmation (the final "go-ahead" step of the Stage-0
questionnaire), the orchestrator writes the resolved Stage-0 plan to
`last-plan.yaml`. The write happens after explicit user confirmation
and before the contract probe runs.

Shape:

```yaml
target_kb: "<kb name or slug>"
source_spec:
  source_type: "<youtube_playlist|youtube_videos|x_bookmarks|x_user_tweets|x_thread|local_files|sql_database>"
  # Plus source-specific keys (playlist_id / video_ids / handle / root_tweet_id / paths / db_path).
db_path: "<absolute path to source MCP cache DB>"
granularity: "row | batch"
dedup_policy: "skip | re-ingest | force-add"
embeddings_model: "<endpoint identifier, e.g. 'ollama:default' or a custom URL>"
created_at: "<ISO8601 UTC timestamp>"
```

The orchestrator does not persist raw tweet/transcript/article
payload bytes; `last-plan.yaml` is strictly configuration.

### Read semantics

On re-invocation from the `/etl-config` slash command, the
orchestrator first checks for `.claude/etl-orchestrator/last-plan.yaml`.
If the file exists and parses, the orchestrator offers:

> `Reuse last plan from <ISO8601>? (yes / edit / start fresh)`

- **yes** — skip the questionnaire, carry `last-plan.yaml` forward
  into the contract probe step, and proceed directly to sub-skill
  dispatch.
- **edit** — prefill each Stage-0 answer with the cached value, then
  ask the user to confirm or override per-question.
- **start fresh** — ignore the cache and run the full questionnaire.

Never reuse without explicit user confirmation. A missing, malformed,
or unreadable cache file falls back to a fresh questionnaire with no
prompt.

## AskUserQuestion limit verification

- Verification date: 2026-04-20
- Claude Code version: Opus 4.7 (model id: `claude-opus-4-7`)
- Confirmed limit: 1-4 questions per call — limit intact, no cascade
  edits required.

The Stage-0 questionnaire's grouping advice in
`preflight-questionnaire.md` (the 7-question batching and the
"up to 4 questions per AskUserQuestion call" claim) was pre-verified
against the live harness JSONSchema before Phase 3 landed.

See `docs/phase-0-askuserquestion-verification.md` for the full
report, including the observed schema fragment (`"maxItems": 4,
"minItems": 1`) and the Phase-3 unblocking decision.
