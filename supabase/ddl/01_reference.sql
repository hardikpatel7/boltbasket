-- ============================================================================
-- BoltBasket — Reference data (cities, pincodes, categories, brands)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- CITIES
-- ---------------------------------------------------------------------------
CREATE TABLE raw.cities (
  city_id         SERIAL PRIMARY KEY,
  city_code       TEXT NOT NULL UNIQUE,           -- 'BLR', 'BOM', 'PNQ'
  city_name       TEXT NOT NULL,
  state           TEXT NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  launched_at     DATE NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE raw.cities IS 'Canonical list of cities BoltBasket operates in. Seeded with BLR, BOM, PNQ for the Supabase reference DB.';

-- ---------------------------------------------------------------------------
-- PINCODES
-- ---------------------------------------------------------------------------
CREATE TABLE raw.pincodes (
  pincode_id      SERIAL PRIMARY KEY,
  pincode         TEXT NOT NULL UNIQUE,           -- 6-digit Indian pincode
  city_id         INT NOT NULL REFERENCES raw.cities(city_id),
  area_name       TEXT NOT NULL,                  -- e.g. 'Indiranagar', 'Bandra West'
  -- Demand-tier influences seeded order volume. Used by seed scripts only;
  -- in real BoltBasket this would not be a column, it'd be derived.
  demand_tier     TEXT NOT NULL CHECK (demand_tier IN ('high', 'medium', 'low')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pincodes_city ON raw.pincodes(city_id);

COMMENT ON COLUMN raw.pincodes.demand_tier IS
  'Synthetic field used only for realistic seed data weighting. Not a real BoltBasket column.';

-- ---------------------------------------------------------------------------
-- CATEGORIES (3-level hierarchy)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.categories (
  category_id     SERIAL PRIMARY KEY,
  category_code   TEXT NOT NULL UNIQUE,
  category_name   TEXT NOT NULL,
  parent_id       INT REFERENCES raw.categories(category_id),  -- self-referential
  level           SMALLINT NOT NULL CHECK (level IN (1, 2, 3)),
  -- Imperfection: this column is denormalized but not always kept in sync
  -- with the parent chain. Articles about referential integrity can use it.
  full_path       TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_categories_parent ON raw.categories(parent_id);
CREATE INDEX idx_categories_level ON raw.categories(level);

COMMENT ON COLUMN raw.categories.full_path IS
  'Denormalized "Aisle > Category > Subcategory" string. Maintained imperfectly. Imperfection #2-adjacent.';

-- ---------------------------------------------------------------------------
-- BRANDS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.brands (
  brand_id        SERIAL PRIMARY KEY,
  brand_code      TEXT NOT NULL UNIQUE,
  brand_name      TEXT NOT NULL,
  is_private_label BOOLEAN NOT NULL DEFAULT FALSE,
  -- BoltBasket Daily is the in-house brand; some brands are partners, etc.
  brand_type      TEXT NOT NULL CHECK (brand_type IN ('mass', 'premium', 'private_label', 'regional')),
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_brands_type ON raw.brands(brand_type);
