-- ============================================================================
-- BoltBasket — Catalog (products, product_attributes)
-- ============================================================================
-- IMPERFECTION #2 lives here:
--   Some attributes (weight_grams, is_perishable, country_of_origin) live as
--   columns on `products` AND as rows in `product_attributes`. They sometimes
--   disagree. The seed scripts deliberately introduce drift for ~5% of rows.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PRODUCTS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.products (
  product_id          SERIAL PRIMARY KEY,
  sku                 TEXT NOT NULL UNIQUE,           -- format: BB-XXXXX
  product_name        TEXT NOT NULL,
  category_id         INT NOT NULL REFERENCES raw.categories(category_id),
  brand_id            INT NOT NULL REFERENCES raw.brands(brand_id),
  -- Hot attributes promoted from product_attributes for query speed (circa 2022)
  weight_grams        INT,
  is_perishable       BOOLEAN,
  country_of_origin   TEXT,
  -- Pricing
  base_price          NUMERIC(10, 2) NOT NULL,
  mrp                 NUMERIC(10, 2),
  -- Lifecycle
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  launched_at         DATE,
  discontinued_at     DATE,
  -- Audit
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_category ON raw.products(category_id);
CREATE INDEX idx_products_brand ON raw.products(brand_id);
CREATE INDEX idx_products_active ON raw.products(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_products_sku_trgm ON raw.products USING gin (product_name gin_trgm_ops);

COMMENT ON TABLE raw.products IS
  'Product master. Imperfection #2: some columns here (weight_grams, is_perishable, country_of_origin) duplicate rows in product_attributes and occasionally disagree. Imperfection #11: ~3% of rows are orphans (no inventory, no recent orders).';

-- ---------------------------------------------------------------------------
-- PRODUCT ATTRIBUTES (the messy key-value store)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.product_attributes (
  attribute_id        BIGSERIAL PRIMARY KEY,
  product_id          INT NOT NULL REFERENCES raw.products(product_id),
  attribute_key       TEXT NOT NULL,
  attribute_value     TEXT,
  -- No FK to a controlled vocab. Keys are strings. This is the point.
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(product_id, attribute_key)
);

CREATE INDEX idx_product_attributes_product ON raw.product_attributes(product_id);
CREATE INDEX idx_product_attributes_key ON raw.product_attributes(attribute_key);

COMMENT ON TABLE raw.product_attributes IS
  'Flexible key-value attribute store. Imperfection #2: overlaps with product columns. Imperfection #8 origin: schema-on-read philosophy from 2021. Common keys include: weight_grams, is_perishable, country_of_origin, shelf_life_days, storage_temp, gst_slab, hsn_code, is_organic, is_imported, fssai_license, packaging_material, etc.';
