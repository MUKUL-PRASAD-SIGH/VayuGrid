# Baseline Protocol and Success Metrics

This document locks the baseline controller definitions, metric formulas, experiment matrix, and acceptance criteria used to evaluate model performance.

## Baseline Controllers

### Baseline-0 (B0): No Control

- Solar serves local load first.
- Excess solar is exported at fixed feed-in tariff.
- Battery is fully disabled.
- EV charges immediately at maximum allowed charging rate.
- No response to grid or neighborhood signals.

### Baseline-1 (B1): Rule-Based (Deterministic)

#### PB1 Battery Rules

- Charge when `solar > load` and `SoC < 90%`.
- Discharge when `load > solar` and `SoC > 20%`.

#### PB1 EV Rules

- Charge only between `22:00-06:00` OR when `price < ev_price_threshold`.

#### PB1 P2P Rules

- Sell when `market_price > 0.8 x grid_tariff`.
- Buy when `market_price < 1.1 x grid_tariff`.

No adaptive or learned logic is allowed in B1.

### Baseline-2 (B2): MPC-lite

- Rolling horizon: `30 minutes`.
- Re-optimization frequency: every simulation timestep.

#### PB2 Objective

Minimize:

`grid_cost + lambda_1 * curtailment + lambda_2 * battery_degradation`

#### PB2 Constraints

- SoC lower and upper bounds.
- EV energy deadline constraint.
- Battery charge and discharge power limits.
- Grid import and export bounds.
- Device-level and feeder-level power limits.

Use linear programming where feasible for speed and stability.

## Pecan Real-Data Baselines (Locked)

These baselines are used when the simulator is driven by wired Pecan Street
profiles (`load_kw`, `pv_kw`, `ev_kw`, `battery_kw`) from
`pecan_data_wireup.py`.

### Pecan-B0 (PB0): Replay + No Control

- Use `load_kw` as exogenous household demand.
- Use `pv_kw` as exogenous PV generation.
- Battery dispatch is disabled.
- EV follows exogenous `ev_kw` profile only (no optimization).
- P2P trading is disabled.

Purpose: establishes a real-data counterfactual with zero control logic.

### Pecan-B1 (PB1): TOU + Self-Consumption Rules

#### Battery rules

- Charge from PV surplus when `pv > load` and `SoC < 90%`.
- Discharge during evening peak window `18:00-22:00` when `SoC > 20%`.
- Outside evening peak, allow discharge only if `price > 1.2 x grid_tariff`.

#### EV rules

- Treat exogenous `ev_kw` as requested charging demand.
- Shift flexible EV energy to `22:00-06:00` first, then to lowest-price hours.
- Enforce per-vehicle deadline and charger power limits.

#### P2P rules

- Sell when net surplus exists and `market_price >= grid_tariff`.
- Buy when net deficit exists and `market_price <= 0.95 x grid_tariff`.

No forecasting or learned policy is allowed in PB1.

### Pecan-B2 (PB2): Forecasted MPC-lite

- Rolling horizon: `30 minutes`.
- Re-optimization frequency: every simulation timestep.
- Forecast source: persistence baseline from the recent historical window
  (`last 7-day same-minute median`) for both `load` and `pv`.

#### Objective

Minimize:

`grid_cost + lambda_1 * curtailment + lambda_2 * battery_degradation + lambda_3 * ev_deadline_violation`

#### Constraints

- SoC lower and upper bounds.
- EV deadline and charging power constraints.
- Battery charge/discharge limits and round-trip efficiency.
- Grid import/export bounds.
- Feeder and transformer power limits.

Use linear programming where feasible for speed and stability.

## Success Metrics (Locked Definitions)

### 1. Solar Curtailment (%)

Per timestep:

`P_curtailed(t) = max(0, solar(t) - load(t) - battery_charge(t) - export(t))`

Aggregate:

`Curtailment(%) = (sum(P_curtailed) / sum(solar)) * 100`

### 2. Peak Demand Reduction (%)

- Peak is defined as `max(grid_import)` over the full simulation window.

`PeakReduction(%) = ((Peak_B0 - Peak_controller) / Peak_B0) * 100`

### 3. Transformer Overload Events

- Trigger event when `loading > 1.2 pu` for `5 consecutive timesteps`.
- Cooldown after event: `10 minutes` before counting a new event.

### 4. Cost Reduction (%)

Total cost:

`C = grid_import_cost - p2p_revenue`

Include:

- EV charging energy cost.
- Optional battery inefficiency penalty (if enabled, report explicitly).

`CostReduction(%) = ((C_B0 - C_controller) / C_B0) * 100`

### 5. Island Switchover Time (seconds)

- Outage detection condition: `voltage < 0.9 pu`.
- Island stable condition: all nodes disconnected from central grid and local frequency stable.

`SwitchoverTime = t_island_stable - t_outage_detect`

### 6. P2P Settlement Latency

Track timeline:

- `submit_time`
- `match_time`
- `settle_time`

Report:

- p50
- p95
- p99

## Pecan Data Quality Gates (Before Running PB0/PB1/PB2)

- Timestamp continuity at `1-minute` resolution after IST conversion.
- Missingness in `load_kw` and `pv_kw` after preprocessing must be `< 1%`.
- Negative `load_kw` values are clipped to `0` and logged.
- For PV-replaced runs, NSRDB merge coverage must be `>= 99%` of timesteps.
- Homes with fewer than `7` valid days in the selected year are excluded.

## Experiment Matrix

Run each controller (B0, B1, B2) across:

- Cities: Bengaluru, Kochi, Delhi, Chennai, Hyderabad.
- Day types: weekday, weekend.
- Seasonal windows: summer, monsoon, winter representative weeks.
- Scales: 10, 50, 200 nodes.
- Penetration sets:
  - Default: solar 40%, battery 30%, EV 25%.
  - Stress: solar 60%, battery 20%, EV 40%.
- Fault scenarios:
  - Sudden solar drop event (cloud transient).
  - Transformer overload stress.
  - Grid outage and island transition.

Minimum random seeds per scenario: `5`.

## Pecan Experiment Matrix

Run each controller (PB0, PB1, PB2) across:

- Source regions: Austin, California, New York.
- Target city solar mode:
  - Raw Pecan PV (`pv_kw` as-is).
  - NSRDB-replaced PV for Bengaluru, Kochi, Delhi, Chennai, Hyderabad.
- Day types: weekday, weekend.
- Scales: 10, 50, 150 homes.
- Tariff modes:
  - Flat tariff.
  - Time-of-use tariff.
- Fault scenarios:
  - Sudden PV drop event.
  - Transformer overload stress.
  - Grid outage and island transition.

Minimum random seeds per scenario: `3`.

## Reporting Format

| City | Controller | Curtailment (%) | Peak Reduction (%) | Cost Reduction (%) | Overload Events | Latency p95 |
|------|------------|-----------------|--------------------|--------------------|-----------------|-------------|
| BLR  | B0         | mean ± std      | mean ± std         | mean ± std         | count           | value       |

Also include:

- Overall aggregate mean across all cities and seeds.
- Standard deviation and coefficient of variation (`std/mean`) for key metrics.

For Pecan runs, also include:

| Source Region | Target Solar City | Controller | Curtailment (%) | Peak Reduction (%) | Cost Reduction (%) | Overload Events | Latency p95 |
|---------------|-------------------|------------|-----------------|--------------------|--------------------|-----------------|-------------|
| Austin        | BLR               | PB0        | mean ± std      | mean ± std         | mean ± std         | count           | value       |

## Acceptance Criteria

Baseline suite is considered locked when all conditions pass:

- Coefficient of variation for key metrics is `< 0.1`.
- B2 is not worse than B1 on any key metric.
- Controller ordering remains stable across seeds and cities.

Pecan baseline suite is considered locked when all conditions pass:

- Coefficient of variation for key metrics is `< 0.12`.
- PB2 is not worse than PB1 on any key metric.
- PB1 is not worse than PB0 on `CostReduction(%)` and `PeakReduction(%)`.
- Controller ordering remains stable across source regions.
