# KB Memory Pointer Protocol

## Purpose

Keeps the KB's memory pointer accurate across renames, recreates, and conversation resets. Trusting a recalled KB id from conversation memory without live verification was the failure mode documented in `db_operations_plugins_claude_errors.txt`. This protocol prevents it.

---

## Location

Pointer files live at:

```
C:\Users\olive\.claude\projects\<project_slug>\memory\kb_<slug>.md
```

The `MEMORY.md` index file is in the same directory.

---

## Pointer file structure

```markdown
---
name: <slug> KB pointer
description: Pointer to the <KB name> knowledgebase (id + one-line purpose)
type: reference
---

Knowledgebase name: <KB name>
Knowledgebase id: <uuid>
Purpose: <one-sentence>
Last verified: <ISO date>
```

- `type: reference` is required in the frontmatter.
- `Last verified` must be updated on every confirmed `kb_info` call.

---

## MEMORY.md index line

Add or update a single line in `MEMORY.md`:

```
- [<slug> KB](kb_<slug>.md) — <one-line hook>
```

Keep the line under 150 characters total.

---

## When to update

Update immediately after any of the following events:

1. `kb_create` — write the new pointer file and MEMORY.md line.
2. A KB rename — update `Knowledgebase name` and the MEMORY.md hook text.
3. A `kb_info` call whose returned `name` or `id` disagrees with the stored pointer — rewrite both fields and update `Last verified`.

---

## How to verify

Always call `kb_info(id)` before trusting a stale pointer. Do not use a KB id recalled from earlier in the conversation without this check.

---

## Stale-pointer recovery flow

1. Read the pointer file at `memory/kb_<slug>.md`.
2. Call `kb_info(stored_id)`.
3. If `kb_info` returns "not found":
   - Call `kb_list()`.
   - Match by name (case-insensitive, trim whitespace).
4. If exactly one match: use that KB id.
5. If multiple matches: present the list to the user and ask which one to use.
6. When the resolved id differs from the stored pointer, prompt the
   user to choose: (a) **prune** the stale MEMORY.md index line and
   rewrite `memory/kb_<slug>.md` with the resolved id, or
   (b) **abort** Stage 0 so they can investigate. Do not silently
   rewrite the pointer.
7. If no match: ask the user whether to create a new KB or abort.
8. After resolving: overwrite the pointer file with the correct id and set `Last verified` to today's date. Update the MEMORY.md index line to match.

---

## Failure mode to avoid

Do not read a KB id from conversation context and pass it directly to `kb_ingest` or `kb_ingest_batch`. Always confirm via `kb_info` first. Stale ids accumulate when KBs are deleted and recreated between sessions — verification is cheap; a misrouted ingest is not.

---

## See also

- `preflight-questionnaire.md` § Q1 Target KB — Stage-0 invokes this
  protocol on every ETL run.
- `session-hygiene.md` — the interrupt-recovery recipe re-runs this
  verification as part of recovering from a dropped MCP connection.
