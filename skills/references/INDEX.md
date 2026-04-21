# References index

Canonical reference docs for the data-etl-orchestrator skills. Every
skill links to the docs it depends on. This index is a discoverability
layer; the docs below are the source of truth.

| File | Purpose |
|------|---------|
| [bug-closure.md](bug-closure.md) | Evidence table of verified bug fixes committed on the roadmap-implementation branch. |
| [contract-probe-protocol.md](contract-probe-protocol.md) | Lightweight probe calls against 3 sibling MCPs before Stage 1 to catch contract drift. |
| [deliverable-format.md](deliverable-format.md) | Mandates the fixed 6-section output format every sub-skill report must conform to. |
| [idempotency-and-dedup.md](idempotency-and-dedup.md) | Dedup keys per source type; prevents duplicate rows and KB pages on repeat runs. |
| [kb-memory-pointer-protocol.md](kb-memory-pointer-protocol.md) | Keeps the KB memory pointer accurate across renames, recreates, and conversation resets. |
| [kb-source-types.md](kb-source-types.md) | Decision table for which `source_type` to pass to `kb_ingest`; `sql_database` is canonical for MCP-cached data. |
| [mcp-tool-contracts.md](mcp-tool-contracts.md) | Pins authoritative tool signatures and response envelopes for youtube-mcp and x-api-mcp. |
| [phase-8-assertions.md](phase-8-assertions.md) | Defines the markdown-only verification harness (Option B) and forbidden-pattern regex set. |
| [phase-8-review-checklist.md](phase-8-review-checklist.md) | Shell-command checklist for verifying payload-byte invariants across skill text and dry-run transcripts. |
| [preflight-questionnaire.md](preflight-questionnaire.md) | Mandatory Stage-0 gate: 7 questions that must be resolved before any data tool is called. |
| [release-gates.md](release-gates.md) | Read-only mirror of sibling plugin release status for agent-knowledgebase, youtube-mcp, and x-api-mcp. |
| [source-db-schemas.md](source-db-schemas.md) | Ground-truth source-MCP cache schemas used by Stage-3 batch construction for table and dedup-key references. |
| [session-hygiene.md](session-hygiene.md) | Pause protocol for `uv sync` mid-session (FIELD-4) and interrupt-recovery recipe for MCP server disconnects (FIELD-9). |
| [subagent-dispatch-protocol.md](subagent-dispatch-protocol.md) | Contract between parent agent and dispatched Sonnet subagent for Stage-3 batch KB ingestion. |
