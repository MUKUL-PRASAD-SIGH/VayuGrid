-- Plain-PostgreSQL dev schema (no TimescaleDB required)
-- Use this against the local system postgres when running the API outside Docker.

CREATE TABLE IF NOT EXISTS node_telemetry (
    ts              TIMESTAMPTZ       NOT NULL,
    node_id         INTEGER           NOT NULL,
    node_type       TEXT              NOT NULL,
    battery_soc_kwh DOUBLE PRECISION,
    battery_power_kw DOUBLE PRECISION,
    solar_output_kw DOUBLE PRECISION,
    household_load_kw DOUBLE PRECISION,
    ev_charge_kw    DOUBLE PRECISION,
    net_grid_kw     DOUBLE PRECISION,
    voltage_pu      DOUBLE PRECISION,
    metadata        JSONB             DEFAULT '{}'::jsonb,
    PRIMARY KEY (ts, node_id)
);

CREATE INDEX IF NOT EXISTS node_telemetry_node_ts_idx ON node_telemetry (node_id, ts DESC);

CREATE TABLE IF NOT EXISTS transformer_readings (
    ts                      TIMESTAMPTZ       NOT NULL,
    transformer_id          TEXT              NOT NULL,
    feeder_total_kw         DOUBLE PRECISION  NOT NULL,
    transformer_loading_pu  DOUBLE PRECISION  NOT NULL,
    max_branch_loading_pu   DOUBLE PRECISION  NOT NULL,
    hottest_spot_temp_c     DOUBLE PRECISION  NOT NULL,
    aging_acceleration      DOUBLE PRECISION  NOT NULL,
    grid_available          BOOLEAN           NOT NULL,
    islanding_triggered     BOOLEAN           NOT NULL,
    maintenance_mode        BOOLEAN           NOT NULL,
    metadata                JSONB             DEFAULT '{}'::jsonb,
    PRIMARY KEY (ts, transformer_id)
);

CREATE TABLE IF NOT EXISTS trade_records (
    trade_id                    TEXT             PRIMARY KEY,
    ts                          TIMESTAMPTZ      NOT NULL,
    buyer_node_id               INTEGER          NOT NULL,
    seller_node_id              INTEGER          NOT NULL,
    quantity_kwh                DOUBLE PRECISION NOT NULL,
    cleared_price_inr_per_kwh   DOUBLE PRECISION NOT NULL,
    status                      TEXT             NOT NULL,
    metadata                    JSONB            DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS trade_records_ts_idx ON trade_records (ts DESC);

CREATE TABLE IF NOT EXISTS signal_history (
    signal_id       TEXT             PRIMARY KEY,
    ts              TIMESTAMPTZ      NOT NULL,
    signal_type     TEXT             NOT NULL,
    severity        DOUBLE PRECISION NOT NULL,
    target_node_ids JSONB            NOT NULL,
    reason          TEXT             NOT NULL,
    metadata        JSONB            DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS signal_history_ts_idx ON signal_history (ts DESC);

CREATE TABLE IF NOT EXISTS node_api_keys (
    node_id     INTEGER     NOT NULL,
    key_hash    TEXT        NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (node_id, key_hash)
);

CREATE UNIQUE INDEX IF NOT EXISTS node_api_keys_key_hash_idx ON node_api_keys (key_hash);

CREATE TABLE IF NOT EXISTS household_consents (
    node_id          INTEGER     NOT NULL,
    consented        BOOLEAN     NOT NULL,
    consent_version  TEXT        NOT NULL,
    categories       JSONB       NOT NULL,
    ip_address       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS household_consents_node_idx ON household_consents (node_id);

CREATE TABLE IF NOT EXISTS data_deletion_requests (
    request_id   TEXT        PRIMARY KEY,
    node_id      INTEGER     NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    status       TEXT        NOT NULL,
    metadata     JSONB       DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS data_deletion_requests_node_idx ON data_deletion_requests (node_id);

CREATE TABLE IF NOT EXISTS critical_load_flags (
    flag_id       TEXT        PRIMARY KEY,
    node_id       INTEGER     NOT NULL,
    priority_tier TEXT        NOT NULL,
    reason        TEXT        NOT NULL,
    active        BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata      JSONB       DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS critical_load_flags_node_idx ON critical_load_flags (node_id);
