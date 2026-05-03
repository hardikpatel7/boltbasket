-- ============================================================================
-- BoltBasket — Pricing, promotions, advertising, engagement
-- ============================================================================
-- IMPERFECTION #7 lives here:
--   price_lists overrides products.base_price. Effective price logic is in
--   application code, not the DB. Two services compute it slightly differently.
--
-- IMPERFECTION #10 lives here:
--   ad_attributions can have multiple rows per order from different attribution
--   models (last_click, view_through, multi_touch). Pooja's team and the data
--   team disagree on which is canonical.
--
-- IMPERFECTION #8 lives here:
--   app_events.properties is JSONB. ~600 distinct keys, some misspelled.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PRICE LISTS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.price_lists (
  price_list_id       SERIAL PRIMARY KEY,
  list_name           TEXT NOT NULL,
  scope_type          TEXT NOT NULL CHECK (scope_type IN ('global', 'city', 'store')),
  scope_id            INT,                            -- city_id or dark_store_id depending on scope_type
  starts_at           TIMESTAMPTZ NOT NULL,
  ends_at             TIMESTAMPTZ,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE raw.price_list_items (
  price_list_item_id  BIGSERIAL PRIMARY KEY,
  price_list_id       INT NOT NULL REFERENCES raw.price_lists(price_list_id),
  product_id          INT NOT NULL REFERENCES raw.products(product_id),
  override_price      NUMERIC(10, 2) NOT NULL,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(price_list_id, product_id)
);

CREATE INDEX idx_pli_product ON raw.price_list_items(product_id);

COMMENT ON TABLE raw.price_lists IS
  'Imperfection #7: effective price = most specific override that applies. Logic lives in application code, not DB. Two services compute it differently.';

-- ---------------------------------------------------------------------------
-- PROMOTIONS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.promotions (
  promotion_id        SERIAL PRIMARY KEY,
  promo_code          TEXT NOT NULL UNIQUE,
  promo_name          TEXT NOT NULL,
  promo_type          TEXT NOT NULL CHECK (promo_type IN
                        ('flat_discount', 'percent_discount', 'free_delivery',
                         'bogo', 'category_discount', 'first_order_bonus')),
  discount_value      NUMERIC(10, 2),                 -- meaning depends on promo_type
  min_order_value     NUMERIC(10, 2),
  max_discount        NUMERIC(10, 2),
  -- JSON eligibility rules: applicable categories, user segments, etc.
  eligibility_rules   JSONB,
  starts_at           TIMESTAMPTZ NOT NULL,
  ends_at             TIMESTAMPTZ NOT NULL,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  total_budget        NUMERIC(12, 2),
  spent_so_far        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_promotions_active ON raw.promotions(is_active, ends_at) WHERE is_active = TRUE;

CREATE TABLE raw.promotion_redemptions (
  redemption_id       BIGSERIAL PRIMARY KEY,
  promotion_id        INT NOT NULL REFERENCES raw.promotions(promotion_id),
  order_id            BIGINT NOT NULL REFERENCES raw.orders(order_id),
  user_id             BIGINT NOT NULL REFERENCES raw.users(user_id),
  discount_applied    NUMERIC(10, 2) NOT NULL,
  redeemed_at         TIMESTAMPTZ NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pr_promotion ON raw.promotion_redemptions(promotion_id);
CREATE INDEX idx_pr_order ON raw.promotion_redemptions(order_id);
CREATE INDEX idx_pr_user ON raw.promotion_redemptions(user_id);

-- ---------------------------------------------------------------------------
-- ADVERTISING
-- ---------------------------------------------------------------------------
CREATE TABLE raw.ad_campaigns (
  campaign_id         SERIAL PRIMARY KEY,
  brand_id            INT NOT NULL REFERENCES raw.brands(brand_id),
  campaign_name       TEXT NOT NULL,
  campaign_type       TEXT NOT NULL CHECK (campaign_type IN
                        ('search_sponsored', 'banner', 'push_notification',
                         'category_takeover', 'product_listing_ads')),
  -- Budget and pacing
  total_budget        NUMERIC(12, 2) NOT NULL,
  spent_so_far        NUMERIC(12, 2) NOT NULL DEFAULT 0,
  starts_at           TIMESTAMPTZ NOT NULL,
  ends_at             TIMESTAMPTZ NOT NULL,
  status              TEXT NOT NULL CHECK (status IN ('draft', 'active', 'paused', 'ended')),
  -- Targeting (JSON for flexibility)
  targeting_rules     JSONB,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_campaigns_brand ON raw.ad_campaigns(brand_id);
CREATE INDEX idx_campaigns_status ON raw.ad_campaigns(status);

CREATE TABLE raw.ad_placements (
  placement_id        SERIAL PRIMARY KEY,
  campaign_id         INT NOT NULL REFERENCES raw.ad_campaigns(campaign_id),
  placement_type      TEXT NOT NULL CHECK (placement_type IN
                        ('home_banner', 'category_banner', 'search_result',
                         'product_detail_recommended', 'cart_recommended', 'push')),
  product_id          INT REFERENCES raw.products(product_id),  -- if SKU-level
  bid_amount          NUMERIC(10, 2),                 -- INR per impression or click
  bid_type            TEXT NOT NULL CHECK (bid_type IN ('cpm', 'cpc', 'cpa')),
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_placements_campaign ON raw.ad_placements(campaign_id);
CREATE INDEX idx_placements_product ON raw.ad_placements(product_id);

CREATE TABLE raw.ad_impressions (
  impression_id       BIGSERIAL PRIMARY KEY,
  placement_id        INT NOT NULL REFERENCES raw.ad_placements(placement_id),
  user_id             BIGINT REFERENCES raw.users(user_id),
  session_id          UUID,
  shown_at            TIMESTAMPTZ NOT NULL,
  context             JSONB,                          -- search query, page, position, etc.
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_impressions_placement ON raw.ad_impressions(placement_id);
CREATE INDEX idx_impressions_user ON raw.ad_impressions(user_id);
CREATE INDEX idx_impressions_time ON raw.ad_impressions(shown_at);

CREATE TABLE raw.ad_clicks (
  click_id            BIGSERIAL PRIMARY KEY,
  impression_id       BIGINT REFERENCES raw.ad_impressions(impression_id),
  placement_id        INT NOT NULL REFERENCES raw.ad_placements(placement_id),
  user_id             BIGINT REFERENCES raw.users(user_id),
  clicked_at          TIMESTAMPTZ NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clicks_placement ON raw.ad_clicks(placement_id);
CREATE INDEX idx_clicks_user ON raw.ad_clicks(user_id);
CREATE INDEX idx_clicks_time ON raw.ad_clicks(clicked_at);

-- ---------------------------------------------------------------------------
-- AD ATTRIBUTIONS (Imperfection #10)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.ad_attributions (
  attribution_id      BIGSERIAL PRIMARY KEY,
  order_id            BIGINT NOT NULL REFERENCES raw.orders(order_id),
  campaign_id         INT NOT NULL REFERENCES raw.ad_campaigns(campaign_id),
  placement_id        INT REFERENCES raw.ad_placements(placement_id),
  -- The attribution model that produced this row
  attribution_model   TEXT NOT NULL CHECK (attribution_model IN
                        ('last_click', 'view_through', 'multi_touch_linear',
                         'multi_touch_position_based')),
  attributed_value    NUMERIC(10, 2) NOT NULL,        -- INR credited to this campaign
  attributed_weight   NUMERIC(5, 4),                  -- 0.0-1.0; sum across rows for one order under one model = 1.0
  attribution_window_hours INT NOT NULL DEFAULT 24,
  attributed_at       TIMESTAMPTZ NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attr_order ON raw.ad_attributions(order_id);
CREATE INDEX idx_attr_campaign ON raw.ad_attributions(campaign_id);
CREATE INDEX idx_attr_model ON raw.ad_attributions(attribution_model);

COMMENT ON TABLE raw.ad_attributions IS
  'Imperfection #10: same order can have multiple rows from different attribution models. "How many orders did campaign X drive?" has multiple correct answers depending on model.';

-- ---------------------------------------------------------------------------
-- ENGAGEMENT — APP EVENTS, SEARCH QUERIES, PUSH NOTIFICATIONS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.app_events (
  event_id            BIGSERIAL PRIMARY KEY,
  user_id             BIGINT REFERENCES raw.users(user_id),
  session_id          UUID,
  event_name          TEXT NOT NULL,                  -- 'screen_view', 'product_clicked', 'add_to_cart', etc.
  event_time          TIMESTAMPTZ NOT NULL,
  -- Imperfection #8: schema-on-read; ~600 distinct keys exist; some misspelled
  properties          JSONB,
  device_type         TEXT,                           -- 'android', 'ios', 'web'
  app_version         TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_app_events_user_time ON raw.app_events(user_id, event_time);
CREATE INDEX idx_app_events_name ON raw.app_events(event_name);
CREATE INDEX idx_app_events_time ON raw.app_events(event_time);
CREATE INDEX idx_app_events_session ON raw.app_events(session_id);

COMMENT ON TABLE raw.app_events IS
  'Imperfection #8: properties JSONB has ~600 distinct keys; some keys are misspelled (productId vs product_id vs prod_id all coexist).';

CREATE TABLE raw.search_queries (
  search_id           BIGSERIAL PRIMARY KEY,
  user_id             BIGINT REFERENCES raw.users(user_id),
  session_id          UUID,
  query_text          TEXT NOT NULL,
  search_at           TIMESTAMPTZ NOT NULL,
  result_count        INT NOT NULL,
  clicked_product_id  INT REFERENCES raw.products(product_id),
  led_to_order        BOOLEAN NOT NULL DEFAULT FALSE,
  led_to_order_id     BIGINT REFERENCES raw.orders(order_id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_search_user ON raw.search_queries(user_id);
CREATE INDEX idx_search_time ON raw.search_queries(search_at);
CREATE INDEX idx_search_zero_results ON raw.search_queries(result_count) WHERE result_count = 0;

CREATE TABLE raw.push_notifications (
  push_id             BIGSERIAL PRIMARY KEY,
  user_id             BIGINT NOT NULL REFERENCES raw.users(user_id),
  campaign_code       TEXT,                           -- internal grouping
  title               TEXT NOT NULL,
  body                TEXT,
  sent_at             TIMESTAMPTZ NOT NULL,
  delivered           BOOLEAN NOT NULL DEFAULT FALSE,
  opened              BOOLEAN NOT NULL DEFAULT FALSE,
  opened_at           TIMESTAMPTZ,
  led_to_order        BOOLEAN NOT NULL DEFAULT FALSE,
  led_to_order_id     BIGINT REFERENCES raw.orders(order_id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_push_user ON raw.push_notifications(user_id);
CREATE INDEX idx_push_campaign ON raw.push_notifications(campaign_code);
CREATE INDEX idx_push_sent ON raw.push_notifications(sent_at);
