---
name: ingest-local-files
description: "Ingest local files (absolute paths) into an agent-knowledgebase. Agent never reads file content - passes the path to kb_ingest(source_type=file). Trigger: 'ingest this folder/file into my KB', '/ingest-local-files'."
---

## When to use this skill

- "ingest this file / folder into my KB"
- "add these documents to my knowledgebase"
- "load [PDF / markdown / txt files] into [KB name]"
- `/ingest-local-files`

Do not invoke if `etl-overview` Stage 0 is not yet complete.

---

## Stage-0 prerequisites

Before dispatch, run the Stage-0 questionnaire — see
[preflight-questionnaire.md](../references/preflight-questionnaire.md).

---

## Preconditions

Stage 0 must be complete (see `skills/etl-overview/SKILL.md`). Required answers:

- Target KB (existing or new name/slug).
- Absolute path(s): individual files or directories.
- For directory mode: glob pattern, recursive flag.
- Dedup policy (skip / re-ingest / force-add).
- KB ingest granularity (one KB source per file vs. per batch).

**This skill is the ONLY skill in this plugin that uses `source_type="file"` or `source_type="directory"`.** All other ingest skills use `source_type="sql_database"` because their data flows through an MCP cache DB first. Local files have no cache layer — the on-disk file IS the source of truth.

---

## Stage 1 — Fetch

Not applicable. The user already has the files on disk. No MCP fetch step.

---

## Stage 2 — Confirm paths and compute dedup keys

**IMPORTANT: The agent must NOT read file contents at any point. Only paths and hashes are captured.**

**Step 2a — Verify paths exist.**

Run a directory listing via `Bash` (e.g., `ls -la <path>` or `dir <path>`). Confirm each supplied path is accessible. Flag missing paths as errors before proceeding — do not silently skip them.

**Step 2b — Compute SHA-256 hashes (file mode only).**

For individual files, compute hashes via `Bash`:

```bash
# Windows (PowerShell)
Get-FileHash -Algorithm SHA256 "C:\absolute\path\to\file.pdf" | Select-Object -ExpandProperty Hash

# Windows (cmd)
certutil -hashfile "C:\absolute\path\to\file.pdf" SHA256

# Linux/macOS
sha256sum /absolute/path/to/file.pdf
```

Capture the hash string only. Do not read, print, or relay any file content.

**Step 2c — Dedup check.**

Call `kb_list_pages(kb_id)` and scan existing source metadata for `sha256` fields matching any computed hash. Apply Stage-0 dedup policy:

- `skip` — omit files whose SHA-256 is already present.
- `re-ingest` — re-submit matching files; the KB will update the existing source.
- `force-add` — submit regardless; creates a duplicate source entry.

For directory mode, dedup key is the directory `uri` rather than per-file SHA-256.

---

## Stage 3 — Ingest into KB

**KB resolution.**

1. Call `kb_list` and match against the Stage-0 KB name or memory pointer.
2. If the KB is new: `kb_create`, then create `memory/kb_<slug>.md` and update `MEMORY.md` index. Verify with `kb_info`.

**Batch ingestion — file mode.**

Split file list into chunks of at most 50. For each chunk:

```
kb_ingest_batch([
  {
    source_type: "file",
    uri: "/absolute/path/to/document.pdf",
    metadata: {
      sha256: "<hash>",
      relative_name: "document.pdf"
    }
  },
  ...
])
```

**Batch ingestion — directory mode.**

```
kb_ingest_batch([
  {
    source_type: "directory",
    uri: "/absolute/path/to/dir",
    metadata: {
      glob: "**/*.md",
      recursive: true
    }
  }
])
```

- Calls are sequential, not parallel.
- Do NOT use `source_type="sql_database"` for local files. There is no MCP cache DB for this source type.

---

## Partial success handling

- A file that fails to parse (unsupported format, binary, corrupt) is logged with reason and skipped. It is not a fatal error.
- After the batch run, call `kb_list_pages(kb_id)` and `kb_list_sources(kb_id)` to confirm ingested count matches expectation. Report any discrepancy.

---

## Deliverable

This skill emits the standard ETL deliverable. See
[deliverable-format.md](../references/deliverable-format.md).

---

## Idempotency and envelopes

Dedup behaviour per source is documented in
[idempotency-and-dedup.md](../references/idempotency-and-dedup.md).
Sibling MCP response envelopes (including `articles: Article[]`) are
pinned in [mcp-tool-contracts.md](../references/mcp-tool-contracts.md).

---

## Do not do these things

- **Do NOT read, print, or relay file contents at any step.** The agent handles paths and hashes only.
- Do NOT use `source_type="sql_database"` for local files.
- Do NOT use `source_type="file"` for tweets, transcripts, or other MCP-sourced data.
- Do NOT skip Stage 2 path verification — a missing-file error at ingest time is harder to diagnose than at path-check time.
- Do NOT run `kb_ingest_batch` calls in parallel.
- Do NOT start Stage 3 before Stage 0 confirmation.

---

## References

- `references/preflight-questionnaire.md` — Stage 0 canonical spec
- `references/deliverable-format.md` — standard deliverable structure
- `references/idempotency-and-dedup.md` — dedup behaviour per source
- `references/mcp-tool-contracts.md` — tool signatures and response contracts
- `references/kb-memory-pointer-protocol.md` — memory pointer update spec
