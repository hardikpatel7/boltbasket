-- ============================================================================
-- BoltBasket — Imperfection Verification Queries
-- ============================================================================
-- Run after loading the smoke seed (or full seed). Confirms each deliberate
-- imperfection from schema/imperfections.md is actually present in the data.
--
-- Each query is annotated with:
--   - Which imperfection it verifies
--   - What "correct" output looks like (for the smoke seed)
-- ============================================================================

SET search_path TO raw, public;

\echo '============================================================'
\echo 'BoltBasket Imperfection Verification'
\echo '============================================================'

-- ---------------------------------------------------------------------------
-- Imperfection #1: Circular FK + stale primary_address_id
-- ---------------------------------------------------------------------------
\echo ''
\echo '#1: Users with NULL primary_address_id but with addresses'
\echo '    Smoke seed: expect 1 user (user 5)'

SELECT COUNT(*) AS users_with_null_primary_but_have_addresses
FROM raw.users u
WHERE u.primary_address_id IS NULL
  AND EXISTS (SELECT 1 FROM raw.addresses a WHERE a.user_id = u.user_id);


-- ---------------------------------------------------------------------------
-- Imperfection #2: Column vs product_attributes disagreement
-- ---------------------------------------------------------------------------
\echo ''
\echo '#2: Products where column weight_grams disagrees with product_attributes'
\echo '    Smoke seed: expect 1 row (product 4)'

SELECT
  p.product_id,
  p.product_name,
  p.weight_grams AS column_value,
  pa.attribute_value AS attribute_value
FROM raw.products p
JOIN raw.product_attributes pa
  ON pa.product_id = p.product_id
  AND pa.attribute_key = 'weight_grams'
WHERE p.weight_grams::TEXT <> pa.attribute_value;

\echo ''
\echo '#2b: Products where column country_of_origin disagrees with product_attributes'
\echo '    Smoke seed: expect 1 row (product 7)'

SELECT
  p.product_id,
  p.product_name,
  p.country_of_origin AS column_value,
  pa.attribute_value AS attribute_value
FROM raw.products p
JOIN raw.product_attributes pa
  ON pa.product_id = p.product_id
  AND pa.attribute_key = 'country_of_origin'
WHERE p.country_of_origin <> pa.attribute_value;


-- ---------------------------------------------------------------------------
-- Imperfection #4: Multiple service_areas per pincode
-- ---------------------------------------------------------------------------
\echo ''
\echo '#4: Pincodes served by multiple dark stores'
\echo '    Smoke seed: expect ~5 pincodes with multiple stores'

SELECT
  pc.pincode,
  pc.area_name,
  COUNT(DISTINCT sa.dark_store_id) AS stores_serving,
  ARRAY_AGG(ds.store_code ORDER BY sa.is_primary DESC, sa.distance_km) AS store_codes
FROM raw.pincodes pc
JOIN raw.service_areas sa ON sa.pincode_id = pc.pincode_id
JOIN raw.dark_stores ds ON ds.dark_store_id = sa.dark_store_id
GROUP BY pc.pincode, pc.area_name
HAVING COUNT(DISTINCT sa.dark_store_id) > 1
ORDER BY stores_serving DESC, pc.pincode;


-- ---------------------------------------------------------------------------
-- Imperfection #5: Orders with NULL cart_id
-- ---------------------------------------------------------------------------
\echo ''
\echo '#5: Orders with NULL cart_id (deeplink direct-order)'
\echo '    Smoke seed: expect 2 of 3 orders'

SELECT
  COUNT(*) FILTER (WHERE cart_id IS NULL) AS orders_with_null_cart,
  COUNT(*) FILTER (WHERE cart_id IS NOT NULL) AS orders_with_cart,
  ROUND(100.0 * COUNT(*) FILTER (WHERE cart_id IS NULL) / NULLIF(COUNT(*), 0), 2) AS pct_null
FROM raw.orders;


-- ---------------------------------------------------------------------------
-- Imperfection #6: Orders past 'picked' state with NULL rider_id
-- ---------------------------------------------------------------------------
\echo ''
\echo '#6: Orders past picked state with NULL rider_id (legacy bad rows)'
\echo '    Smoke seed: expect 1 row (order BB-20231215-000003)'

SELECT
  order_code,
  current_status,
  placed_at::DATE AS placed_date,
  rider_id
FROM raw.orders
WHERE rider_id IS NULL
  AND current_status IN ('picked', 'packed', 'out_for_delivery', 'delivered')
ORDER BY placed_at;


-- ---------------------------------------------------------------------------
-- Imperfection #12 (positive): order_items snapshot fields are populated
-- ---------------------------------------------------------------------------
\echo ''
\echo '#12: order_items snapshot fields are populated (this is GOOD design)'
\echo '    Smoke seed: expect 0 rows missing snapshot data'

SELECT COUNT(*) AS items_missing_snapshot_data
FROM raw.order_items
WHERE product_name_snapshot IS NULL
   OR product_sku_snapshot IS NULL
   OR unit_price_snapshot IS NULL;


-- ---------------------------------------------------------------------------
-- General health check: row counts per table
-- ---------------------------------------------------------------------------
\echo ''
\echo 'General row counts (smoke seed expected values shown)'

SELECT 'cities'                AS table_name, COUNT(*)::TEXT AS row_count, '3'   AS expected FROM raw.cities
UNION ALL SELECT 'pincodes',                COUNT(*)::TEXT, '23'        FROM raw.pincodes
UNION ALL SELECT 'categories',              COUNT(*)::TEXT, '27'        FROM raw.categories
UNION ALL SELECT 'brands',                  COUNT(*)::TEXT, '13'        FROM raw.brands
UNION ALL SELECT 'products',                COUNT(*)::TEXT, '10'        FROM raw.products
UNION ALL SELECT 'product_attributes',      COUNT(*)::TEXT, '18'        FROM raw.product_attributes
UNION ALL SELECT 'dark_stores',             COUNT(*)::TEXT, '12'        FROM raw.dark_stores
UNION ALL SELECT 'service_areas',           COUNT(*)::TEXT, '~28'       FROM raw.service_areas
UNION ALL SELECT 'employees',               COUNT(*)::TEXT, '14'        FROM raw.employees
UNION ALL SELECT 'users',                   COUNT(*)::TEXT, '5'         FROM raw.users
UNION ALL SELECT 'addresses',               COUNT(*)::TEXT, '5'         FROM raw.addresses
UNION ALL SELECT 'subscriptions',           COUNT(*)::TEXT, '1'         FROM raw.subscriptions
UNION ALL SELECT 'carts',                   COUNT(*)::TEXT, '1'         FROM raw.carts
UNION ALL SELECT 'orders',                  COUNT(*)::TEXT, '3'         FROM raw.orders
UNION ALL SELECT 'order_items',             COUNT(*)::TEXT, '4'         FROM raw.order_items
UNION ALL SELECT 'order_events',            COUNT(*)::TEXT, '5'         FROM raw.order_events;

\echo ''
\echo '============================================================'
\echo 'Verification complete. If any of the above queries returned'
\echo 'unexpected results, the schema or seed has an issue.'
\echo '============================================================'
