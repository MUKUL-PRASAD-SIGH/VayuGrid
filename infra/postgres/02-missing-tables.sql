-- Migration: create tables that were missing from the initial init run

CREATE TABLE IF NOT EXISTS signal_history (
    signal_id TEXT PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL,
    signal_type TEXT NOT NULL,
    severity DOUBLE PRECISION NOT NULL,
    target_node_ids JSONB NOT NULL,
    reason TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

SELECT create_hypertable('signal_history', 'ts', if_not_exists => TRUE, migrate_data => TRUE);
ALTER TABLE signal_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'signal_type'
);
SELECT add_compression_policy('signal_history', INTERVAL '7 days', if_not_exists => TRUE);

CREATE TABLE IF NOT EXISTS node_api_keys (
    node_id INTEGER NOT NULL,
    key_hash TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (node_id, key_hash)
);

CREATE UNIQUE INDEX IF NOT EXISTS node_api_keys_key_hash_idx ON node_api_keys (key_hash);

CREATE TABLE IF NOT EXISTS household_consents (
    node_id INTEGER NOT NULL,
    consented BOOLEAN NOT NULL,
    consent_version TEXT NOT NULL,
    categories JSONB NOT NULL,
    ip_address TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS household_consents_node_idx ON household_consents (node_id);

CREATE TABLE IF NOT EXISTS data_deletion_requests (
    request_id TEXT PRIMARY KEY,
    node_id INTEGER NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS data_deletion_requests_node_idx ON data_deletion_requests (node_id);

CREATE TABLE IF NOT EXISTS critical_load_flags (
    flag_id TEXT PRIMARY KEY,
    node_id INTEGER NOT NULL,
    priority_tier TEXT NOT NULL,
    reason TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS critical_load_flags_node_idx ON critical_load_flags (node_id);

-- Retention policy (idempotent)
SELECT add_retention_policy('node_telemetry', INTERVAL '90 days', if_not_exists => TRUE);

-- Continuous aggregates (IF NOT EXISTS is supported in newer TimescaleDB)
CREATE MATERIALIZED VIEW IF NOT EXISTS node_telemetry_15min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('15 minutes', ts) AS bucket,
    node_id,
    AVG(battery_soc_kwh)      AS battery_soc_kwh_avg,
    AVG(battery_power_kw)     AS battery_power_kw_avg,
    AVG(solar_output_kw)      AS solar_output_kw_avg,
    AVG(household_load_kw)    AS household_load_kw_avg,
    AVG(ev_charge_kw)         AS ev_charge_kw_avg,
    AVG(net_grid_kw)          AS net_grid_kw_avg,
    AVG(voltage_pu)           AS voltage_pu_avg
FROM node_telemetry
GROUP BY bucket, node_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
    'node_telemetry_15min',
    start_offset      => INTERVAL '7 days',
    end_offset        => INTERVAL '15 minutes',
    schedule_interval => INTERVAL '15 minutes',
    if_not_exists     => TRUE
);

SELECT add_retention_policy('node_telemetry_15min', INTERVAL '3 years', if_not_exists => TRUE);

CREATE MATERIALIZED VIEW IF NOT EXISTS community_monthly_summary
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 month', ts) AS month,
    SUM(COALESCE(solar_output_kw,    0)) AS solar_kw_sum,
    SUM(COALESCE(household_load_kw,  0)) AS load_kw_sum,
    SUM(COALESCE(net_grid_kw,        0)) AS net_grid_kw_sum
FROM node_telemetry
GROUP BY month
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
    'community_monthly_summary',
    start_offset      => INTERVAL '1 year',
    end_offset        => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day',
    if_not_exists     => TRUE
);
