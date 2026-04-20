# Bug Closure Verification Report

**Generated:** 2026-04-17  
**Branch:** roadmap-implementation  
**Verifier:** C2 — Bug Catalog Verification Pass

---

## Evidence Table

| id | description | commit | file | line | grep snippet |
|---|---|---|---|---|---|
| BUG-1 | X user tweets routing fixed — routes to `ingest-x-user-tweets` (not `ingest-x-bookmarks`) | 8850282 | `skills/etl-overview/SKILL.md` | 62 | `\| X user tweets \| ingest-x-user-tweets \|` |
| BUG-2 | Routing table has all 7 sub-skill entries (X thread, load-kb-from-sql, ingest-local-files added) | 8850282 | `skills/etl-overview/SKILL.md` | 57–66 | 7 routable rows in routing table (+ 1 unimplemented placeholder for crawled pages) |
| BUG-3 | Q6 (embeddings model) present in preflight questionnaire with schema and default | 8850282 | `skills/references/preflight-questionnaire.md` | 86–92 | `## Question 6: Embeddings model` |
| BUG-4 | No singular `article:` field in skills — all X skills use `articles:` plural | edff64e | `skills/` (all X ingest skills) | — | `rg "\barticle:" skills/` → zero hits |
| BUG-5 | Envelope-shape drift mitigated — Probe 4 assertion (a) runtime-parses `articleIngestService` envelope against `tweetArticlesEnvelopeSchema` zod schema; Map-valued responses fail the probe before dispatch | Phase 4 | `skills/references/contract-probe-protocol.md` | Probe 4 (a) | Probe-4 section in `contract-probe-protocol.md`; schema hosted in `references/mcp-tool-contracts.md` |
| BUG-6 | Silent-DB-failure blind spot mitigated — Probe 4 assertion (d) issues a known-bad idempotent write and asserts a SCREAMING_SNAKE_CASE `error_code` on stderr within 100 ms; missing or delayed stderr halts the router before sub-skill dispatch | Phase 4 | `skills/references/contract-probe-protocol.md` | Probe 4 (d) | Probe-4 canary: duplicate-`tweet_id` upsert → expect `TWEET_UPSERT_CONFLICT`-shaped `error_code` within 100 ms |
| CON-1 | No `where:` metadata field in any skill — all use `row_selector` | edff64e | `skills/` (all ingest skills) | — | `rg "\bwhere:" skills/` → zero hits |
| CON-2 | No `"crawled"` status value in skills — article status vocabulary uses `ok / missing / failed` | edff64e | `skills/ingest-x-user-tweets/SKILL.md` | — | `rg -i "\b(crawled\|scraped)\b" skills/` — only prose "crawled" / "auto-crawled" hits; zero `status == "crawled"` comparisons |
| CON-3 | Windows hash commands (`Get-FileHash`, `certutil`) are primary; `sha256sum` is Linux/macOS alternative | 67f58be | `skills/ingest-local-files/SKILL.md` | 49–57 | `# Windows (PowerShell)` block is first; `sha256sum` appears only under `# Linux/macOS` label |

---

## Verification commands run

```bash
# BUG-4: no singular article:
rg -n "\barticle:" skills/   # → zero hits

# BUG-5: envelope-shape drift — probe-4 (a) defined
rg -n "tweetArticlesEnvelopeSchema|Probe 4" skills/references/contract-probe-protocol.md
# → at least one hit in the Probe 4 section; schema reference crosses to mcp-tool-contracts.md

# BUG-6: silent-DB-failure canary — probe-4 (d) defined with 100 ms stderr deadline
rg -n "TWEET_UPSERT_CONFLICT|100 ms|SCREAMING_SNAKE_CASE" skills/references/contract-probe-protocol.md
# → hits in the Probe 4 (d) assertion describe the canary and deadline

# CON-1: no bare where:
rg -n "\bwhere:" skills/   # → zero hits

# CON-2: no crawled/scraped status comparisons
rg -in '\b(crawled|scraped)\b' skills/   # prose-only hits; no status == "crawled" expressions

# CON-3: sha256sum exists only as Linux/macOS alternative
rg -n "sha256sum" skills/   # one hit: ingest-local-files/SKILL.md:57, under "# Linux/macOS" label
```

---

## Notes

- **Live smoke-test skipped** — fresh session simulation is not available in a subagent context. This step was out of scope per C2 brief instructions.
- CON-2 grep for `\b(crawled|scraped)\b` returns prose hits (e.g. "auto-crawled articles", "Crawled pages" in routing table). None are status comparisons. The original bug (`article.status == "crawled"`) has been fully removed.
- CON-3: `sha256sum` appears once at line 57 of `ingest-local-files/SKILL.md`, correctly placed as the third platform option under a `# Linux/macOS` comment, after Windows PowerShell and Windows cmd blocks.
- BUG-5 and BUG-6 are closed by Phase 4's ensemble contract-probe (Probe 4). Closure is protocol-based rather than code-based: the mitigation is the probe's runtime assertion, which halts dispatch before sub-skill invocation when the envelope drifts (BUG-5) or stderr is silent on a deliberate PK violation (BUG-6). Residual runtime risk is tracked by re-running the probe on each new session; evidence lives in `phase-8-dry-run-report.md` (Probe OK line).

---

## Verdict

**GREEN — all 9 items verified** (BUG-1..BUG-6 + CON-1..CON-3)
