-- ============================================================================
-- BoltBasket — Schema initialization
-- ============================================================================
-- This file sets up the schemas, extensions, and conventions used across all
-- DDL files. Run this FIRST, before any other DDL file.
--
-- Convention:
--   - `raw` schema = OLTP layer (mirrors what would be in AWS Postgres at real BoltBasket)
--   - `marts` schema = analytical layer (mirrors what would be in GCP BigQuery)
--   - `staging` schema = intermediate layer (mirrors a dbt staging layer)
-- ============================================================================

-- Drop schemas if they exist (for clean re-runs)
DROP SCHEMA IF EXISTS marts CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;

-- Create schemas
CREATE SCHEMA raw;
CREATE SCHEMA staging;
CREATE SCHEMA marts;

COMMENT ON SCHEMA raw IS 'OLTP-equivalent tables. In production, these would live in AWS Postgres.';
COMMENT ON SCHEMA staging IS 'Cleaned and lightly-typed views of raw. dbt staging layer equivalent.';
COMMENT ON SCHEMA marts IS 'Business-logic-applied analytical layer. In production, these would live in BigQuery.';

-- Useful extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- for fuzzy text search on product names

-- Set default search path so queries don't need to qualify everything
SET search_path TO raw, staging, marts, public;

-- A small audit table that future articles about lineage / observability can reference
CREATE TABLE raw.pipeline_runs (
  run_id          BIGSERIAL PRIMARY KEY,
  pipeline_name   TEXT NOT NULL,
  started_at      TIMESTAMPTZ NOT NULL,
  finished_at     TIMESTAMPTZ,
  status          TEXT NOT NULL CHECK (status IN ('running', 'success', 'failed', 'partial')),
  rows_processed  BIGINT,
  notes           TEXT
);

COMMENT ON TABLE raw.pipeline_runs IS
  'Append-only log of pipeline executions. Useful for articles about freshness, lineage, observability.';
