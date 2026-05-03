-- ============================================================================
-- BoltBasket — Users, addresses, subscriptions
-- ============================================================================
-- IMPERFECTION #1 lives here:
--   users.primary_address_id -> addresses.id (circular FK)
--   addresses.user_id -> users.id
--   The seed scripts produce a small number of users where primary_address_id
--   is stale (points to a deleted address) or NULL despite addresses existing.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------------------
CREATE TABLE raw.users (
  user_id             BIGSERIAL PRIMARY KEY,
  user_uuid           UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  phone               TEXT NOT NULL UNIQUE,             -- fictional, format: +91XXXXXXXXXX
  email               TEXT UNIQUE,                      -- nullable, ~70% have email
  first_name          TEXT,
  last_name           TEXT,
  -- The circular FK. Nullable, populated after first address insert.
  primary_address_id  BIGINT,                           -- FK added after addresses created
  signup_city_id      INT REFERENCES raw.cities(city_id),
  signup_at           TIMESTAMPTZ NOT NULL,
  last_active_at      TIMESTAMPTZ,
  is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
  -- Audit
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON raw.users(phone);
CREATE INDEX idx_users_signup_city ON raw.users(signup_city_id);
CREATE INDEX idx_users_last_active ON raw.users(last_active_at);

COMMENT ON COLUMN raw.users.primary_address_id IS
  'Imperfection #1: circular FK with addresses.user_id. Sometimes stale.';

-- ---------------------------------------------------------------------------
-- ADDRESSES
-- ---------------------------------------------------------------------------
CREATE TABLE raw.addresses (
  address_id          BIGSERIAL PRIMARY KEY,
  user_id             BIGINT NOT NULL REFERENCES raw.users(user_id),
  pincode_id          INT NOT NULL REFERENCES raw.pincodes(pincode_id),
  address_line_1      TEXT NOT NULL,
  address_line_2      TEXT,
  landmark            TEXT,
  address_type        TEXT NOT NULL CHECK (address_type IN ('home', 'work', 'other')),
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_addresses_user ON raw.addresses(user_id);
CREATE INDEX idx_addresses_pincode ON raw.addresses(pincode_id);

-- Now add the FK from users.primary_address_id back to addresses
ALTER TABLE raw.users
  ADD CONSTRAINT fk_users_primary_address
  FOREIGN KEY (primary_address_id) REFERENCES raw.addresses(address_id)
  DEFERRABLE INITIALLY DEFERRED;  -- needed for chicken-and-egg insert order

COMMENT ON CONSTRAINT fk_users_primary_address ON raw.users IS
  'Imperfection #1: circular FK. DEFERRABLE so multi-step inserts work.';

-- ---------------------------------------------------------------------------
-- SUBSCRIPTIONS (BoltBasket Plus)
-- ---------------------------------------------------------------------------
CREATE TABLE raw.subscriptions (
  subscription_id     BIGSERIAL PRIMARY KEY,
  user_id             BIGINT NOT NULL REFERENCES raw.users(user_id),
  plan_code           TEXT NOT NULL DEFAULT 'PLUS_QUARTERLY',
  started_at          TIMESTAMPTZ NOT NULL,
  ends_at             TIMESTAMPTZ NOT NULL,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  cancelled_at        TIMESTAMPTZ,
  cancellation_reason TEXT,
  amount_paid         NUMERIC(10, 2) NOT NULL DEFAULT 199.00,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON raw.subscriptions(user_id);
CREATE INDEX idx_subscriptions_active ON raw.subscriptions(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_subscriptions_ends_at ON raw.subscriptions(ends_at);

COMMENT ON TABLE raw.subscriptions IS
  'BoltBasket Plus subscriptions. ~340K subscribers in canon. Articles about Arc 7 (Plus subscriber mystery / causal inference) draw from this table.';
