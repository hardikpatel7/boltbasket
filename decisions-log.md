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

## 2026-05-03 — Phase 4b complete: full seed generator + verify extended + ~210K rows loaded

**What changed:**

1. New Python package at `supabase/seed/generator/` produces seven bulk SQL files (`02a` → `02g`) totalling **~210,000 rows** across 25 tables. Generator is deterministic (`SEED=42`; per-module sub-seeds via SHA-256 of module name XOR'd with SEED). Re-running `python generate.py` produces byte-identical SQL — enforced by `tests/test_determinism.py`.

2. **Layered approach honored end-to-end.** Smoke seed remains untouched: bulk user_id starts at 6, bulk order_id starts at 4, bulk rider_id starts at 4, bulk product_id starts at 11. The 5 named users, 14 named employees, 3 named riders, 3 demo orders, 10 base products from smoke seed are all preserved. Verify confirms imperfections #1, #2, #2b, #4, #5, #6, #12 still surface correctly on the smoke seed rows.

3. **The 5 new imperfections (Phase 4b's brief) are now exercised** and verified:
   - **#3 (inventory snapshot/log drift):** 5 of 120 (store, product) cells deliberately drift between `store_inventory.quantity_on_hand` and the replay sum of `inventory_movements.quantity_change`. 3 negative, 2 positive, magnitudes ±2..±15. Drifted cells listed in the SQL header comment of `02c_inventory.sql`. Verify reports exactly 5 drifted cells.
   - **#7 (price_list scope overlap):** 15 price_lists across 3 scope types (1 global + 6 city + 8 store). All 10 active products appear in all 3 scope types simultaneously. Verify reports exactly 10 products.
   - **#8 (app_events.properties JSONB chaos):** 30K events with deliberate key-spelling drift (`product_id` 70% / `productId` 20% / `prod_id` 10%), type drift on `cart_value` (~20% rendered as `"₹X.XX"` strings), ~5% missing keys, ~5% stray keys, plus a sprinkling of realistic feature-flag/experiment indexed keys. Verify reports **677 distinct keys** across the corpus (target ~600, range 400-800).
   - **#10 (multi-model ad_attributions):** ~30% of bulk orders (3,000) attributable; 100% get `last_click`, ~10% additionally `view_through`, ~5% additionally `multi_touch_linear` (1-3 rows per order, weights summing to 1.0). Total 3,557 attribution rows. Verify reports 407 orders appearing in ≥2 attribution model rows.
   - **#11 (orphan products):** 50 new product rows added (20 discontinued with `(DISC)` suffix, 20 never-launched plausible BoltBasket SKUs, 10 test data with `TEST-LOREM-NNN` SKUs). All `is_active=FALSE`, never referenced from `store_inventory`, `inventory_movements`, `order_items`, or `price_list_items`. Verify reports exactly 50.

4. **`supabase/verify/imperfections_check.sql` extended** with new check queries for all 5 new imperfections plus updated general row counts to bulk-seeded values (riders 53, users 3505, orders 10003, app_events ~30K, etc.).

5. **Generator package contains 82 pytest tests** covering determinism (parametrized over all 7 modules, byte-identical hash check), per-module cardinalities (±2% tolerance), total row budget (200K-220K), and per-module imperfection signatures. **No tests touch the database** — they operate on generated SQL files only.

6. **Live Supabase load complete.** Drop-and-reload not required: bulk seed loads on top of the smoke-seeded DB additively (using non-overlapping ID ranges and order_codes). Total load time ~5 minutes for ~27 MB of SQL. Verify passes fully green for all 11 imperfections we cover (#1, #2, #2b, #4, #5, #6, #3, #7, #8, #10, #11, #12 — #9 is out-of-scope).

**Why:** Phase 4b was the planned next phase per CLAUDE.md. Articles need realistic enough data that queries return interesting answers; smoke seed alone (~100 rows) was too small for power-law product popularity, multi-day analytics, or any of the activity-volume-dependent imperfections. ~210K rows is a comfortable middle ground — fits the Supabase free tier, query performance starts to matter, and the data is dense enough that articles can do meaningful aggregations without contrivance.

**Spec ↔ DDL reconciliations** (recorded here so future articles know):

- **Spec said "4 price_list scope types" (city + store + time + category).** DDL only supports 3 (`global`, `city`, `store`); time-bounding is via `starts_at`/`ends_at` columns on the price_lists row, not a scope type. Plan and implementation use 3 scope types; "all 4 simultaneously" became "all 3 simultaneously."
- **Spec called the snapshot column `quantity_available`.** DDL column is `quantity_on_hand`. Code uses `quantity_on_hand` throughout.
- **`ad_attributions.attribution_model`** has 4 valid values (`last_click`, `view_through`, `multi_touch_linear`, `multi_touch_position_based`). Plan picks `multi_touch_linear` for the multi-touch case (simpler 1/N weights).
- **`price_list_items` capped at 150**, not 300 as the plan claimed. Math: 15 price_lists × 10 active products with `UNIQUE(price_list_id, product_id)` = 150 max distinct pairs. Total bulk row budget unaffected (~210,690).

**Notable issues caught during code review and fixed before sign-off:**

- `numpy==2.0.0` was bumped to `2.2.2` (pre-Python-3.13 release; Python 3.13 wheels needed).
- `common.sql_value` did not handle `np.int64` (the default return type of `rng.integers()` in numpy 2.x). Added `np.integer`/`np.floating` checks via abstract base classes.
- `common.sql_value` did not escape single quotes inside JSONB-encoded dicts/lists. With Faker en_IN names containing apostrophes (e.g., "Mohan's Market"), this would have produced broken SQL. Now escapes after `json.dumps`.
- `common.sql_value` was rendering ₹ as `₹` because `json.dumps` defaults to `ensure_ascii=True`. Set to `False` so non-ASCII chars survive (critical for Imperfection #8's `"₹245.50"` cart_value string demo).
- `common.sql_value` accepted naive datetimes silently, which would have landed in TIMESTAMPTZ columns as session-local time. Now raises `ValueError`.
- `orders.py` event-trim loop was randomly popping mandatory lifecycle events (placed/confirmed/picked/delivered) — empirically ~6% of orders were losing events. Fix: only trim optional `packed` events. Added regression test `test_every_order_has_mandatory_lifecycle_events`.
- `orders.py` payment amounts were rolled independently of order totals (100% mismatch, avg INR 394 discrepancy). Now `payment.amount = order.total_amount`.
- Refund amounts could exceed payment amounts. Now clamped.

**Affects:** `supabase/seed/generator/*` (new), `supabase/seed/02*.sql` (generated, in repo), `supabase/verify/imperfections_check.sql` (extended), live Supabase database (loaded). All commits between `537ad98` (init) and the current HEAD form the Phase 4b series.

**Operational rule going forward:**
- Generator output (`supabase/seed/02*.sql`) is checked in. Re-running the generator should produce identical bytes; if it doesn't, the determinism test will catch it before commit.
- The full reset flow is: drop schemas → DDL → smoke seed → 02a..02g → marts → verify. Documented in `supabase/seed/generator/README.md`.

**What's next:** Phase 5 (public GitHub README) → Phase 6 (Week 1 Post 1 draft).

---

## How to use this log

When you make a meaningful decision (cast change, scope change, content direction shift), add a dated entry here with:

1. What changed
2. Why
3. What it affects (which files, which articles, which future plans)

This file becomes invaluable around month 4 when you're trying to remember why you made a choice.
