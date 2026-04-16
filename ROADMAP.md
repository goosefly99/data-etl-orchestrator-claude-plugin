# data-etl-orchestrator — Update Roadmap
Generated from code review 2026-04-15, building on run `data-etl-orchestrator-update-2026-04-13`.

Source spec: `pipeline_mcp_data/specs/data-etl-orchestrator-update-spec.json`
Plugin root: `C:\Users\olive\claude_projects\coding\agent_tools_dev\data_etl_orchestrator_dev\data-etl-orchestrator`
Plugin type: skills-only Claude Code plugin (no MCP server, no MCP tool surface).

## Release position
**Stage 4 of 4 — ships LAST.**
- Gated by (all three must land first):
  1. `agent-knowledgebase` — the sql_database uri grammar, dedup_key/dedup_policy, 50-row cap, per-kb_id serialization, augmented `kb_list_pages`/`kb_list_sources` responses.
  2. `youtube-mcp` — `get_playlist_items(hydrate=true)` + `get_video_details(includeTranscript=true)` defaults; status envelope; `get_transcript` demoted.
  3. `x-api-mcp` — auto-crawl on all 5 tweet-returning tools; `articles: Article[]` envelope (one-to-many); `x_get_article` / `x_crawl_article` demoted.
- Gates: nothing downstream. End of release.

---

## Critical bugs (from 2026-04-15 code review)

### BUG-1: Router sends X user tweets to wrong skill
**File:** `skills/etl-overview/SKILL.md` line 49
**Problem:** Routing table maps "X user tweets" to `ingest-x-bookmarks (with source=user_tweets param)` instead of `ingest-x-user-tweets`. The dedicated `ingest-x-user-tweets` skill exists and handles user-tweet-specific logic (user resolution via `x_get_user`, pagination, per-user filtering). Routing to `ingest-x-bookmarks` would bypass all of this.
**Fix:** Change the routing entry to point at `ingest-x-user-tweets`.

### BUG-2: Router missing routes for X threads and load-kb-from-sql
**File:** `skills/etl-overview/SKILL.md` lines 48-51
**Problem:** The routing table only maps 4 source types (YouTube playlist, YouTube videos, X bookmarks, X user tweets) and marks local files and crawled pages as "not yet implemented." But `ingest-x-thread` and `load-kb-from-sql` both exist as fully written skills with no route to reach them. The plan specifies 8 skills (1 router + 7 sub-skills); the router only dispatches to 4.
**Fix:** Add routing entries for:
- X thread (tweet URL/ID with thread intent) -> `ingest-x-thread`
- DB-to-KB standalone ("load DB into KB") -> `load-kb-from-sql`
- Local files -> `ingest-local-files` (remove "not yet implemented" — the skill is written)

### BUG-3: Stage-0 questionnaire drops embeddings model question
**File:** `skills/etl-overview/SKILL.md`, `skills/references/preflight-questionnaire.md`
**Problem:** PLAN.md Q6 specifies: "Embeddings model — ask user which embeddings model endpoint to use for the KB records if the default ollama embeddings model is not available." Both `etl-overview` and `preflight-questionnaire.md` implement only 6 questions (target KB, source, DB path, granularity, dedup, confirmation), skipping the embeddings model question entirely.
**Fix:** Insert Q6 (embeddings model) before the confirmation question in both `etl-overview/SKILL.md` and `preflight-questionnaire.md`. Renumber confirmation to Q7.

### BUG-4: `article` (singular) vs `articles: Article[]` (plural) mismatch
**Files:** `skills/ingest-x-bookmarks/SKILL.md`, `skills/ingest-x-user-tweets/SKILL.md`, `skills/ingest-x-thread/SKILL.md`, `skills/references/mcp-tool-contracts.md`
**Problem:** All X ingest skills and the tool contracts doc use `article: {status, url, article_id}` (singular object per tweet). The ROADMAP blocking change and the x-api-mcp spec require `articles: Article[]` (plural array, one-to-many — a tweet can link multiple articles). This is not cosmetic; the response shape determines how the agent iterates article results and constructs dedup checks.
**Fix:** Update `mcp-tool-contracts.md` first to define the `articles: Article[]` envelope shape, then update all 3 X ingest skills to iterate the array.

---

## Consistency issues (from 2026-04-15 code review)

### CON-1: `where` vs `row_selector` metadata field name
**Files:** `skills/ingest-x-user-tweets/SKILL.md`, `skills/ingest-x-thread/SKILL.md` use `metadata.where`; `skills/ingest-youtube-playlist/SKILL.md`, `skills/ingest-youtube-videos/SKILL.md`, `skills/ingest-x-bookmarks/SKILL.md` use `metadata.row_selector`; `skills/references/kb-source-types.md` pins `row_selector` as canonical.
**Fix:** Standardize all skills to use `row_selector`. Update `ingest-x-user-tweets` and `ingest-x-thread`.

### CON-2: `"crawled"` vs `"ok"` article status vocabulary
**File:** `skills/ingest-x-user-tweets/SKILL.md` line 39 uses `article.status == "crawled"` in the Stage-2 verification step. `mcp-tool-contracts.md` defines the vocabulary as `ok | missing | failed`. No other skill uses `"crawled"`.
**Fix:** Replace `"crawled"` with `"ok"` in `ingest-x-user-tweets/SKILL.md`.

### CON-3: Windows hash command in `ingest-local-files`
**File:** `skills/ingest-local-files/SKILL.md` line 49 — primary example uses `sha256sum` (Linux). The project runs on Windows (`W:\` paths). `idempotency-and-dedup.md` correctly references `certutil -hashfile`. The skill should match.
**Fix:** Make the Windows command (`certutil -hashfile <path> SHA256` or `Get-FileHash`) the primary example; move `sha256sum` to a "Linux/macOS" alternative.

---

## Blocking changes (carried from prior roadmap + new items)

- [x] **BUG-1** — Fix X user tweets routing in `etl-overview/SKILL.md`. _(Phase 1, commit 8850282)_
- [x] **BUG-2** — Add missing routes (X thread, load-kb-from-sql, local files) to the routing table. _(Phase 1, commit 8850282)_
- [x] **BUG-3** — Restore embeddings model question (Q6) in `etl-overview/SKILL.md` and `preflight-questionnaire.md`. _(Phase 1, commit 8850282)_
- [x] **BUG-4** — Migrate `article` -> `articles: Article[]` in all X skills + `mcp-tool-contracts.md`. _(Phase 2, commit edff64e)_
- [x] **CON-1** — Standardize `row_selector` across all skills. _(Phase 2, commit edff64e)_
- [x] **CON-2** — Fix `"crawled"` -> `"ok"` status vocabulary. _(Phase 2, commit edff64e)_
- [x] **CON-3** — Fix hash command platform mismatch in `ingest-local-files`. _(Phase 4, commit 67f58be)_
- [x] **Stage-0 preflight contract-probe.** Router probes 3 sibling MCPs before dispatch. _(Phase 3+4, commits de360f6, 67f58be)_
- [x] **Subagent dispatch protocol reference doc.** `skills/references/subagent-dispatch-protocol.md` created; cross-referenced from all 6 delegating skills. _(Phase 3, commit de360f6)_
- [x] **Install-ordering constraint documented in `README.md`.** Numbered install steps with verification commands. _(Phase 7, commit 5b5ab3e)_
- [x] **Stage-0 slash-command wrapper.** `commands/etl-config.md` created; plugin.json updated; etl-overview mentions `/etl-config`. _(Phase 6, commit b6045d2)_
- [x] **Drop "zero tools" framing; use "no MCP tool surface."** Replaced across README.md and plugin.json. _(Phase 7, commits 5b5ab3e, b5bd464)_
- [x] **Reference `docs/safe-where-clause-grammar.md`** in mcp-tool-contracts.md and load-kb-from-sql; 3 canned WHERE patterns; "no free-form filters" warning. _(Phase 5, commit 656b215)_
- [x] **Update `skills/references/mcp-tool-contracts.md`** — articles[] plural, transcript-status table, per-kb_id serialization, dominant_embedding_model. _(Phase 2, commit edff64e)_

## Recommended changes (ship if feasible)

- [ ] Pre-tool-use hook template stub under `scripts/` that blocks `Write` on `*.transcript`, `*.tweet`, `*.article` paths and `Read` on known MCP cache DB filenames.
- [ ] A `skills/references/stage-0-defaults.md` note on how the slash-command reuses the last confirmed plan (YAML file under `.claude/etl-orchestrator/last-plan.yaml`).
- [ ] Verify `AskUserQuestion` actually supports "up to 4 questions per call" as claimed in `preflight-questionnaire.md` line 104. If not, fix the grouping advice.
- [ ] Verify `get_saved_videos` actually supports a `source` parameter for column filtering (used in `ingest-youtube-playlist` Stage 2). If the tool only supports keyword `query`, update the skill to use the correct parameter name.

## Accepted as-is

- 8-skill layout (1 router + 7 ingest/load) under `skills/`.
- 6 reference docs already scaffolded on disk under `skills/references/`.
- Four-stage flow (Clarify -> Fetch -> Verify -> Load).
- `source_type=file` forbidden for MCP cache content; reserved for user-supplied files only.
- Memory-pointer ritual (`memory/kb_<slug>.md` + `MEMORY.md` index + `kb_info` verification).
- 50-row sequential batches for `kb_ingest_batch`.
- Fixed deliverable report format per run.
- Partial-success as a first-class non-failure state.
- No MCP tool surface via `.claude-plugin/plugin.json` with no `mcpServers` block.

---

## Phased work breakdown

### Phase 1 — Critical bug fixes (router + questionnaire)
**Files:** `skills/etl-overview/SKILL.md`, `skills/references/preflight-questionnaire.md`
**Work:**
- Fix BUG-1: correct X user tweets routing entry.
- Fix BUG-2: add X thread, load-kb-from-sql, and local files routes.
- Fix BUG-3: insert embeddings model question as Q6; renumber confirmation to Q7.
**Verification:** routing table has 7 entries (one per sub-skill); questionnaire has 7 questions; no "not yet implemented" markers for skills that exist.

### Phase 2 — Contract alignment (article shape + field names + status vocab)
**Files:** `skills/references/mcp-tool-contracts.md`, `skills/ingest-x-bookmarks/SKILL.md`, `skills/ingest-x-user-tweets/SKILL.md`, `skills/ingest-x-thread/SKILL.md`
**Work:**
- Fix BUG-4: update `mcp-tool-contracts.md` with `articles: Article[]` shape, then update all 3 X ingest skills.
- Fix CON-1: standardize `row_selector` in `ingest-x-user-tweets` and `ingest-x-thread`.
- Fix CON-2: replace `"crawled"` with `"ok"` in `ingest-x-user-tweets`.
- Add transcript-status semantics table, per-kb_id serialization note, `dominant_embedding_model` field to contracts doc.
**Verification:** `rg "\"article\":" skills/` returns zero hits (all plural now); `rg "\"where\":" skills/` returns zero hits (all `row_selector` now); `rg "crawled" skills/` returns zero hits.

### Phase 3 — New reference docs (contract probe + subagent dispatch)
**Files:** NEW `skills/references/contract-probe-protocol.md`, NEW `skills/references/subagent-dispatch-protocol.md`
**Work:**
- Write contract-probe-protocol with the 3 probe calls and expected response shapes.
- Write subagent-dispatch-protocol pinning prompt template, context limits, forbidden inputs, report shape.
- Cross-reference from every SKILL.md that dispatches a subagent.
**Verification:** both files exist; every SKILL.md that mentions "Sonnet subagent" or "Delegate" references `subagent-dispatch-protocol.md`.

### Phase 4 — Router preflight probe + local-files platform fix
**Files:** `skills/etl-overview/SKILL.md`, `skills/ingest-local-files/SKILL.md`
**Work:**
- Add contract-probe step to `etl-overview` between Stage-0 confirmation and sub-skill dispatch.
- Fix CON-3: make Windows hash command primary in `ingest-local-files`.
**Verification:** `etl-overview` text includes a probe block referencing `contract-probe-protocol.md`; `ingest-local-files` primary hash example uses `certutil` or `Get-FileHash`.

### Phase 5 — load-kb-from-sql: canned WHERE patterns only
**Files:** `skills/load-kb-from-sql/SKILL.md`, `skills/references/mcp-tool-contracts.md`
**Work:**
- Replace the generic `<narrowed SQL fragment>` placeholder with exactly 3 canned patterns: by ID list (`video_id IN (...)`), by date range (`saved_at >= '...'`), by author (`author_id = '...'`).
- Add note: "no free-form filters until `docs/safe-where-clause-grammar.md` is linked."
- Reference the safe-grammar doc in `mcp-tool-contracts.md`.
**Verification:** `load-kb-from-sql` shows 3 explicit patterns; no generic SQL fragment placeholders remain.

### Phase 6 — Slash-command wrapper + plugin.json update
**Files:** NEW `commands/etl-config.md`, `.claude-plugin/plugin.json`
**Work:**
- Write `commands/etl-config.md` wrapping the 7-question questionnaire.
- Add command registration to `plugin.json`.
- Mention the slash-command option in `etl-overview/SKILL.md`.
**Verification:** `plugin.json` registers 8 skills + 1 command + 0 tools + 0 mcpServers; `commands/etl-config.md` exists.

### Phase 7 — README + framing cleanup
**Files:** `README.md`, `.claude-plugin/plugin.json`, all `SKILL.md` files
**Work:**
- Replace "zero tools" / "no tools" / "skills-only" framing with "no MCP tool surface" where it describes the plugin's enforcement model.
- Add install-ordering constraint with probe-call verification instructions.
- Cross-link to sibling plugin repos.
**Verification:** `rg -n "zero tools|no tools" .` returns no user-facing hits; README has install-ordering section.

### Phase 8 — Dry-run walkthrough + publish
**Verification:**
- Walkthrough per sub-skill: trigger router -> answer Stage-0 (all 7 questions) -> verify echoed plan -> handoff -> Stage-1 tool call visible in logs.
- Manually run the contract probe against the 3 installed sibling servers; confirm all 3 respond with the new envelope fields.
- Confirm `plugin.json` registers exactly 8 skills + 1 command + 0 tools + 0 mcpServers.
- Publish to `goosefly99-plugins-auto-dev` marketplace.

---

## Cross-plugin dependencies

- **This plugin's changes gate:** nothing downstream.
- **This plugin is gated by:**
  - `agent-knowledgebase` (uri grammar, dedup, batch cap, augmented list responses, embedding-model field in `kb_info`)
  - `youtube-mcp` (`hydrate=true` / `includeTranscript=true` defaults, status envelope, `get_transcript` cache-read demotion)
  - `x-api-mcp` (auto-crawl on 5 tools, `articles: Article[]` envelope, `x_get_article` / `x_crawl_article` demotion)

## Verification commands

No type-checker / linter / test suite applies — skills-only plugin ships Markdown + JSON.

Applicable gates:
```bash
# JSON validity:
python -m json.tool .claude-plugin/plugin.json

# Consistency checks (Phase 2 acceptance):
rg "\"article\":" skills/       # expect 0 hits (all plural)
rg "\"where\":" skills/          # expect 0 hits (all row_selector)
rg "crawled" skills/             # expect 0 hits (all "ok")

# Framing cleanup (Phase 7 acceptance):
rg -n "zero tools|no tools" .   # expect 0 user-facing hits

# Subagent cross-references (Phase 3 acceptance):
rg "subagent-dispatch-protocol" skills/  # expect 1 hit per skill that delegates

# Markdown lint (if markdownlint-cli present):
npx markdownlint "**/*.md"

# Probe (manual, against installed sibling plugins):
# - call kb_info on a scratch KB -> confirm dominant_embedding_model present
# - call get_video_details(videoId='dQw4w9WgXcQ') -> confirm statuses.transcript present
# - call x_get_tweet(id='<public tweet>') -> confirm articles: [] (array, not object)
```

## Out of scope

- No MCP server / no tools / no runtime code in this plugin.
- No auto-generated SKILL.md content — every skill is hand-authored Markdown.
- No pre-tool-use hook implementation in release 1 (only stub template, optional).
- No caching layer for the Stage-0 questionnaire answers beyond the slash-command's last-plan YAML.
- No changes to sibling-plugin source trees — only cross-references.
- No migration of existing `memory/kb_<slug>.md` files — protocol docs explain the format; user maintains.
