# Phase 8 review checklist — payload-byte invariants

Markdown-only harness (Option B) per `phase-8-assertions.md`. Run each command below against the plugin source and each captured dry-run transcript. Zero hits = pass; any hit = fail with defect list.

## Payload-byte definition (normative)

A **payload byte** is any of:

- Transcript text (YouTube subtitle body).
- Tweet full text (including thread tweet bodies; quoted-tweet bodies).
- Article body content (from x-api-mcp article auto-crawl).
- Scraped page text (crawler-mcp output).

**Not** payload (metadata — safe to appear in transcripts):

- IDs: `video_id`, `tweet_id`, `article_id`, `sha256`, `kb_id`, playlist_id.
- Timestamps / ISO date strings.
- URLs (canonical or raw).
- Titles (video titles, article titles, tweet author display names, user
  handles).
- Status tokens: `ok`, `missing`, `failed`.
- Row counts, durations, and integer statistics.

Open-question-3 caveat: URLs like pastebin links may themselves be payload.
v1 accepts this risk. Revisit in v2 if observed.

## Static skill-text checks (S1-S13)

Run each grep against `data-etl-orchestrator/skills/`. **Every row must return zero hits** (excluding the noted exceptions).

Scope note: S1-S13 are checks on *skill body content* (the SKILL.md files and the canonical references they cite). The following reference files are self-documenting harness artifacts and are excluded from S9-S13 counting by convention: `skills/references/bug-closure.md`, `skills/references/phase-8-review-checklist.md` (this file), `skills/references/phase-8-dry-run-report.md`, and `skills/references/phase-8-assertions.md` (defines S13 normatively). They necessarily quote the forbidden patterns to describe them. Use the `--glob` excludes in the shell form below when running the battery mechanically.

| # | Pattern | Expected hits | Exceptions |
|---|---------|---------------|------------|
| S1 | `Read\(.*transcript.*\.(txt\|vtt\|srt)\)` | 0 | none |
| S2 | `Read\(.*\.txt\)` | 0 | none (no skill should Read payload text files) |
| S3 | `Read\(.*\.json\)` | 0 | none (orchestrator does not Read payload JSON) |
| S4 | `Write\(.*summary.*\.md\)` | 0 | none |
| S5 | `Write\(.*transcript.*\)` | 0 | none |
| S6 | `source_type\s*=\s*(?!sql_database)` | 0 | none — only `sql_database` permitted |
| S7 | `article:` (singular, user-facing) | 0 | none (plural `articles:` is required per BUG-4) |
| S8 | `where:` (deprecated row_selector vocabulary) | 0 | none (CON-1 closure) |
| S9 | `\b(crawled\|scraped)\b` (deprecated status vocab) | 0 status-comparison hits | prose adjectives ("auto-crawled articles", "crawled pages" in routing table) are CON-2-closed and allowed; exclude `references/bug-closure.md`, `references/phase-8-review-checklist.md`, `references/phase-8-dry-run-report.md`, and `references/source-db-schemas.md` (schema describes crawler source column) |
| S10 | `sha256sum` (Windows-incompatible CLI) | 0 hits outside a `# Linux/macOS` label | CON-3 permits `sha256sum` inside an explicit `# Linux/macOS` block after Windows (`Get-FileHash`/`certutil`) primary guidance; exclude `references/bug-closure.md` and `references/phase-8-review-checklist.md` |
| S11 | `x-article.*canonical URL` (v0.1.0 spec error SE-2) | 0 | polymorphic id required per C5; exclude `references/phase-8-review-checklist.md` (documents the forbidden pattern) and `references/phase-8-dry-run-report.md` (assertion labels) |
| S12 | Stage-0 echo inlined | the literal Stage-0 echo template appears only in `references/deliverable-format.md` | the phrase "Stage-0 echo" (as an assertion/section label) may appear in `references/phase-8-review-checklist.md` and `references/phase-8-dry-run-report.md`; C3 enforces single source for the *template body* |
| S13 | `\b(crawled\|scraped\|queued\|in_progress)\b` (unified status vocab — broader than S9) | 0 status-comparison hits | ensemble status vocab is `ok\|missing\|failed` (youtube adds `unavailable\|skipped` at tool boundary); `queued`/`in_progress` legacy tokens are forbidden anywhere; prose-adjective carve-outs from S9 apply for `crawled`/`scraped`; exclude `references/bug-closure.md`, `references/phase-8-review-checklist.md`, `references/phase-8-dry-run-report.md`, `references/phase-8-assertions.md`, `references/source-db-schemas.md` (schema column `source='crawl'`), and `references/contract-probe-protocol.md` (Probe 4 assertion (b) quotes the forbidden tokens as examples) |
| SN-legacy-grammar-warning | `until.*safe-where-clause-grammar.*ships` | 0 | self-documenting hits in `references/phase-8-review-checklist.md` (this file defines the pattern) are excluded via `$HX`. Run: `rg 'until.*safe-where-clause-grammar.*ships' skills/ $HX` — expect zero hits |

Shell form (copy-paste for a fresh operator):

```bash
set -e
cd /path/to/data-etl-orchestrator
R=skills/
# Harness-doc excludes: self-documenting files that quote the forbidden patterns.
# S13 additionally excludes phase-8-assertions.md (defines S13 pattern normatively).
HX="-g !skills/references/bug-closure.md -g !skills/references/phase-8-review-checklist.md -g !skills/references/phase-8-dry-run-report.md"
HX13="$HX -g !skills/references/phase-8-assertions.md -g !skills/references/source-db-schemas.md -g !skills/references/contract-probe-protocol.md"

echo "S1" ; ! rg -nq 'Read\(.*transcript.*\.(txt|vtt|srt)\)' $R
echo "S2" ; ! rg -nq 'Read\(.*\.txt\)' $R
echo "S3" ; ! rg -nq 'Read\(.*\.json\)' $R
echo "S4" ; ! rg -nq 'Write\(.*summary.*\.md\)' $R
echo "S5" ; ! rg -nq 'Write\(.*transcript.*\)' $R
echo "S6" ; ! rg -nqP 'source_type\s*=\s*(?!sql_database)' $R  # -P: negative lookahead requires PCRE2
echo "S7" ; ! rg -nq '^\s*article:\s' $R      # YAML-key form only; allows prose "article:" in sentences
echo "S8" ; ! rg -nq '^\s*where:\s' $R        # YAML-key form only
# S9: status-comparison only — not prose adjectives. Exclude harness docs + schema doc.
echo "S9" ; ! rg -nq 'status\s*[:=]\s*["'\'']?(crawled|scraped)\b' $R $HX -g '!skills/references/source-db-schemas.md'
# S10: sha256sum outside a # Linux/macOS label is disallowed. Quick heuristic — exclude harness docs.
echo "S10"; ! rg -nqU 'sha256sum' $R $HX
echo "S11"; ! rg -nq 'x-article.*canonical URL' $R $HX
# S12: the Stage-0 echo *template* appears only in deliverable-format.md. Label-only mentions in harness docs are allowed.
echo "S12"; test "$(rg -c 'Stage-0 echo' $R $HX | grep -v deliverable-format.md | wc -l)" -eq 0
# S13: unified status vocabulary — broader than S9, adds `queued|in_progress`. Status-comparison form;
# prose-adjective carve-outs ("auto-crawled articles") inherited from S9. Exclude harness docs,
# phase-8-assertions.md (defines S13), source-db-schemas.md (legitimate source='crawl' column value),
# and contract-probe-protocol.md (Probe 4 assertion (b) quotes the forbidden tokens as examples).
# S13 shell form narrows the table-row literal pattern to status-comparison contexts
# to avoid prose false positives in skill text. Sibling-repo sweep uses the literal pattern.
echo "S13"; ! rg -nq 'status\s*[:=]\s*["'\'']?(crawled|scraped|queued|in_progress)\b' $R $HX13
# SN-legacy-grammar-warning: the pre-Phase-1 "until ... safe-where-clause-grammar.md ships" gating prose is retired.
# This file necessarily defines the pattern, so exclude via $HX.
echo "SN-legacy-grammar-warning"; ! rg -nq 'until.*safe-where-clause-grammar.*ships' $R $HX
echo "ALL STATIC CHECKS PASS"
```

(On Windows, run under Git Bash or WSL; plain PowerShell does not honor the
`!` negation the same way — use `if (!(rg -nq ...)) { ... }`.)

## Transcript payload-byte checks (T1-T7)

Each dry-run produces a transcript file (e.g.,
`pipeline_mcp_data/scaffolds/phase-8-transcripts/ingest-youtube-videos.txt`).
Run each pattern on every captured transcript. Every row must return zero hits.

Disqualifying content patterns — a positive hit means payload leaked into the agent context.

| # | Pattern | What it catches |
|---|---------|-----------------|
| T1 | `transcript_text\s*[:=]\s*"[^"]{80,}"` | Long transcript string pasted into context. |
| T2 | `\bfull_text\s*[:=]\s*"[^"]{140,}"` | Tweet body copied into context. |
| T3 | `\barticle_body\s*[:=]\s*"[^"]{200,}"` | Article body copied into context. |
| T4 | `\bpage_text\s*[:=]\s*"[^"]{200,}"` | Scraped page body copied into context. |
| T5 | More than 10 consecutive lines without at least one control token (`assistant:`, `tool_use`, `tool_result`, status token, ID) | Wall-of-text paste. Heuristic. |
| T6 | `(paraphrase\|summary).*transcript\|tweet` followed by a >80-char free-text span | Agent summarizing payload it should not have. |
| T7 | Any line longer than 400 chars in the transcript not inside a known metadata JSON | Sentinel for payload leakage. Tune threshold per skill. |

Shell form (copy-paste):

```bash
set -e
T=pipeline_mcp_data/scaffolds/phase-8-transcripts

for f in "$T"/*.txt; do
  echo "=== $f ==="
  ! rg -nqU 'transcript_text\s*[:=]\s*"[^"]{80,}"'   "$f"
  ! rg -nqU 'full_text\s*[:=]\s*"[^"]{140,}"'        "$f"
  ! rg -nqU 'article_body\s*[:=]\s*"[^"]{200,}"'     "$f"
  ! rg -nqU 'page_text\s*[:=]\s*"[^"]{200,}"'        "$f"
  awk 'length($0) > 400' "$f" | grep -v '"id":' \
      | (grep -q . && { echo "T7 violation"; exit 1; } || true)
done
echo "ALL TRANSCRIPT CHECKS PASS"
```

## Per-dry-run assertions (min 3 per sub-skill)

Each sub-skill dry-run must log these three machine-verifiable assertions
into `skills/references/phase-8-dry-run-report.md`:

1. **Static OK:** section 2's S1-S13 all zero hits.
2. **Transcript OK:** section 3's T1-T7 all zero hits on this run's
   transcript.
3. **Format OK:** emitted deliverable contains all 6 sections from
   `deliverable-format.md` (Stage-0 echo, Stage-1 counts, Stage-2 diff,
   Stage-3 counts, partial failures, memory pointers).

Recommended extra assertions (not required but increase evidence):

4. **Dispatch OK:** exactly one sub-skill SKILL.md was loaded.
5. **Dedup OK:** per-item `dedup_result` is one of `new` or `duplicate`.
6. **Envelope OK:** for X sub-skills, every tweet has an `articles: []`
   field (possibly empty) and each entry has status `ok|missing|failed`.
7. **Probe OK:** `references/contract-probe-protocol.md` returns 4/4 GREEN
   on a fresh run (probes 1-3 + probe-4 ensemble).

## PR-time sibling-repo status-vocabulary sweep (Phase 4)

Before merging any orchestrator PR, run the S13 pattern across the 3 sibling
repos as a cross-plugin guard. This catches legacy status tokens that might
leak into sibling code between releases; the orchestrator's own skills/ are
covered by S13 above.

```
[ ] Run rg -n '\b(crawled|scraped|queued|in_progress)\b' against each sibling repo:
    - ../agent_knowledge_base_plugin_dev/src/
    - ../x-api-mcp-dev/ (excluding node_modules)
    - ../youtube-mcp-dev/src/
    Expected: zero hits unless the hit is a DB column value (check source-db-schemas.md for the legitimate exclusions).
```

Shell form (copy-paste):

```bash
rg -n '\b(crawled|scraped|queued|in_progress)\b' ../agent_knowledge_base_plugin_dev/src/
rg -n '\b(crawled|scraped|queued|in_progress)\b' --glob '!node_modules' ../x-api-mcp-dev/
rg -n '\b(crawled|scraped|queued|in_progress)\b' ../youtube-mcp-dev/src/
```

Any non-zero result outside documented DB column values is a PR blocker.
Resolve in the owning sibling repo before merging the orchestrator PR.

## Red-flag disqualifying patterns

Any of these in transcripts is an automatic RED verdict:

- A code fence containing > 50 lines of transcript-looking prose.
- Tool inputs where `content` field > 500 chars that is not ID/URL/title.
- `Read` tool invocations on paths that match `*.txt`, `*.vtt`, `*.srt`,
  `*transcript*`, `*article*`, `*body*`.
- `Write` tool invocations creating `*summary*.md` or `*paraphrase*.md`
  files.
- Any mention of a specific speaker's multi-sentence quote from a video.

## Per-run report template

For each dry-run, append a section to
`skills/references/phase-8-dry-run-report.md`:

```
### <sub-skill name>

- Dry-run id: <yyyymmdd-hhmm>
- Variant: happy | partial-success
- Assertions:
  - [x] Static OK (S1-S13)
  - [x] Transcript OK (T1-T7)
  - [x] Format OK (6 sections)
  - [x] Probe OK (4/4 contract probes GREEN)
- Evidence:
  - transcript: pipeline_mcp_data/scaffolds/phase-8-transcripts/<skill>.txt
  - harness run: <command>
  - harness exit: 0
- Verdict: GREEN
```

Aggregate verdict at the top of the report: `N/8 green`. Anything other
than `8/8` blocks publish.
