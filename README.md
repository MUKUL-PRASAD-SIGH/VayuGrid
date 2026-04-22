# VayuGrid

A smart energy grid

## Pecan Data Wire-Up

Use `pecan_data_wireup.py` to convert raw Pecan Street 1-minute files into
simulator-ready household profiles and optionally replace PV with city-specific
NSRDB solar.

### What it produces

- Minute-level output per household with:
  - `timestamp_ist`
  - `home_id`
  - `load_kw`
  - `pv_kw`
  - `ev_kw`
  - `battery_kw`
  - `grid_kw`
  - `source_region`
- Output files:
  - `data/processed/pecan_india/<city>/<year>/pecan_wired_<city>_<year>.csv`
  - `data/processed/pecan_india/<city>/<year>/pecan_wired_<city>_<year>.parquet`
  - `data/processed/pecan_india/<city>/<year>/pecan_wired_<city>_<year>_summary.csv`

### Example

```bash
/home/varshith/VayuGrid/.venv/bin/python pecan_data_wireup.py \
  --city bangalore \
  --year 2019 \
  --source-regions austin,california,newyork \
  --max-homes 150 \
  --target-kwh-per-day 6.5 \
  --replace-solar-with-nsrdb
```

### Background batch run (all target cities)

```bash
for city in bangalore chennai kochi hyderabad delhi; do
  /home/varshith/VayuGrid/.venv/bin/python pecan_data_wireup.py \
    --city "$city" \
    --year 2019 \
    --source-regions austin,california,newyork \
    --max-homes 150 \
    --target-kwh-per-day 6.5 \
    --replace-solar-with-nsrdb
done
```
