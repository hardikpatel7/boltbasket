-- ============================================================================
-- BoltBasket — Operations (dark stores, service areas, employees, riders)
-- ============================================================================
-- IMPERFECTION #4 lives here:
--   service_areas allows many-to-many (one pincode -> multiple stores).
--   The seed scripts will create this overlap deliberately for dense urban areas.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- DARK STORES
-- ---------------------------------------------------------------------------
CREATE TABLE raw.dark_stores (
  dark_store_id       SERIAL PRIMARY KEY,
  store_code          TEXT NOT NULL UNIQUE,           -- format: BLR-IND-01
  store_name          TEXT NOT NULL,                  -- e.g., 'Indiranagar 1'
  city_id             INT NOT NULL REFERENCES raw.cities(city_id),
  primary_pincode_id  INT NOT NULL REFERENCES raw.pincodes(pincode_id),
  area_sqft           INT,
  capacity_skus       INT,                            -- max distinct SKUs stocked
  status              TEXT NOT NULL CHECK (status IN ('active', 'inactive', 'pre_launch', 'closed')),
  launched_at         DATE NOT NULL,
  closed_at           DATE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dark_stores_city ON raw.dark_stores(city_id);
CREATE INDEX idx_dark_stores_status ON raw.dark_stores(status);

-- ---------------------------------------------------------------------------
-- SERVICE AREAS (which dark stores serve which pincodes)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.service_areas (
  service_area_id     SERIAL PRIMARY KEY,
  dark_store_id       INT NOT NULL REFERENCES raw.dark_stores(dark_store_id),
  pincode_id          INT NOT NULL REFERENCES raw.pincodes(pincode_id),
  is_primary          BOOLEAN NOT NULL DEFAULT FALSE,
  -- Distance in km (rough). Used by routing logic.
  distance_km         NUMERIC(4, 2),
  -- Promised delivery time at this (store, pincode) pair
  promised_minutes    INT NOT NULL DEFAULT 15,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(dark_store_id, pincode_id)
);

CREATE INDEX idx_service_areas_pincode ON raw.service_areas(pincode_id);
CREATE INDEX idx_service_areas_store ON raw.service_areas(dark_store_id);
CREATE INDEX idx_service_areas_primary ON raw.service_areas(pincode_id, is_primary) WHERE is_primary = TRUE;

COMMENT ON TABLE raw.service_areas IS
  'Imperfection #4: one pincode can be served by multiple dark stores in dense urban areas. is_primary flags the default; routing picks the closest store with stock.';

-- ---------------------------------------------------------------------------
-- EMPLOYEES (small table, mostly for the named characters)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.employees (
  employee_id         SERIAL PRIMARY KEY,
  employee_code       TEXT NOT NULL UNIQUE,           -- format: BB-EMP-XXXX
  full_name           TEXT NOT NULL,
  role                TEXT NOT NULL,
  department          TEXT NOT NULL,
  city_id             INT REFERENCES raw.cities(city_id),
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at           DATE NOT NULL,
  left_at             DATE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE raw.employees IS
  'Includes the named characters from the bible (Aryan, Priya, Noel, etc.) plus a small sample of dark store managers.';

-- ---------------------------------------------------------------------------
-- DARK STORE ASSIGNMENTS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.dark_store_assignments (
  assignment_id       SERIAL PRIMARY KEY,
  dark_store_id       INT NOT NULL REFERENCES raw.dark_stores(dark_store_id),
  employee_id         INT NOT NULL REFERENCES raw.employees(employee_id),
  role                TEXT NOT NULL CHECK (role IN ('store_manager', 'shift_lead', 'picker', 'rider_supervisor')),
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  started_at          DATE NOT NULL,
  ended_at            DATE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dsa_store ON raw.dark_store_assignments(dark_store_id);
CREATE INDEX idx_dsa_employee ON raw.dark_store_assignments(employee_id);

-- ---------------------------------------------------------------------------
-- RIDERS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.riders (
  rider_id            SERIAL PRIMARY KEY,
  rider_code          TEXT NOT NULL UNIQUE,           -- format: BB-RDR-XXXXX
  full_name           TEXT NOT NULL,
  phone               TEXT NOT NULL UNIQUE,
  city_id             INT NOT NULL REFERENCES raw.cities(city_id),
  primary_dark_store_id INT REFERENCES raw.dark_stores(dark_store_id),
  rider_type          TEXT NOT NULL CHECK (rider_type IN ('payroll', 'gig')),
  vehicle_type        TEXT NOT NULL CHECK (vehicle_type IN ('bike', 'cycle', 'scooter', 'on_foot')),
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at           DATE NOT NULL,
  rating              NUMERIC(3, 2),                  -- average customer rating (1.0-5.0)
  total_deliveries    INT NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_riders_city ON raw.riders(city_id);
CREATE INDEX idx_riders_store ON raw.riders(primary_dark_store_id);
CREATE INDEX idx_riders_active ON raw.riders(is_active) WHERE is_active = TRUE;
