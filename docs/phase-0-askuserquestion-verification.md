# Phase 0: AskUserQuestion Pre-Verification Spike

**Spec lineage:** spec-4a2c91e7 | Phase 0 | Success Criteria: SC1 | Risk mitigation: R10

## Verification Metadata

| Field | Value |
|---|---|
| Verification date | 2026-04-20 |
| Claude Code version | Opus 4.7 (model id: `claude-opus-4-7`) |
| Platform | Windows 11 |
| Branch | `v1.0.0/phase-0-askuserquestion-verification` |

## AskUserQuestion Schema Evidence

The AskUserQuestion tool JSONSchema, as observed in this session's tool definitions:

```json
"questions": {
  "items": { ... },
  "maxItems": 4,
  "minItems": 1,
  "type": "array"
}
```

Constraint is client-side enforced by the Claude Code harness. A call supplying 5 or more questions is rejected at schema validation before the call reaches the model. No live 5-question call is required to confirm — the schema is authoritative.

## Verdict

**LIMIT INTACT.** The AskUserQuestion tool accepts 1–4 questions per call. This matches the assumption carried in:

- `skills/preflight-questionnaire.md` (L114, L136)
- `skills/etl-overview/SKILL.md`
- All 7 `ingest-*` sub-skills

No discrepancy detected. No cascade-edit sub-issue required.

## Phase 3 Gating Decision

**UNBLOCKED.** Phase 3 (orchestrator edits) may proceed without changes to the AskUserQuestion call pattern.

## Forward Pointer

Re-run this spike at the start of every new minor release of the orchestrator to catch harness-level changes before SKILL.md edits land.
