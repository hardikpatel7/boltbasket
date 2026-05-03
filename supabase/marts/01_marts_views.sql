-- ============================================================================
-- BoltBasket — Marts Layer (simulates BigQuery analytical layer)
-- ============================================================================
-- In the BoltBasket lore, the marts live in BigQuery. In our reference Supabase,
-- we simulate them as views in the `marts` schema. Same table-shape, same
-- naming conventions, same logic — just running on Postgres instead of BQ.
--
-- Articles can demonstrate "warehouse vs OLTP" by showing queries against
-- raw.orders (OLTP) and marts.fct_orders (warehouse) side by side, even though
-- both are physically in the same Supabase.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- DIMENSIONS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW marts.dim_users AS
SELECT
  u.user_id,
  u.user_uuid,
  u.phone,
  u.email,
  COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '') AS full_name,
  u.signup_at,
  u.signup_city_id,
  c.city_name AS signup_city,
  u.last_active_at,
  u.is_deleted,
  -- Tenure in days
  EXTRACT(DAY FROM (NOW() - u.signup_at))::INT AS tenure_days,
  -- Has active subscription right now?
  EXISTS (
    SELECT 1 FROM raw.subscriptions s
    WHERE s.user_id = u.user_id
      AND s.is_active = TRUE
      AND s.ends_at > NOW()
  ) AS is_plus_subscriber
FROM raw.users u
LEFT JOIN raw.cities c ON c.city_id = u.signup_city_id;

COMMENT ON VIEW marts.dim_users IS 'User dimension. Joins city for convenience and adds derived fields.';


CREATE OR REPLACE VIEW marts.dim_products AS
SELECT
  p.product_id,
  p.sku,
  p.product_name,
  p.category_id,
  c.category_name,
  c.full_path AS category_full_path,
  c.level AS category_level,
  p.brand_id,
  b.brand_name,
  b.brand_type,
  b.is_private_label,
  p.weight_grams,
  p.is_perishable,
  p.country_of_origin,
  p.base_price,
  p.mrp,
  -- Discount % off MRP at base price
  CASE
    WHEN p.mrp IS NOT NULL AND p.mrp > 0
    THEN ROUND(100.0 * (p.mrp - p.base_price) / p.mrp, 2)
    ELSE NULL
  END AS discount_pct_off_mrp,
  p.is_active,
  p.launched_at,
  p.discontinued_at
FROM raw.products p
LEFT JOIN raw.categories c ON c.category_id = p.category_id
LEFT JOIN raw.brands b ON b.brand_id = p.brand_id;


CREATE OR REPLACE VIEW marts.dim_dark_stores AS
SELECT
  ds.dark_store_id,
  ds.store_code,
  ds.store_name,
  ds.city_id,
  c.city_name,
  ds.primary_pincode_id,
  pc.pincode AS primary_pincode,
  pc.area_name AS primary_area,
  ds.area_sqft,
  ds.capacity_skus,
  ds.status,
  ds.launched_at,
  -- How many pincodes does this store service?
  (SELECT COUNT(*) FROM raw.service_areas sa WHERE sa.dark_store_id = ds.dark_store_id AND sa.is_active) AS pincodes_served
FROM raw.dark_stores ds
LEFT JOIN raw.cities c ON c.city_id = ds.city_id
LEFT JOIN raw.pincodes pc ON pc.pincode_id = ds.primary_pincode_id;


-- ---------------------------------------------------------------------------
-- FACT: ORDERS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW marts.fct_orders AS
SELECT
  o.order_id,
  o.order_code,
  o.user_id,
  o.cart_id,
  o.dark_store_id,
  ds.store_code,
  ds.city_id,
  c.city_name,
  o.delivery_address_id,
  o.rider_id,
  o.current_status,

  -- Pricing
  o.subtotal,
  o.discount_amount,
  o.delivery_fee,
  o.tax_amount,
  o.total_amount,
  -- Net of refunds (computed via subquery)
  o.total_amount - COALESCE((
    SELECT SUM(amount) FROM raw.refunds r
    WHERE r.order_id = o.order_id AND r.status = 'completed'
  ), 0) AS net_amount,

  -- Lifecycle timestamps
  o.placed_at,
  o.confirmed_at,
  o.picked_at,
  o.delivered_at,
  o.cancelled_at,
  -- Date dimensions
  o.placed_at::DATE AS order_date,
  EXTRACT(HOUR FROM o.placed_at) AS order_hour,
  EXTRACT(DOW FROM o.placed_at) AS order_dow,  -- 0 = Sunday

  -- Delivery
  o.promised_minutes,
  o.actual_minutes,
  CASE
    WHEN o.actual_minutes IS NULL THEN NULL
    WHEN o.actual_minutes <= o.promised_minutes THEN TRUE
    ELSE FALSE
  END AS delivered_on_time,

  -- Flags
  o.was_substituted,
  o.is_first_order,
  o.used_subscription_benefit,
  CASE WHEN o.cart_id IS NULL THEN TRUE ELSE FALSE END AS is_deeplink_order,

  o.created_at
FROM raw.orders o
LEFT JOIN raw.dark_stores ds ON ds.dark_store_id = o.dark_store_id
LEFT JOIN raw.cities c ON c.city_id = ds.city_id;

COMMENT ON VIEW marts.fct_orders IS 'Order fact table. Includes derived fields for date analytics and a flag for Imperfection #5 (deeplink orders).';


-- ---------------------------------------------------------------------------
-- FACT: ORDER ITEMS (with product join)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW marts.fct_order_items AS
SELECT
  oi.order_item_id,
  oi.order_id,
  o.order_code,
  o.user_id,
  o.dark_store_id,
  o.placed_at,
  o.placed_at::DATE AS order_date,
  oi.product_id,
  -- Use snapshot fields for historical correctness (Imperfection #12 demo)
  oi.product_name_snapshot AS product_name,
  oi.product_sku_snapshot AS sku,
  oi.brand_name_snapshot AS brand_name,
  oi.category_path_snapshot AS category_path,
  oi.unit_price_snapshot AS unit_price,
  oi.mrp_snapshot AS mrp,
  oi.quantity_ordered,
  oi.quantity_delivered,
  oi.line_subtotal,
  oi.line_discount,
  oi.line_total,
  oi.was_substituted,
  oi.substitute_product_id
FROM raw.order_items oi
JOIN raw.orders o ON o.order_id = oi.order_id;


-- ---------------------------------------------------------------------------
-- METRIC LAYER ATTEMPT — daily revenue (data team definition vs finance)
-- ---------------------------------------------------------------------------
-- This is the heart of Arc 2 (the Two Revenues). Two views, two definitions.

-- Data team definition: order_placed_time, gross of refunds
CREATE OR REPLACE VIEW marts.daily_revenue_data_team AS
SELECT
  o.placed_at::DATE AS revenue_date,
  ds.city_id,
  c.city_name,
  COUNT(*) AS order_count,
  SUM(o.total_amount) AS gross_revenue
FROM raw.orders o
JOIN raw.dark_stores ds ON ds.dark_store_id = o.dark_store_id
JOIN raw.cities c ON c.city_id = ds.city_id
WHERE o.current_status NOT IN ('cancelled')  -- exclude cancellations only
GROUP BY 1, 2, 3
ORDER BY revenue_date DESC, city_name;

COMMENT ON VIEW marts.daily_revenue_data_team IS
  'Data teams definition: by order placement date, gross of refunds, excludes cancellations only. Imperfection: doesnt match finance.';

-- Finance definition: order_delivered_time, net of refunds, excludes cancellations + refunds within window
CREATE OR REPLACE VIEW marts.daily_revenue_finance AS
SELECT
  o.delivered_at::DATE AS revenue_date,
  ds.city_id,
  c.city_name,
  COUNT(*) AS order_count,
  SUM(o.total_amount) - COALESCE(SUM(refund_total), 0) AS net_revenue
FROM raw.orders o
JOIN raw.dark_stores ds ON ds.dark_store_id = o.dark_store_id
JOIN raw.cities c ON c.city_id = ds.city_id
LEFT JOIN LATERAL (
  SELECT COALESCE(SUM(r.amount), 0) AS refund_total
  FROM raw.refunds r
  WHERE r.order_id = o.order_id
    AND r.status = 'completed'
) r_agg ON TRUE
WHERE o.current_status = 'delivered'
  AND o.delivered_at IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY revenue_date DESC, city_name;

COMMENT ON VIEW marts.daily_revenue_finance IS
  'Finance definition: by delivery date, net of refunds, only delivered orders. The other half of Arc 2.';


-- ---------------------------------------------------------------------------
-- A side-by-side comparison view — the article-ready output
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW marts.daily_revenue_comparison AS
SELECT
  COALESCE(d.revenue_date, f.revenue_date) AS revenue_date,
  COALESCE(d.city_name, f.city_name) AS city_name,
  d.gross_revenue AS data_team_revenue,
  f.net_revenue AS finance_revenue,
  COALESCE(d.gross_revenue, 0) - COALESCE(f.net_revenue, 0) AS difference,
  CASE
    WHEN f.net_revenue IS NULL OR f.net_revenue = 0 THEN NULL
    ELSE ROUND(100.0 * (COALESCE(d.gross_revenue, 0) - COALESCE(f.net_revenue, 0)) / f.net_revenue, 2)
  END AS pct_difference
FROM marts.daily_revenue_data_team d
FULL OUTER JOIN marts.daily_revenue_finance f
  ON d.revenue_date = f.revenue_date
  AND d.city_name = f.city_name
ORDER BY 1 DESC, 2;

COMMENT ON VIEW marts.daily_revenue_comparison IS
  'Article-ready: side-by-side data team vs finance revenue. The exact view that exposes Arc 2 in real time.';
