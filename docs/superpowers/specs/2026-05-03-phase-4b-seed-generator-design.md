# Phase 4b — Full Seed Generator Design

**Date:** 2026-05-03
**Status:** Design approved by author; ready for implementation plan
**Phase reference:** CLAUDE.md → "Phase 4b (Full ~200K-row Python seed generator)"

## Context

The smoke seed (`supabase/seed/01_smoke_seed.sql`) provides ~100 hand-crafted rows that exercise imperfections #1, #2, #4, #5, #6, #12 and seed the named characters from the bible. Phase 4b builds the deterministic Python generator that produces ~200–220K bulk rows on top of the smoke seed, fully exercising the remaining five imperfections (#3, #7, #8, #10, #11) and giving every article in the project a realistic Indian-quick-commerce dataset to query against.

**Activity window:** 2025-10-09 → 2025-10-15 (7 inclusive days, anchor = last day).

**Approach decision:** Layered. Smoke seed loads first; bulk seed adds on top without disturbing the named characters or the three demo orders. (Decision rationale recorded in conversation; user picked option A from Q1.)

## 1. Architecture & Layout

```
supabase/seed/
├── 01_smoke_seed.sql              (existing — unchanged)
├── 02a_operational_baseline.sql   (riders, ad_campaigns, ad_placements,
│                                   promotions, price_lists, price_list_items
│                                   ← owns Imperfection #7)
├── 02b_users.sql                  (bulk users + addresses)
├── 02c_inventory.sql              (store_inventory + inventory_movements
│                                   ← owns Imperfection #3 snapshot/log drift)
├── 02d_orders.sql                 (carts, orders, order_items, order_events,
│                                   payments, refunds — the transactional core)
├── 02e_engagement.sql             (app_events ← owns Imperfection #8 properties chaos,
│                                   search_queries, push_notifications, pipeline_runs)
├── 02f_advertising.sql            (ad_impressions, ad_clicks, ad_attributions
│                                   ← owns Imperfection #10 multi-model attribution)
├── 02g_orphans.sql                (50 orphan products with no inventory/orders/prices
│                                   ← owns Imperfection #11)
└── generator/
    ├── README.md                  (how to run + how to regenerate)
    ├── requirements.txt           (faker, numpy, pendulum)
    ├── generate.py                (entry point — `python generate.py` writes all 02*.sql)
    ├── config.py                  (SEED=42, ANCHOR_DATE=2025-10-15, cardinality dict)
    ├── common.py                  (faker init, SQL escape, timestamp helpers, file writer)
    ├── operational.py             (writes 02a)
    ├── users.py                   (writes 02b)
    ├── inventory.py               (writes 02c — owns #3)
    ├── orders.py                  (writes 02d)
    ├── engagement.py              (writes 02e — owns #8)
    ├── advertising.py             (writes 02f — owns #10)
    ├── orphans.py                 (writes 02g — owns #11)
    └── tests/
        ├── test_determinism.py    (seed=42 produces byte-identical SQL output)
        ├── test_cardinalities.py  (row counts within expected bounds)
        └── test_imperfections.py  (#3/#7/#8/#10/#11 present in expected ways)
```

**Run flow** (two commands):
```sh
cd supabase/seed/generator && python generate.py             # writes all 02*.sql files
for f in supabase/seed/02*.sql; do                            # loads in alphabetical order
  psql "$SUPABASE_DB_URL" -f "$f"
done
```

**Imperfection ownership.** Each imperfection lives in exactly one module: operational owns #7, inventory owns #3, engagement owns #8, advertising owns #10, orphans owns #11. Makes reasoning + testing local.

**Why a Python package, not a single script.** ~200–220K rows of generation logic is too much for one file. Splitting per output file keeps each module focused on one phase + one imperfection and each file under ~300 lines of Python.

## 2. Cardinality Plan

Targeting ~210K total rows (mid of 200–220K range).

| Output file | Table | Bulk rows | File subtotal |
|---|---|---:|---:|
| 02a operational | riders | 50 | |
| | ad_campaigns | 20 | |
| | ad_placements | 60 | |
| | promotions | 25 | |
| | price_lists | 15 | |
| | price_list_items | 300 | **~470** |
| 02b users | users | 3,500 | |
| | addresses | 4,500 | **8,000** |
| 02c inventory | store_inventory | 120 | |
| | inventory_movements | 25,000 | **~25,120** |
| 02d orders | carts | 13,000 | |
| | orders | 10,000 | |
| | order_items | 30,000 | |
| | order_events | 40,000 | |
| | payments | 10,000 | |
| | refunds | 500 | **103,500** |
| 02e engagement | app_events | 30,000 | |
| | search_queries | 10,000 | |
| | push_notifications | 8,000 | |
| | pipeline_runs | 200 | **48,200** |
| 02f advertising | ad_impressions | 20,000 | |
| | ad_clicks | 2,000 | |
| | ad_attributions | 3,500 | **25,500** |
| 02g orphans | products (orphans) | 50 | **50** |
| | | **TOTAL** | **~210,840** |

**Distribution rationale:**
- **Users**: 3,500 active in 7 days; ~2.85 orders/user avg (mix of one-time and repeat power users).
- **Orders**: 10K over 7 days = ~120/day/store across 12 stores. Sample-scale for an Indian Series C; not real-prod-scale, but plausible.
- **Order_items**: 3 items/order avg (typical Indian household top-up basket).
- **Order_events**: 4 events/order avg (placed → confirmed → picked → delivered, some adding `packed`).
- **Carts**: 13K vs 10K orders = ~23% abandonment (realistic for quick-commerce; lower than e-commerce overall).
- **Inventory_movements**: 25K = ~3 movements per (store, product, day) — mix of receipts + sales decrements + adjustments.
- **Ad CTR**: 10% (impressions → clicks), realistic for in-app placements with intent.
- **Ad attributions**: 3,500 from multi-model split (#10) = ~1.5 attributions per converted order on average.
- **Refunds**: 5% of orders (plausible for quick-commerce damage/wrong-item).

**City split** (consistent with smoke seed and the bible): Bengaluru ~50%, Mumbai ~35%, Pune ~15%.

**Hourly distribution:** activity skews to **lunch (12–14)** and **dinner (19–22)** peaks (~40% of orders), plus a morning bump (8–10) for milk/bread/essentials.

## 3. Imperfection Mechanics

The five imperfections we are building this phase, each owned by exactly one module:

### #3 — Inventory snapshot/log drift *(owned by `inventory.py` → `02c`)*

For each (store, product) cell (~120 total), generate movements across 7 days — receipts (incoming), sales decrements (linked logically to order_items via timestamp + store + product), and occasional adjustments. Replay the log to compute the *correct* final snapshot quantity, then write that to `store_inventory` for **115 of 120 cells**. For the remaining **5 cells (~4%)**, deliberately drift the snapshot by ±2 to ±15 units — simulating the documented Diwali-outage failure mode where snapshot updates failed silently while movements committed.

- **3 cells negative** (snapshot < reality)
- **2 cells positive** (snapshot > reality)

The SQL header comment in `02c` lists exactly which (store, product) cells were drifted, so any reader can audit. The `verify` query for #3 should return exactly 5.

### #7 — Price override hierarchy *(owned by `operational.py` → `02a`)*

15 `price_lists` rows with deliberately overlapping scopes:
- **3 city-wide** ("BLR festive pricing", "BOM Diwali week", "PNQ launch promo")
- **5 store-specific** (e.g., `BLR-WHF-01` charges 5–10% premium because Whitefield)
- **4 time-bound** (active 2–3 days within the activity window)
- **3 category-wide** ("10% off dairy", "5% off snacks", etc.)

~300 `price_list_items` distributed across them. **~10 products** will have overlapping scopes simultaneously (city + store + time + category all apply). The "most specific wins" rule is **not encoded** in the DB — that is the imperfection. App code is supposed to know.

### #8 — `app_events.properties` JSONB chaos *(owned by `engagement.py` → `02e`)*

12 event types: `app_open`, `screen_view`, `search`, `product_view`, `add_to_cart`, `remove_from_cart`, `checkout_started`, `order_placed`, `push_received`, `push_clicked`, `app_background`, `app_close`.

Deliberate variations across 30K events:
- **Key spelling drift:** `product_id` (70%) / `productId` (20%) / `prod_id` (10%) — same conceptual field, three keys
- **Type drift:** `cart_value` is sometimes a number, sometimes a string with `"₹"` prefix (e.g. `"₹245.50"`)
- **Missing keys:** ~5% of events drop a key the schema-by-convention "expects"
- **Stray keys:** ~5% of events have extras (`debug`, `_test`, `_internal`)

Target ~600 distinct keys across the corpus (matching the canonical figure in `schema/imperfections.md`).

### #10 — Multi-model ad_attributions *(owned by `advertising.py` → `02f`)*

Of the 10K orders, **~30% (~3,000)** are "ad-attributable" (touched ≥1 impression + click in the window). Per attributable order:
- **100%** → 1 `last_click` row → ~3,000 rows
- **~10%** → 1 additional `view_through` row → ~300 rows
- **~5%** → 1–3 additional `multi_touch` rows with `attribution_weight` summing to 1.0 → ~225 rows

Total ~3,500 attributions across 3 models. Same `order_id` appears in multiple rows for ~15% of attributable orders. This is the data shape that makes "how many orders did this campaign drive?" have three correct answers — Pooja's team's whole problem in the bible.

### #11 — Orphan products *(owned by `orphans.py` → `02g`)*

50 new product rows added to `raw.products` (extending the 10 in smoke seed):
- **20 "discontinued"** (status = `inactive`, names like "Britannia Marie Gold 200g (DISC)")
- **20 "never launched"** (status = `inactive`, plausible-but-fictional SKUs)
- **10 "test data"** (SKUs like `TEST-LOREM-001`, names like `TEST PRODUCT — DO NOT USE`)

**None** appear in `store_inventory`, `inventory_movements`, `order_items`, or `price_list_items`. They exist purely in the catalog table. Verify query: products with no inventory/orders/price coverage should return exactly 50.

### Note on the existing 6 imperfections

Smoke seed already exercises #1, #2, #4, #5, #6, #12 with hand-crafted rows. Bulk seed layers on top **without disturbing** them:
- Bulk users start at `user_id = 6` (smoke holds 1–5)
- Bulk orders use `BB-2025101[3-5]-XXXXXX` codes, avoiding the smoke seed's three order codes
- Bulk address rows do not touch user 5's NULL `primary_address_id`
- Bulk product_attributes do not touch the disagreements on products 4 and 7

After bulk load, all 11 imperfections (#9 is out of scope for relational data — it lives in MongoDB conceptually) should be present and verifiable.

## 4. Determinism, Validation, Re-run

### Determinism

- `config.py` defines `SEED = 42` and `ANCHOR_DATE = date(2025, 10, 15)` as the single sources of truth.
- Each module derives a stable sub-seed from its name:
  ```python
  module_seed = int.from_bytes(hashlib.sha256(b"users").digest()[:8], "big") ^ SEED
  ```
  This isolates RNG state per module — regenerating just `users.py` does not shift any other module's output.
- `Faker(locale='en_IN')` for realistic Indian names/phones/addresses, seeded with the module's sub-seed.
- `numpy.random.default_rng(module_seed)` for distributions: Zipfian product popularity, beta for hour-of-day, lognormal for cart values, etc.
- Tests assert: SHA-256 of each generated SQL file is byte-identical across runs.

### Validation — extend `supabase/verify/imperfections_check.sql`

| Imperfection | New verify query expectation |
|---|---|
| #3 | cells where (replay_quantity − store_inventory.quantity_available) ≠ 0 → **5** |
| #7 | products covered by all 4 scope types simultaneously (city AND store AND time AND category) → **~10** |
| #8 | distinct keys aggregated via `jsonb_object_keys` over `app_events.properties` → **~600** |
| #10 | orders appearing in ≥2 attribution model rows → **~450** (~15% of attributable) |
| #11 | products with no rows in `store_inventory` AND no rows in `inventory_movements` AND no rows in `order_items` AND no rows in `price_list_items` → **50** |

The "general row counts" section gets updated to reflect bulk-seeded ranges:
- `users` 5 → 3,505
- `orders` 3 → 10,003
- `order_items` 4 → 30,004
- `app_events` 0 → 30,000
- `inventory_movements` 0 → 25,000
- ...etc.

After Phase 4b, `verify/imperfections_check.sql` becomes the single source of truth for "what does a correctly-loaded BoltBasket look like."

### Re-run / iteration story

- Generator output is deterministic → re-running `python generate.py` produces byte-identical SQL.
- **Loading is NOT idempotent.** To redo the bulk seed cleanly:
  1. Drop schemas (`DROP SCHEMA marts CASCADE; DROP SCHEMA staging CASCADE; DROP SCHEMA raw CASCADE;`)
  2. Re-run DDL (`for f in supabase/ddl/*.sql; do psql -f "$f"; done`)
  3. Run smoke seed (`psql -f supabase/seed/01_smoke_seed.sql`)
  4. Run bulk seed (`for f in supabase/seed/02*.sql; do psql -f "$f"; done`)
  5. Run marts (`psql -f supabase/marts/01_marts_views.sql`)
  6. Run verify (`psql -f supabase/verify/imperfections_check.sql`)

  Total ~5 minutes.
- `generator/README.md` documents this clearly.
- **No partial-reload tooling.** Phase 4b is a one-time generator; full reset is the only supported re-load path.

### Loading order

Alphabetical (02a → 02g) is FK-safe by construction. If during implementation a FK constraint forces a re-ordering (e.g., `inventory_movements.order_item_id` referencing items from `02d`), the offender splits into two phases (e.g., `02c_inventory_snapshots.sql` before orders, `02h_inventory_movements.sql` after). The DDL files do not pre-declare such cross-bulk FKs, so this should be clean — but we will know when we run it.

### Tests in `generator/tests/`

- `test_determinism.py` — SHA-256 of each generated SQL file matches a checked-in golden hash dict.
- `test_cardinalities.py` — row counts within ±2% of expected per file (allows for Poisson-style noise in distributions).
- `test_imperfections.py` — each imperfection's signature pattern is present in the output SQL via grep/string match (e.g., #3: 5 SQL comment lines naming the drifted cells; #11: 50 INSERTs into raw.products with status='inactive').

All tests run via `pytest`; **no DB connection required**. Tests operate on the generated SQL files only. CI-friendly.

## 5. Open Implementation Choices (deferred to writing-plans)

1. **INSERT vs COPY format.** Default is multi-row `INSERT INTO ... VALUES (...), (...), ...` (~500 rows per statement) for readability and grep-ability. Switch to `COPY FROM STDIN` only if load time becomes an issue (unlikely at ~210K rows; psql ingests 50MB INSERT files in seconds).
2. **Inventory_movements FK to order_items.** Need to confirm in `supabase/ddl/05_inventory.sql` whether `order_item_id` is a declared FK. If yes, split inventory into snapshots (before orders) and movements (after orders). If no, alphabetical order works as-is.
3. **Faker locale.** Plan is `en_IN` for names/phones. Some Faker `en_IN` providers may not produce sufficiently varied output; may need to mix with custom name lists drawn from realistic Indian quick-commerce reality (e.g., delivery rider names, customer first-name pools).
4. **Price plausibility.** Bulk-generated `unit_price_snapshot` values on order_items must respect the products' base_prices and the price_list overrides for the order's city/store/time. Implementation needs a small "effective price calculator" helper to keep the data internally consistent (otherwise reports will look weird).

These are flagged for the implementation plan to resolve.

## 6. Out of Scope for Phase 4b

- **Imperfection #9** (MongoDB blind spot) — by definition not in the relational schema.
- **Catalog expansion beyond 10 active products + 50 orphans.** The 10 active products from smoke seed are sufficient for bulk activity; a Zipfian popularity distribution gives narrative texture without needing more SKUs. (Future enhancement if articles need it.)
- **Realistic geospatial detail beyond city + pincode.** Lat/long fields on dark_stores and addresses can be NULL for now. Phase 5+ if needed.
- **Marts re-population timing.** Marts views are recreated by `marts/01_marts_views.sql` after the bulk load — no special handling.

## 7. Definition of Done

Phase 4b is done when:
1. `python generate.py` produces all `supabase/seed/02*.sql` files from a clean working tree (no errors, no warnings).
2. Loading DDL → smoke → bulk → marts → verify completes without errors against a clean Supabase instance.
3. The extended `verify/imperfections_check.sql` reports all 11 imperfections (1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12) at expected counts/values; #9 is documented as out-of-scope.
4. `pytest` passes in `generator/tests/` (determinism + cardinalities + imperfection presence).
5. `generator/README.md` documents the run flow + reset flow.
6. A new `decisions-log.md` entry records: row count target (200–220K), file structure (02a–02g), and any deviations encountered during implementation.

## 8. After This

- Implementation plan via `superpowers:writing-plans` skill.
- Implementation work follows the plan.
- After bulk load and verify pass: Phase 5 (public GitHub README) → Phase 6 (Week 1 Post 1 draft).
