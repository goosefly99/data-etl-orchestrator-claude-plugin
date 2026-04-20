# Safe `row_selector` grammar for `kb_ingest_batch` (orchestrator mirror)

This document is a short-form mirror of the canonical allow-list
reference shipped with the agent-knowledgebase MCP server. The
canonical source — including the full BNF, per-code rejection table,
and validator wiring — lives at
`agent-knowledgebase/docs/safe-where-clause-grammar.md`. Read the
canonical whenever you need the authoritative grammar; this mirror
exists so orchestrator skills can cite a stable path inside the plugin
without requiring readers to follow a cross-repo link.

## Allow-list summary

- **Comparison operators.** `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=` —
  identifier on one side, literal or identifier on the other.
- **Logical operators.** `AND`, `OR`, `NOT`, with parenthesised
  grouping `( expr )`. Parens do not introduce subqueries.
- **Identifiers.** Bare `[A-Za-z_][A-Za-z0-9_]*`; table-qualified
  names (`t.col`) are rejected in the current release and reserved
  for v0.4.0 scoping work.
- **Literals.** Single-quoted strings (with a doubled-apostrophe
  escape for embedded `'`), integers, and floats. `NULL` is accepted
  only inside a null-check predicate.
- **`IS NULL` / `IS NOT NULL`.** The only accepted way to test for
  `NULL`; `col = NULL` always evaluates to `NULL`, never true.
- **`IN (...)` / `NOT IN (...)`.** Membership against a
  comma-separated literal list.
- **`LIKE` / `NOT LIKE`.** String-literal pattern match with optional
  `ESCAPE 'x'` clause.

See the canonical for the complete BNF, per-category edge cases, and
validator error codes.

## Example filters (mirrors canonical)

The ten examples below are kept in sync with the canonical doc
verbatim. Any grammar change lands in the canonical first; updates
to this mirror follow.

### 1. Select a single row by primary key

```sql
id = 42
```

Use this when you know the exact row you want to ingest.

### 2. Select a small set of IDs (chained `OR`)

```sql
id = 1 OR id = 2 OR id = 3
```

Idiomatic for two or three IDs. For larger lists prefer `IN (...)`
as shown in example 10's style — it is also accepted by the
validator.

### 3. Date range

```sql
created_at >= '2026-01-01' AND created_at < '2026-04-01'
```

Half-open date range — common shape for time-windowed ingest.

### 4. Filter by author

```sql
author = 'alice'
```

One-column equality filter on a text column.

### 5. Date range combined with author

```sql
created_at >= '2026-04-01' AND author = 'bob'
```

Combines a date predicate with an equality filter.

### 6. Exclude archived rows

```sql
status != 'archived'
```

Inequality against a text column; also accepted as `status <> 'archived'`.

### 7. Filter by tag

```sql
tag = 'research'
```

Trivial equality filter; useful when the source table has a single
`tag` column per row.

### 8. Numeric comparison

```sql
word_count > 500
```

Numeric comparisons work for `INTEGER` and `REAL` / `FLOAT` columns
equally.

### 9. Null check on soft-delete column

```sql
deleted_at IS NULL
```

Null-check form — the only accepted way to test for `NULL`. Do not
write `deleted_at = NULL`; SQL compares `NULL` to `NULL` as `NULL`,
not true.

### 10. Compound `AND` / `OR` with parens

```sql
(status = 'published' OR status = 'featured') AND author != 'bot'
```

Parens are accepted for grouping. The content inside parens must
itself be a valid expression — it cannot contain a `SELECT`, a
function call, or any other denied construct.

## Deny-list summary

The validator rejects: subqueries (`SELECT ... FROM ...` inside
parens), function calls of any shape (`LOWER(...)`, `COUNT(*)`,
`JSON_EXTRACT(...)`, etc.), set operators (`UNION`, `INTERSECT`,
`EXCEPT`), CTEs and window functions, column aliases inside the
selector, table-qualified identifiers, multi-statement input
(embedded `;`), SQL comments (`--` or `/* */`), backtick-quoted
identifiers, SQLite control-plane keywords (`PRAGMA`, `ATTACH`,
`DETACH`), any DML / DDL keyword, arithmetic and bitwise operators,
bind parameters, bare wildcards outside a literal, `CASE / WHEN`
expressions, `BETWEEN`, and `CAST(...)`. Each rejection surfaces as a
`WhereClauseValidationError` with a stable `code`. See the canonical
for the per-rejection code table.

## Defense-in-depth

Allow-list validation is layered behind a SQLite `mode=ro` URI
rewrite that pins every sqlite source connection physically
read-only (`sqlite:///file:<path>?mode=ro&uri=true`). Even if the
parser misses an edge case, any write attempt surfaces as
`sqlite3.OperationalError: attempt to write a readonly database`
before touching the file.

## Canonical source

Canonical source: `agent-knowledgebase/docs/safe-where-clause-grammar.md`.
Any grammar change lands in the canonical first; this mirror follows.
