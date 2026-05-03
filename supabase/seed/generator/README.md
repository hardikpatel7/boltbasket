# Phase 4b — Full Seed Generator

Deterministic Python generator that writes ~210K rows of bulk BoltBasket activity into seven SQL files (`02a_*` through `02g_*`) in `supabase/seed/`. The smoke seed (`01_smoke_seed.sql`) loads first; this layer adds on top without disturbing the smoke seed's named characters or demo orders.

## Run

```bash
cd supabase/seed/generator
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=.. python generate.py                # writes all 02*.sql
PYTHONPATH=.. python generate.py --module users # writes just 02b_users.sql
```

After generation, load into Supabase via `psql`:

```bash
cd ../../..  # back to project root
for f in supabase/seed/02*.sql; do
  psql "$SUPABASE_DB_URL" -f "$f"
done
psql "$SUPABASE_DB_URL" -f supabase/marts/01_marts_views.sql  # rebuild marts
psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql
```

## Iteration / re-run

The bulk seed is **NOT idempotent** — each load assumes empty tables (other than smoke seed rows). To re-run cleanly:

```bash
psql "$SUPABASE_DB_URL" -c "DROP SCHEMA marts CASCADE; DROP SCHEMA staging CASCADE; DROP SCHEMA raw CASCADE;"
for f in supabase/ddl/*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
psql "$SUPABASE_DB_URL" -f supabase/seed/01_smoke_seed.sql
for f in supabase/seed/02*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
psql "$SUPABASE_DB_URL" -f supabase/marts/01_marts_views.sql
psql "$SUPABASE_DB_URL" -f supabase/verify/imperfections_check.sql
```

Total time: ~5 minutes.

## Imperfection ownership

| File | Module | Owns |
|---|---|---|
| `02a_operational_baseline.sql` | `operational.py` | #7 (price_list scope overlap) |
| `02b_users.sql` | `users.py` | none |
| `02c_inventory.sql` | `inventory.py` | #3 (snapshot/log drift) |
| `02d_orders.sql` | `orders.py` | none |
| `02e_engagement.sql` | `engagement.py` | #8 (JSONB key chaos) |
| `02f_advertising.sql` | `advertising.py` | #10 (multi-model attribution) |
| `02g_orphans.sql` | `orphans.py` | #11 (orphan products) |

#1, #2, #4, #5, #6, #12 are demonstrated by the smoke seed. #9 is out-of-scope (lives in MongoDB conceptually).

## Determinism

`config.SEED = 42` is the single source of truth. Each module derives a stable sub-seed from its name (`config.sub_seed("users")` etc.), so regenerating one module does not shift any other module's output. Re-running `python generate.py` produces byte-identical SQL — `tests/test_determinism.py` enforces this via SHA-256 hash comparison across two runs of every module.

## Tests

```bash
PYTHONPATH=.. pytest                              # all tests (~80, ~3 min)
PYTHONPATH=.. pytest tests/test_determinism.py    # determinism only
PYTHONPATH=.. pytest tests/test_cardinalities.py  # row count budget
PYTHONPATH=.. pytest tests/test_inventory.py      # imperfection #3 mechanic
```

No tests touch the database. They operate on generated SQL files only.

## Module dependency graph

The 7 output files load in alphabetical order (`02a` → `02g`), which is FK-safe by construction:

```
02a operational  →  riders, ad_campaigns, ad_placements, promotions, price_lists, price_list_items
02b users        →  users (id 6+), addresses (id 6+)
02c inventory    →  store_inventory, inventory_movements (movement.reference_id is soft FK to order_items)
02d orders       →  carts, orders, order_items, order_events, payments, refunds — references riders/users/addresses
02e engagement   →  app_events, search_queries, push_notifications, pipeline_runs — references users
02f advertising  →  ad_impressions, ad_clicks, ad_attributions — references campaigns/placements (02a) + orders (02d)
02g orphans      →  50 orphan products (no inbound or outbound references)
```

## Known limitations

- **Attribution timestamps in `02f`** are sampled independently from the activity window; some `attributed_at` values may precede their order's `placed_at`. Article queries should not rely on temporal ordering between `ad_attributions` and `orders`.
- **Price overrides** in `02a` are not applied to `order_items.unit_price_snapshot` in `02d`. The orders module uses `products.BASE_PRICES` directly. Reconciling these is deferred — the imperfection #7 demo only requires the override rows to exist.
- **`payments.amount`** matches `orders.total_amount` exactly (post-Task-8 fix); refund amounts are clamped to `<= payment.amount`.
