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
-- Imperfection #3: Inventory snapshot/log drift
-- ---------------------------------------------------------------------------
\echo ''
\echo '#3: store_inventory cells where snapshot != replay-of-log'
\echo '    Bulk seed: expect 5 cells (3 negative, 2 positive)'

WITH replay AS (
  SELECT dark_store_id, product_id,
         SUM(quantity_change)::INT AS replay_qty
  FROM raw.inventory_movements
  GROUP BY dark_store_id, product_id
)
SELECT COUNT(*) AS drifted_cells
FROM raw.store_inventory si
JOIN replay r USING (dark_store_id, product_id)
WHERE si.quantity_on_hand <> GREATEST(0, r.replay_qty);


-- ---------------------------------------------------------------------------
-- Imperfection #7: Price-list scope overlap
-- ---------------------------------------------------------------------------
\echo ''
\echo '#7: products covered by all 3 scope types simultaneously'
\echo '    Bulk seed: expect ~10 products (the 10 active SKUs)'

WITH scopes AS (
  SELECT DISTINCT pli.product_id, pl.scope_type
  FROM raw.price_list_items pli
  JOIN raw.price_lists pl ON pl.price_list_id = pli.price_list_id
)
SELECT COUNT(*) AS products_with_all_3_scopes
FROM (
  SELECT product_id
  FROM scopes
  GROUP BY product_id
  HAVING COUNT(DISTINCT scope_type) = 3
) sub;


-- ---------------------------------------------------------------------------
-- Imperfection #8: app_events.properties key chaos
-- ---------------------------------------------------------------------------
\echo ''
\echo '#8: distinct keys across app_events.properties'
\echo '    Bulk seed: expect 400-800 (target ~600)'

SELECT COUNT(DISTINCT k) AS distinct_property_keys
FROM raw.app_events,
     LATERAL jsonb_object_keys(properties) AS k;


-- ---------------------------------------------------------------------------
-- Imperfection #10: Multi-model ad_attributions
-- ---------------------------------------------------------------------------
\echo ''
\echo '#10: orders appearing in >=2 attribution model rows'
\echo '    Bulk seed: expect ~300-450 (~10-15% of attributable orders)'

SELECT COUNT(*) AS orders_with_multiple_models
FROM (
  SELECT order_id
  FROM raw.ad_attributions
  GROUP BY order_id
  HAVING COUNT(DISTINCT attribution_model) >= 2
) sub;


-- ---------------------------------------------------------------------------
-- Imperfection #11: Orphan products
-- ---------------------------------------------------------------------------
\echo ''
\echo '#11: products with no inventory, no orders, no price overrides'
\echo '    Bulk seed: expect 50'

SELECT COUNT(*) AS orphan_product_count
FROM raw.products p
WHERE NOT EXISTS (SELECT 1 FROM raw.store_inventory si WHERE si.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM raw.inventory_movements im WHERE im.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM raw.order_items oi WHERE oi.product_id = p.product_id)
  AND NOT EXISTS (SELECT 1 FROM raw.price_list_items pli WHERE pli.product_id = p.product_id);


-- ---------------------------------------------------------------------------
-- General health check: row counts per table
-- ---------------------------------------------------------------------------
\echo ''
\echo 'General row counts (smoke seed expected values shown)'

SELECT 'cities'                AS table_name, COUNT(*)::TEXT AS row_count, '3'   AS expected FROM raw.cities
UNION ALL SELECT 'pincodes',                COUNT(*)::TEXT, '23'        FROM raw.pincodes
UNION ALL SELECT 'categories',              COUNT(*)::TEXT, '27'        FROM raw.categories
UNION ALL SELECT 'brands',                  COUNT(*)::TEXT, '13'        FROM raw.brands
UNION ALL SELECT 'products',                COUNT(*)::TEXT, '60'        FROM raw.products
UNION ALL SELECT 'product_attributes',      COUNT(*)::TEXT, '18'        FROM raw.product_attributes
UNION ALL SELECT 'dark_stores',             COUNT(*)::TEXT, '12'        FROM raw.dark_stores
UNION ALL SELECT 'service_areas',           COUNT(*)::TEXT, '~28'       FROM raw.service_areas
UNION ALL SELECT 'employees',               COUNT(*)::TEXT, '14'        FROM raw.employees
UNION ALL SELECT 'riders',                  COUNT(*)::TEXT, '53'        FROM raw.riders
UNION ALL SELECT 'users',                   COUNT(*)::TEXT, '3505'      FROM raw.users
UNION ALL SELECT 'addresses',               COUNT(*)::TEXT, '4505'      FROM raw.addresses
UNION ALL SELECT 'subscriptions',           COUNT(*)::TEXT, '1'         FROM raw.subscriptions
UNION ALL SELECT 'carts',                   COUNT(*)::TEXT, '13001'     FROM raw.carts
UNION ALL SELECT 'orders',                  COUNT(*)::TEXT, '10003'     FROM raw.orders
UNION ALL SELECT 'order_items',             COUNT(*)::TEXT, '~30004'    FROM raw.order_items
UNION ALL SELECT 'order_events',            COUNT(*)::TEXT, '~40005'    FROM raw.order_events
UNION ALL SELECT 'payments',                COUNT(*)::TEXT, '10000'     FROM raw.payments
UNION ALL SELECT 'refunds',                 COUNT(*)::TEXT, '500'       FROM raw.refunds
UNION ALL SELECT 'store_inventory',         COUNT(*)::TEXT, '120'       FROM raw.store_inventory
UNION ALL SELECT 'inventory_movements',     COUNT(*)::TEXT, '~25000'    FROM raw.inventory_movements
UNION ALL SELECT 'app_events',              COUNT(*)::TEXT, '~30000'    FROM raw.app_events
UNION ALL SELECT 'search_queries',          COUNT(*)::TEXT, '10000'     FROM raw.search_queries
UNION ALL SELECT 'push_notifications',      COUNT(*)::TEXT, '8000'      FROM raw.push_notifications
UNION ALL SELECT 'ad_campaigns',            COUNT(*)::TEXT, '20'        FROM raw.ad_campaigns
UNION ALL SELECT 'ad_placements',           COUNT(*)::TEXT, '60'        FROM raw.ad_placements
UNION ALL SELECT 'ad_impressions',          COUNT(*)::TEXT, '~20000'    FROM raw.ad_impressions
UNION ALL SELECT 'ad_clicks',               COUNT(*)::TEXT, '2000'      FROM raw.ad_clicks
UNION ALL SELECT 'ad_attributions',         COUNT(*)::TEXT, '~3500'     FROM raw.ad_attributions
UNION ALL SELECT 'promotions',              COUNT(*)::TEXT, '25'        FROM raw.promotions
UNION ALL SELECT 'price_lists',             COUNT(*)::TEXT, '15'        FROM raw.price_lists
UNION ALL SELECT 'price_list_items',        COUNT(*)::TEXT, '150'       FROM raw.price_list_items
UNION ALL SELECT 'pipeline_runs',           COUNT(*)::TEXT, '200'       FROM raw.pipeline_runs;

\echo ''
\echo '============================================================'
\echo 'Verification complete. If any of the above queries returned'
\echo 'unexpected results, the schema or seed has an issue.'
\echo '============================================================'
