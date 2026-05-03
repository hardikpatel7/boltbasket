# BoltBasket — Decisions Log

A running log of strategic and structural decisions made during this project. Append, don't rewrite.

When future-you (or future-Claude) wonders "why did we choose X?" — the answer should be here.

---

## 2026-05-03 — Bible review pass (Phase 1–3 → Phase 4 transition)

### Decision 1: Multi-cloud (AWS + GCP) instead of AWS-only

**What changed:** BoltBasket now runs on AWS for app/transactional layer and GCP for data/ML/BI layer.

**Why:** Single-cloud was a default-safe choice that wasn't actually deliberate. Multi-cloud is more realistic for Indian Series C companies in 2025, gives us a rich content vein (cross-cloud bridges, egress costs, vendor lock-in tradeoffs), and creates a natural story arc — Vikram's 2021 AWS choice vs. the data team's 2024 GCP migration.

**Affects:** `bible/stack.md` rewritten. `bible/company.md` cultural texture line updated. The deliberately-messy list now has cross-cloud bridge as imperfection #1.

### Decision 2: BigQuery as primary warehouse, Snowflake deprecated-but-not-gone

**What changed:** Moved away from "Snowflake is the warehouse." Now: BigQuery primary on GCP, ~30% of analytical workloads still on a being-retired Snowflake instance. Migration ongoing for ~14 months and counting.

**Why:** BigQuery pairs cleanly with GCP-side ML (Vertex AI) and the broader data-team-on-GCP narrative. The half-finished Snowflake → BigQuery migration adds another rich story arc. BigQuery cost-management content is also less saturated than Snowflake content right now.

**Affects:** `bible/stack.md`. Articles can mine: cost optimization, migration debt, dual-warehouse drift, dbt multi-target setups.

### Decision 3: ~300K-row Supabase, not ~190K

**What changed:** Supabase seed scaled up from ~190K rows (1 day of activity) to ~300K rows (~3 days of activity, slightly larger user base).

**Why:** Author wants more rows to play with. 300K is the comfortable middle ground — fits free tier, query performance starts to matter (good for content), scales realistically across 3 cities.

**Affects:** Phase 4 seed scripts. `schema/entities.md` cardinality section updated.

### Decision 4: Character renames

**What changed:**
- Vikram Iyer → Vikram Bansal (CTO)
- Karthik Subramanian → Noel Thomas (EM, Data Platform)
- Anjali Bhatt (Sr PM, CX) → Tanvi Patel (Sr PM, CX) — same role, new name
- Tanvi Reddy (PM, Supply & Inventory) → Anjali Singh (PM, Supply & Inventory) — same role, new name

**Note on personality assignment:** The original bible's personalities were tied to *roles*, not names. So when "Anjali" moved from CX to Supply & Inventory, the confrontational/CEO-ear/metrics-disagreement traits stayed with the *CX role* (now Tanvi Patel). The bridge-between-offices traits stayed with the *Supply & Inventory role* (now Anjali Singh). All cross-references in story-arcs and other bible files updated accordingly.

**Affects:** `bible/characters.md` rewritten. References updated in `bible/company.md`, `bible/story-arcs.md`, `bible/timeline.md`, `README.md`.

---

## 2026-05-03 — Late edit: Tanvi Patel → Siddharth (Sid) Patel

**What changed:** Sr PM, CX role gender-swapped. Same role, same personality, new name.

- Tanvi Patel (f) → Siddharth "Sid" Patel (m)
- Personality and traits unchanged (sharp, opinionated, confrontational with Noel, has Aryan's ear)
- "Sid" is the informal name used in Slack and casual contexts; "Siddharth" for formal references

**Why:** Author preference. Adjusts cast gender ratio from 8F/8M to 7F/9M (excluding customers), which is closer to industry-realistic for senior PM roles in Indian tech without being stark.

**Affects:** `bible/characters.md`, `bible/company.md`, `bible/story-arcs.md`. All other files unaffected.

---

## 2026-05-03 — Phase 4 complete; Supabase Cloud chosen as canonical DB

**What changed:** Phase 4 (DDL + smoke seed + marts views + verify queries) shipped. Author chose Supabase Cloud over local Docker Postgres as the canonical database path for the project.

**Why:**
- Supabase Cloud means the data is hosted and queryable from anywhere — no need to keep a local Postgres running for article writing or screenshots.
- Free tier covers everything this project needs (well under storage and connection limits).
- Author is moving to Claude Code for the next phase (Phase 4b — full seed generator); Supabase URL + service key in `.env` lets Claude Code generate, validate, and load seed SQL in one workflow.
- The Docker and one-shot install options are retained in `supabase/README.md` as fallbacks but explicitly de-emphasized.

**Affects:** `CLAUDE.md` updated to reflect Phase 4 done and Supabase as canonical. `supabase/README.md` updated with a banner noting Supabase Cloud is the primary path.

**Operational rule going forward:** No credentials in committed files. Supabase URL and keys live in the author's local `.env` only.

---

## 2026-05-03 — Phase 4 first-run fixes: riders seed + product_attributes count

**What changed:**

1. Smoke seed (`supabase/seed/01_smoke_seed.sql`): added a 3-rider INSERT block (`BB-RDR-00001` / `00002` / `00003`, one per city — BLR/BOM/PNQ) and set `rider_id` on the two non-legacy orders (`BB-20251012-000001` → rider 1; `BB-20251013-000002` → rider 2). The 2023 order (`BB-20231215-000003`) stays NULL to keep demonstrating Imperfection #6.
2. `supabase/verify/imperfections_check.sql` and `supabase/README.md` expected count for `product_attributes` corrected from 17 → 18 (the seed already had 18 rows; docs were stale).
3. Live Supabase database patched in-place via `INSERT INTO raw.riders` + `UPDATE raw.orders` so data matches the corrected seed without a full reload.

**Why:** First end-to-end execution of the Phase 4 SQL against Supabase Cloud surfaced two issues. (a) The smoke seed never inserted any riders, so all three orders ended up with NULL `rider_id` — over-stating Imperfection #6, which is supposed to be visible on exactly one legacy 2023 row, not all three. This is a real seed bug that would have over-trained articles to expect blanket NULL riders rather than a single legacy edge case. (b) The product_attributes count claim of "17" in README and verify never matched what the INSERT block actually produced (18). Data was right; doc was stale.

**Affects:** `supabase/seed/01_smoke_seed.sql`, `supabase/verify/imperfections_check.sql`, `supabase/README.md`. Phase 4b's full seed generator should populate riders properly so this isn't a recurring issue.

**Known related stale-doc item (not fixed in this pass):** README line "**3 cities, ~23 pincodes, 23 categories, 13 brands**" — actual category count is 27. Flagged for a separate decision rather than bundled into this fix.

---

## How to use this log

When you make a meaningful decision (cast change, scope change, content direction shift), add a dated entry here with:

1. What changed
2. Why
3. What it affects (which files, which articles, which future plans)

This file becomes invaluable around month 4 when you're trying to remember why you made a choice.
