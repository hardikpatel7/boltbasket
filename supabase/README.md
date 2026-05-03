# Phase 4 — Supabase Setup

This folder contains the SQL schema and seed for BoltBasket's reference database, hosted on **Supabase Cloud**.

> **Setup path:** Supabase Cloud is the canonical path for this project. The Docker and one-shot options below remain for reference (e.g. offline iteration), but the source of truth is the Supabase project. All articles, queries, and screenshots reference the Supabase-hosted database.

## What's here

```
supabase/
├── README.md                          ← you are here
├── ddl/                               ← schema definitions, run in order
│   ├── 00_init.sql                    schemas, extensions
│   ├── 01_reference.sql               cities, pincodes, categories, brands
│   ├── 02_catalog.sql                 products, product_attributes
│   ├── 03_users.sql                   users, addresses, subscriptions
│   ├── 04_operations.sql              dark stores, riders, employees
│   ├── 05_inventory.sql               store_inventory, inventory_movements
│   ├── 06_orders.sql                  carts, orders, order_items, events, payments, refunds
│   └── 07_promotions_ads_engagement.sql   promotions, ads, app_events, search
├── seed/
│   └── 01_smoke_seed.sql              small hand-written seed (~100 rows). Loads in <5s.
├── verify/
│   └── imperfections_check.sql        confirms each deliberate imperfection is intact
└── marts/
    └── 01_marts_views.sql             analytical views simulating the BigQuery layer
```

## Prerequisites

- Postgres 15+ (Supabase, local Docker, or any managed Postgres works)
- `psql` client OR the Supabase SQL Editor

## Setup option 1: Supabase Cloud (recommended)

This is what I'd suggest for the real BoltBasket project — sets up cleanly, free tier covers everything.

1. **Create a Supabase project** at supabase.com. Choose a region close to you (Mumbai or Singapore for India).
2. **Open SQL Editor** in the Supabase dashboard.
3. **Run DDL files in order**, copy-pasting each into the SQL Editor and clicking Run:
   ```
   ddl/00_init.sql
   ddl/01_reference.sql
   ddl/02_catalog.sql
   ddl/03_users.sql
   ddl/04_operations.sql
   ddl/05_inventory.sql
   ddl/06_orders.sql
   ddl/07_promotions_ads_engagement.sql
   ```
4. **Run the smoke seed:**
   ```
   seed/01_smoke_seed.sql
   ```
5. **Run verification:**
   ```
   verify/imperfections_check.sql
   ```
6. **Build marts:**
   ```
   marts/01_marts_views.sql
   ```
7. **Try a sample query** in the SQL Editor:
   ```sql
   SELECT * FROM marts.fct_orders;
   SELECT * FROM marts.daily_revenue_comparison;
   ```

If verification queries return the expected counts, you're set.

## Setup option 2: Local Postgres via Docker

Useful if you want offline iteration before pushing to Supabase.

1. **Start Postgres:**
   ```bash
   docker run -d --name boltbasket-pg \
     -e POSTGRES_PASSWORD=boltbasket \
     -e POSTGRES_DB=boltbasket \
     -p 5432:5432 \
     postgres:15
   ```

2. **Load all DDL + seed + marts in one shot:**
   ```bash
   cd supabase/

   # Load DDL in order
   for f in ddl/*.sql; do
     PGPASSWORD=boltbasket psql -h localhost -U postgres -d boltbasket -f "$f"
   done

   # Load smoke seed
   PGPASSWORD=boltbasket psql -h localhost -U postgres -d boltbasket -f seed/01_smoke_seed.sql

   # Load marts
   PGPASSWORD=boltbasket psql -h localhost -U postgres -d boltbasket -f marts/01_marts_views.sql

   # Verify
   PGPASSWORD=boltbasket psql -h localhost -U postgres -d boltbasket -f verify/imperfections_check.sql
   ```

3. **Connect:**
   ```bash
   PGPASSWORD=boltbasket psql -h localhost -U postgres -d boltbasket
   ```

## Setup option 3: One-shot script

If you have psql installed and a connection string handy:

```bash
export PGURL="postgresql://user:pass@host:5432/dbname"

cd supabase/
for f in ddl/*.sql seed/*.sql marts/*.sql verify/*.sql; do
  echo "=== Loading $f ==="
  psql "$PGURL" -f "$f"
done
```

## What the smoke seed gives you

After loading `01_smoke_seed.sql`, you'll have:

- **3 cities, ~23 pincodes, 23 categories, 13 brands**
- **10 products** (real-feeling Indian SKUs: Amul Gold Milk, Britannia Brown Bread, etc.)
- **18 product attributes** including 2 deliberate disagreements with their column counterparts
- **12 dark stores** across the 3 cities
- **~28 service areas** with deliberate pincode-overlap patterns
- **14 employees** — the named characters from the bible (Aryan, Sanya, Vikram, Naveen, Priya, Noel, Devika, Arjun, Meera, Sid, Rohan, Anjali, Faisal, Pooja)
- **5 users, 5 addresses, 1 active Plus subscription**
- **3 sample orders** demonstrating: normal flow, NULL cart_id (deeplink), and NULL rider_id (legacy bad row)

This is enough to run real queries, validate the schema, and write your first 1–2 articles.

The full ~300K-row generator will come in a follow-up build (Phase 4b) — it requires Python with `faker` and `numpy`, and produces realistic Indian quick-commerce activity with proper distributions, seasonality, and full coverage of all imperfections.

## Imperfections preserved in the smoke seed

| # | Imperfection | Visible in smoke seed? |
|---|---|---|
| 1 | Circular FK + stale primary_address_id | Yes — user 5 has NULL primary_address_id but has an address |
| 2 | Column vs product_attributes disagreement | Yes — products 4 (weight) and 7 (origin) |
| 3 | Snapshot/log inventory drift | Comes in Phase 4b |
| 4 | Multiple service_areas per pincode | Yes — 5+ pincodes have multiple stores |
| 5 | Orders with NULL cart_id | Yes — 2 of 3 orders |
| 6 | Orders past picked with NULL rider_id | Yes — order BB-20231215-000003 |
| 7 | Price overrides via price_lists | Comes in Phase 4b |
| 8 | app_events.properties chaos | Comes in Phase 4b |
| 9 | MongoDB blind spot | OUT OF SCOPE for relational seed |
| 10 | Multi-model ad_attributions | Comes in Phase 4b |
| 11 | Orphan products | Comes in Phase 4b |
| 12 | order_items snapshot fields (positive) | Yes — all 4 order_items have full snapshot |

## Sample queries to try

After loading, paste these into your SQL editor to feel the universe:

```sql
-- Find the named characters
SELECT employee_code, full_name, role, department
FROM raw.employees ORDER BY employee_code;

-- See the canonical "two revenues" comparison (basis of Arc 2)
SELECT * FROM marts.daily_revenue_comparison;

-- Pincodes with overlapping store coverage (Imperfection #4)
SELECT pc.pincode, pc.area_name, ARRAY_AGG(ds.store_code) AS stores
FROM raw.pincodes pc
JOIN raw.service_areas sa ON sa.pincode_id = pc.pincode_id
JOIN raw.dark_stores ds ON ds.dark_store_id = sa.dark_store_id
GROUP BY pc.pincode, pc.area_name
HAVING COUNT(*) > 1;

-- Orders with deeplink flow (NULL cart_id — Imperfection #5)
SELECT order_code, user_id, current_status, total_amount
FROM raw.orders WHERE cart_id IS NULL;

-- Product/attribute disagreements (Imperfection #2)
SELECT p.product_name, p.weight_grams AS column_value, pa.attribute_value
FROM raw.products p
JOIN raw.product_attributes pa
  ON pa.product_id = p.product_id AND pa.attribute_key = 'weight_grams'
WHERE p.weight_grams::TEXT <> pa.attribute_value;
```

## Resetting

If you need to start over:

```sql
-- Nuclear option: drops everything in our schemas
DROP SCHEMA IF EXISTS marts CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
```

Then re-run from `ddl/00_init.sql`.

## Troubleshooting

- **"schema raw does not exist"** — you skipped `00_init.sql`. Run it first.
- **Foreign key violations on insert** — load DDL files in numerical order. Don't skip ahead.
- **Duplicate key on re-run** — the smoke seed isn't idempotent. Drop schemas (above) and reload, or just edit the seed to use `ON CONFLICT DO NOTHING` if you want to re-run safely.
- **"function gen_random_uuid() does not exist"** — your Postgres is old. Ensure you ran `00_init.sql` which creates the `pgcrypto` extension. Supabase has it by default.

## What's next

After confirming this loads cleanly:

1. **Confirm in chat** that everything works on your end.
2. **Phase 4b** — I'll build the full `~300K-row` Python seed generator.
3. **Phase 5** — public GitHub README that introduces BoltBasket to the world.
4. **Then** we draft Week 1 Post 1.
