# Preflight Questionnaire — Stage 0

## Purpose

Stage 0 is a mandatory gate. No MCP data tool may be called until all seven questions are resolved and the user has given an explicit go-ahead. This prevents partial-state writes (e.g., rows inserted to a source DB but no corresponding KB ingest), makes the operation plan reviewable, and ensures dedup, granularity, and KB-target decisions are locked before any data moves. Every skill in this plugin points here for the canonical question spec.

---

## Question 1: Target KB

- Call `kb_list()` to retrieve existing KBs.
- Present the list and ask: "Which KB should this go into, or should we create a new one?"
- If the user names a KB: match by name (case-insensitive). If a memory pointer exists at `memory/kb_<slug>.md`, read the stored id, then verify with `kb_info(id)`. If `kb_info` returns "not found", fall back to `kb_list` and re-match by name (see `kb-memory-pointer-protocol.md`).
- If the user names a KB but no pointer file exists: confirm the selected KB id from `kb_list` results before proceeding.
- If new KB:
  - Collect `name` (human-readable), `description` (one sentence).
  - Ask: "Create a memory pointer for this KB?" (default: yes).

### Stale memory-pointer handling

After reading a pointer file at `memory/kb_<slug>.md`, ALWAYS call `kb_info(stored_id)` before using the id. No exception, even if the id "looks right".

- On `kb_info` returning "not found" (or the name field disagreeing with the pointer file): call `kb_list()` and re-match by name (case-insensitive, trim whitespace).
- On exactly-one match: propose two options to the user:
  a) **Prune** the stale entry from `MEMORY.md` and rewrite the pointer file (`memory/kb_<slug>.md`) with the new id + current ISO date in `Last verified`.
  b) **Abort** Stage 0 and let the user fix the pointer manually.
- On multiple matches or no match: present the list (or the empty state) to the user and ask which KB to use, or offer to create a new one.

Full protocol in `kb-memory-pointer-protocol.md` § Stale-pointer recovery flow.

---

## Question 2: Source(s)

Multi-select from: `youtube`, `x`, `local_files`, `crawler`.

### YouTube sub-questions (mutually exclusive — pick one):
- Playlist ID or URL
- One or more video IDs or YouTube URLs (comma/newline-separated)
- Channel handle + limit (e.g., `@channelHandle`, max 500)

### X sub-questions (pick one or more):
- `bookmarks` — max count (default: 200)
- User handle — resolve to `user_id` via `x_get_user(username)`, then `x_get_user_tweets`; max count
- Thread id — root tweet id
- Search query — query string + max count
- Saved articles — from cache (`x_get_saved_articles`)

### Local files sub-questions:
- Absolute path(s) (one per line)
- Recursive? (yes / no)
- Glob filter (e.g., `*.md`, `*.pdf`; leave blank for all)

### Crawler sub-questions:
- Seed URL(s)
- Crawl depth (default: 2)
- Domain allowlist (comma-separated; leave blank to allow all subdomains of seed)

---

## Question 3: Source DB path override

For each selected MCP source, confirm or override the default DB path.

| Source MCP | Default path | Env override |
|---|---|---|
| youtube-mcp | `W:\youtube_mcp_db\youtube-data.db` | `YOUTUBE_MCP_DB_PATH` |
| x-api-mcp | `~/.x-api-mcp/x-data.db` | `X_API_DB_PATH` |
| crawler-mcp | stateless — no DB | — |

- Present the default. Ask: "Use default path or specify an absolute path?"
- If env var is set, state the resolved value and ask for confirmation.

---

## Question 4: KB ingest granularity

"Should each item (video, tweet, article) become its own KB source, or should the whole batch be one KB source?"

- **Per item (default)** — one `kb_ingest` call per row. Better vector retrieval, finer-grained search results. More KB sources created.
- **Per batch** — one `kb_ingest_batch` call covering all rows via a single `WHERE` clause. Fewer sources, coarser search granularity.

State the default clearly. Let the user override.

---

## Question 5: Dedup policy

"What should happen if an item is already ingested in this KB?"

Options:
- **skip** (default) — drop any item whose dedup key already appears in `kb_list_pages`.
- **re-ingest** — proceed; server replaces or updates the existing source.
- **force-add** — proceed regardless; accept duplicates in the KB.

---

## Question 6: Embeddings model

"Which embeddings model endpoint should be used for the KB records, if the default ollama embeddings model is not available?"

- If the default ollama embeddings model is available and the user has no preference, accept the default.
- If the user specifies an alternative endpoint, record it for use in Stage 3 ingest calls.

---

## Question 7: Confirmation (go-ahead gate)

Echo the resolved plan as a single block before asking for approval. Include:

- Target KB: `<name>` (`<id>`)
- Source(s): type, scope, estimated item count
- DB path(s): resolved absolute path(s)
- Ingest granularity: per-item / per-batch
- Dedup policy: skip / re-ingest / force-add
- Embeddings model: default ollama / `<override endpoint>`

Ask: "Proceed with this plan? (yes / no / edit)"

Do not invoke any Stage 1 tool until the user replies "yes".

---

## Stage-0 warmup (pre-Q1 environment check)

Before Q1, run the following environment probes. All are read-only and
out-of-band — they do not write to any KB or source DB.

### 1. Embedder reachability (FIELD-11 interim)

Run `scripts/check-embedder.sh` (Linux / macOS / WSL) or
`scripts/check-embedder.ps1` (Windows PowerShell). Expect a JSON
response of shape `{"up": true, "latency_ms": N, "endpoint": "..."}`.

If the script exits non-zero or reports `"up": false`, halt Stage 0
and instruct the user to start the embedder (e.g., `ollama serve` or
the configured OpenAI endpoint) before proceeding.

> **Temporary stopgap.** This script is replaced by a sibling
> `kb_embedder_health` tool in agent-knowledgebase v0.7.0; once that
> lands, this step becomes a single `kb_embedder_health` call.

### 2. Ollama cold-start warmup (FIELD-6 interim)

If the configured embedder is a local Ollama model, run one warmup
request out-of-band so the first real `kb_query` or `kb_ingest_batch`
does not pay the 30-35-minute cold-model-load cost silently:

```bash
ollama run qwen3-embedding:8b "hello"
```

Substitute the configured model name if different. State clearly to
the user that cold starts are silent and can take tens of minutes;
skipping this step turns the first query into an unrecoverable wait.

### 3. Routing canary (FIELD-2 interim, replaces `kb_config_show scope=env`)

`kb_config_show scope=env` currently returns `{}` because the server
does not echo inherited env vars. Replace this check with a
single-source `kb_ingest_batch` call using a WHERE clause that
matches no rows (`row_selector="1=0"`). This exercises the routing
path without triggering any embed, and the returned source metadata
reveals which provider was selected.

Invoke:

```json
{
  "kb_id": "<target kb_id>",
  "sources": [{
    "source_type": "sql_database",
    "uri": "sqlite:///<any populated source DB>",
    "metadata": {
      "table": "<any real table in the DB>",
      "row_selector": "1=0",
      "kb_source_label": "stage-0:routing-canary"
    }
  }]
}
```

Inspect the response for the embedder / provider field. Halt Stage-0
if the provider does not match the Stage-0 Q6 selection.

> **Temporary stopgap.** Once agent-knowledgebase v0.7.0 extends
> `kb_config_show scope=env` to echo inherited env vars, this canary
> is replaced by the original `kb_config_show` check.

### 4. Retrieval-flow gate (FIELD-14 interim)

If the run being planned is retrieval-heavy (any `kb_query` /
`kb_search` expected before or after ingest — e.g., the ETL caller
is chaining a query step), the probes above MUST pass before Q1
proceeds. Silent-blocking `kb_query` hangs (30-minute observed
waits) are avoided by short-circuiting Stage-0 on an unreachable
embedder rather than letting `kb_query` hang. Sibling timeout +
progress-event support lands in agent-knowledgebase v0.7.0.

---

## Implementation note

Issue Questions 1–6 via `AskUserQuestion` calls. The tool supports up to 4 questions per call; group related sub-questions together to minimize round-trips. Question 7 is a final single-select confirmation using a preview of the resolved plan text. Never skip Question 7 even if Questions 1–6 seemed unambiguous.

---

## Re-run and persistence policy

The preflight questionnaire is itself idempotent. Re-running it with
identical answers must produce the same resolved plan. If the user
re-invokes the skill in the same session or a new session, re-ask
Stage 0 from scratch rather than reusing earlier answers from
conversation memory. Conversation memory of prior Stage-0 answers is
not reliable and must not substitute for a fresh questionnaire.

This text is duplicated in
[idempotency-and-dedup.md](idempotency-and-dedup.md) under "Idempotent
Stage 0"; the two sections must stay in sync. If the re-run policy
ever changes, update both locations.

---

## AskUserQuestion grouping guidance

Claude Code's `AskUserQuestion` tool accepts 1–4 questions per call,
with 2–4 options per question. Deliver the 7-question Stage-0
questionnaire in two calls:

- **Call 1:** Q1 (Target KB), Q2 (Source), Q3 (DB path override),
  Q4 (KB ingest granularity).
- **Call 2:** Q5 (dedup policy), Q6 (embeddings model), Q7
  (confirmation).

Q7 is a single-select confirmation of the resolved plan and must appear
as the last question in call 2. Never pack Q7 into call 1.

If `AskUserQuestion` is unavailable in the current harness, fall back
to sequential per-question prompts; do not collapse multi-part answers
into a single free-text reply.
