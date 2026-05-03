-- ============================================================================
-- BoltBasket — Orders, carts, order_items, order_events, payments, refunds
-- ============================================================================
-- IMPERFECTIONS lives here:
--   #5: orders.cart_id is nullable. ~3% of orders have NULL cart_id (deeplink).
--   #6: orders.rider_id is nullable in DB but app code says it must be set
--       after 'picked' state. Some old rows violate this.
--   #12: order_items has denormalized snapshot fields (this one is GOOD design).
--   #7: price_at_order_time is the canonical price for that line item;
--       the products.base_price might have changed since.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- CARTS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.carts (
  cart_id             BIGSERIAL PRIMARY KEY,
  cart_uuid           UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  user_id             BIGINT NOT NULL REFERENCES raw.users(user_id),
  dark_store_id       INT REFERENCES raw.dark_stores(dark_store_id),
  status              TEXT NOT NULL CHECK (status IN ('active', 'abandoned', 'converted', 'expired')),
  item_count          INT NOT NULL DEFAULT 0,
  subtotal            NUMERIC(10, 2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  abandoned_at        TIMESTAMPTZ,
  converted_at        TIMESTAMPTZ
);

CREATE INDEX idx_carts_user ON raw.carts(user_id);
CREATE INDEX idx_carts_status ON raw.carts(status);
CREATE INDEX idx_carts_created ON raw.carts(created_at);

-- ---------------------------------------------------------------------------
-- ORDERS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.orders (
  order_id            BIGSERIAL PRIMARY KEY,
  order_code          TEXT NOT NULL UNIQUE,           -- format: BB-YYYYMMDD-XXXXXX
  user_id             BIGINT NOT NULL REFERENCES raw.users(user_id),
  -- Imperfection #5: nullable. ~3% of orders have NULL (deeplink direct order)
  cart_id             BIGINT REFERENCES raw.carts(cart_id),
  dark_store_id       INT NOT NULL REFERENCES raw.dark_stores(dark_store_id),
  delivery_address_id BIGINT NOT NULL REFERENCES raw.addresses(address_id),
  -- Imperfection #6: nullable. App code requires non-null after 'picked' state
  -- but ~0.5% of historical rows violate this.
  rider_id            INT REFERENCES raw.riders(rider_id),

  -- Order state (canonical state, derived from order_events)
  current_status      TEXT NOT NULL CHECK (current_status IN
                        ('placed', 'confirmed', 'picking', 'picked',
                         'packed', 'out_for_delivery', 'delivered',
                         'cancelled', 'refunded')),

  -- Pricing breakdown
  subtotal            NUMERIC(10, 2) NOT NULL,
  discount_amount     NUMERIC(10, 2) NOT NULL DEFAULT 0,
  delivery_fee        NUMERIC(10, 2) NOT NULL DEFAULT 0,
  tax_amount          NUMERIC(10, 2) NOT NULL DEFAULT 0,
  total_amount        NUMERIC(10, 2) NOT NULL,

  -- Timestamps for the canonical lifecycle moments
  placed_at           TIMESTAMPTZ NOT NULL,
  confirmed_at        TIMESTAMPTZ,
  picked_at           TIMESTAMPTZ,
  delivered_at        TIMESTAMPTZ,
  cancelled_at        TIMESTAMPTZ,

  -- Delivery metrics
  promised_minutes    INT,                            -- promised at order time
  actual_minutes      INT,                            -- delivered_at - placed_at, in min

  -- Cancellation/refund metadata
  cancellation_reason TEXT,
  was_substituted     BOOLEAN NOT NULL DEFAULT FALSE, -- some item substituted
  is_first_order      BOOLEAN NOT NULL DEFAULT FALSE,

  -- Used for the BoltBasket Plus arc
  used_subscription_benefit BOOLEAN NOT NULL DEFAULT FALSE,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON raw.orders(user_id);
CREATE INDEX idx_orders_store ON raw.orders(dark_store_id);
CREATE INDEX idx_orders_status ON raw.orders(current_status);
CREATE INDEX idx_orders_placed ON raw.orders(placed_at);
CREATE INDEX idx_orders_rider ON raw.orders(rider_id);
CREATE INDEX idx_orders_cart ON raw.orders(cart_id);

COMMENT ON TABLE raw.orders IS
  'Order header. Imperfections #5 (cart_id nullable, ~3% NULL), #6 (rider_id nullable, ~0.5% historical violations).';

-- ---------------------------------------------------------------------------
-- ORDER ITEMS (with denormalized snapshot fields - Imperfection #12)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.order_items (
  order_item_id       BIGSERIAL PRIMARY KEY,
  order_id            BIGINT NOT NULL REFERENCES raw.orders(order_id) ON DELETE CASCADE,
  product_id          INT NOT NULL REFERENCES raw.products(product_id),

  -- Snapshot fields (Imperfection #12: this is *good* design, included for teaching)
  product_name_snapshot   TEXT NOT NULL,
  product_sku_snapshot    TEXT NOT NULL,
  brand_name_snapshot     TEXT,
  category_path_snapshot  TEXT,
  unit_price_snapshot     NUMERIC(10, 2) NOT NULL,
  mrp_snapshot            NUMERIC(10, 2),

  quantity_ordered    INT NOT NULL,
  quantity_delivered  INT NOT NULL DEFAULT 0,
  line_subtotal       NUMERIC(10, 2) NOT NULL,
  line_discount       NUMERIC(10, 2) NOT NULL DEFAULT 0,
  line_total          NUMERIC(10, 2) NOT NULL,

  -- Substitution data
  was_substituted     BOOLEAN NOT NULL DEFAULT FALSE,
  substitute_product_id INT REFERENCES raw.products(product_id),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON raw.order_items(order_id);
CREATE INDEX idx_order_items_product ON raw.order_items(product_id);

COMMENT ON TABLE raw.order_items IS
  'Imperfection #12: denormalized snapshot fields are *correct* design — orders are immutable history even when products change.';

-- ---------------------------------------------------------------------------
-- ORDER EVENTS (append-only state log)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.order_events (
  event_id            BIGSERIAL PRIMARY KEY,
  order_id            BIGINT NOT NULL REFERENCES raw.orders(order_id) ON DELETE CASCADE,
  event_type          TEXT NOT NULL CHECK (event_type IN
                        ('placed', 'confirmed', 'picking_started', 'picked',
                         'packed', 'rider_assigned', 'out_for_delivery',
                         'delivered', 'cancelled', 'refund_requested',
                         'refund_processed', 'substitution_made')),
  occurred_at         TIMESTAMPTZ NOT NULL,
  actor_type          TEXT,                           -- 'system', 'employee', 'rider', 'customer'
  actor_id            BIGINT,
  metadata            JSONB,                          -- event-specific details
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_events_order ON raw.order_events(order_id, occurred_at);
CREATE INDEX idx_order_events_type ON raw.order_events(event_type);
CREATE INDEX idx_order_events_time ON raw.order_events(occurred_at);

COMMENT ON TABLE raw.order_events IS
  'Append-only state log. Foundation for event-sourcing-style analysis. Reconstructs full order history.';

-- ---------------------------------------------------------------------------
-- PAYMENTS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.payments (
  payment_id          BIGSERIAL PRIMARY KEY,
  order_id            BIGINT NOT NULL REFERENCES raw.orders(order_id),
  payment_method      TEXT NOT NULL CHECK (payment_method IN
                        ('upi', 'card', 'wallet', 'cod', 'netbanking', 'plus_credit')),
  amount              NUMERIC(10, 2) NOT NULL,
  status              TEXT NOT NULL CHECK (status IN
                        ('initiated', 'success', 'failed', 'refunded', 'partial_refund')),
  -- Fictional payment provider reference. NEVER real payment IDs.
  provider_ref        TEXT,
  attempted_at        TIMESTAMPTZ NOT NULL,
  completed_at        TIMESTAMPTZ,
  failure_reason      TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_order ON raw.payments(order_id);
CREATE INDEX idx_payments_status ON raw.payments(status);

-- ---------------------------------------------------------------------------
-- REFUNDS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.refunds (
  refund_id           BIGSERIAL PRIMARY KEY,
  order_id            BIGINT NOT NULL REFERENCES raw.orders(order_id),
  payment_id          BIGINT REFERENCES raw.payments(payment_id),
  refund_type         TEXT NOT NULL CHECK (refund_type IN ('full', 'partial', 'item_level')),
  amount              NUMERIC(10, 2) NOT NULL,
  reason              TEXT NOT NULL,
  initiated_at        TIMESTAMPTZ NOT NULL,
  processed_at        TIMESTAMPTZ,
  status              TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refunds_order ON raw.refunds(order_id);
