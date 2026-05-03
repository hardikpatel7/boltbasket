-- ============================================================================
-- BoltBasket — Inventory (snapshot + append-only log)
-- ============================================================================
-- IMPERFECTION #3 lives here:
--   store_inventory is a snapshot ("how much do we have right now")
--   inventory_movements is an append-only log
--   Replaying the log should reproduce the snapshot. Under load, it doesn't.
--   Seed scripts will introduce small drift (~1% of rows) to enable articles
--   about reconciliation, materialized views, the Diwali outage.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- STORE INVENTORY (snapshot)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.store_inventory (
  inventory_id        BIGSERIAL PRIMARY KEY,
  dark_store_id       INT NOT NULL REFERENCES raw.dark_stores(dark_store_id),
  product_id          INT NOT NULL REFERENCES raw.products(product_id),
  quantity_on_hand    INT NOT NULL DEFAULT 0,
  quantity_reserved   INT NOT NULL DEFAULT 0,        -- carts/in-flight orders
  reorder_point       INT,
  last_restocked_at   TIMESTAMPTZ,
  -- Imperfection #3 enabler: the timestamp of the last successful update
  last_updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_listed           BOOLEAN NOT NULL DEFAULT TRUE,  -- shown in app for this store
  UNIQUE(dark_store_id, product_id)
);

CREATE INDEX idx_si_store ON raw.store_inventory(dark_store_id);
CREATE INDEX idx_si_product ON raw.store_inventory(product_id);
CREATE INDEX idx_si_low_stock ON raw.store_inventory(dark_store_id, quantity_on_hand) WHERE quantity_on_hand < 10;

COMMENT ON TABLE raw.store_inventory IS
  'Snapshot of current inventory. Imperfection #3: should match the replay of inventory_movements but doesnt always under load.';

-- ---------------------------------------------------------------------------
-- INVENTORY MOVEMENTS (append-only log)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.inventory_movements (
  movement_id         BIGSERIAL PRIMARY KEY,
  dark_store_id       INT NOT NULL REFERENCES raw.dark_stores(dark_store_id),
  product_id          INT NOT NULL REFERENCES raw.products(product_id),
  movement_type       TEXT NOT NULL CHECK (movement_type IN
                        ('inbound_restock', 'outbound_order', 'adjustment_loss',
                         'adjustment_count', 'inter_store_transfer_in',
                         'inter_store_transfer_out', 'returned_to_stock')),
  quantity_change     INT NOT NULL,                   -- positive or negative
  reason_code         TEXT,
  reference_type      TEXT,                           -- 'order', 'restock_pr', 'audit', etc.
  reference_id        BIGINT,                         -- soft FK to whatever
  occurred_at         TIMESTAMPTZ NOT NULL,
  recorded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- when DB received it
  notes               TEXT
);

CREATE INDEX idx_im_store_time ON raw.inventory_movements(dark_store_id, occurred_at);
CREATE INDEX idx_im_product_time ON raw.inventory_movements(product_id, occurred_at);
CREATE INDEX idx_im_reference ON raw.inventory_movements(reference_type, reference_id);

COMMENT ON TABLE raw.inventory_movements IS
  'Append-only log of every stock change. Replay reconstructs history. Imperfection #3: drifts from snapshot under load.';
