-- The Diwali Outage: companion SQL
-- ============================================================================
-- Demonstrates Imperfection #3: store_inventory snapshot/log drift.
-- Shows the two queries the article walks through.

-- Query 1 — LIVENESS CHECK (what BoltBasket had during Diwali 2024).
-- Asks: "did the inventory_snapshot_refresh job run successfully?"
-- Returns: 5 rows of status='success'. Looks healthy. Was lying.
SELECT
  pipeline_name,
  status,
  started_at AT TIME ZONE 'Asia/Kolkata' AS started_ist,
  finished_at AT TIME ZONE 'Asia/Kolkata' AS finished_ist,
  ROUND(EXTRACT(EPOCH FROM (finished_at - started_at)))::INT AS duration_seconds
FROM raw.pipeline_runs
WHERE pipeline_name = 'inventory_snapshot_refresh'
  AND status = 'success'
ORDER BY started_at DESC
LIMIT 5;

-- Query 2 — FRESHNESS CHECK (what BoltBasket SHOULD have had).
-- Asks: "does the snapshot match the replay of inventory_movements?"
-- Returns: 5 rows where store_inventory.quantity_on_hand disagrees with
-- SUM(quantity_change). Each row is a cell where the dashboard would
-- have shown the wrong number to a customer trying to order.
WITH replay AS (
  SELECT dark_store_id,
         product_id,
         SUM(quantity_change)::INT AS replay_qty
  FROM raw.inventory_movements
  GROUP BY dark_store_id, product_id
)
SELECT
  ds.store_code,
  p.product_name,
  si.quantity_on_hand                             AS snapshot_says,
  GREATEST(0, r.replay_qty)                       AS replay_says,
  si.quantity_on_hand - GREATEST(0, r.replay_qty) AS drift
FROM raw.store_inventory si
JOIN replay r USING (dark_store_id, product_id)
JOIN raw.dark_stores ds ON ds.dark_store_id = si.dark_store_id
JOIN raw.products    p  ON p.product_id     = si.product_id
WHERE si.quantity_on_hand <> GREATEST(0, r.replay_qty)
ORDER BY ABS(si.quantity_on_hand - GREATEST(0, r.replay_qty)) DESC;
