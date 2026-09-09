# Home Assistant AC Analysis

Export recent Home Assistant AC/weather history into local CSV buckets:

```sh
nix run nixpkgs#python3 -- scripts/export-ha-ac-data.py --hours 24 --bucket-minutes 15
```

The script reads the HA token from `/run/secrets/home-assistant-mcp.env` by
default and writes:

```text
.ha-ac-analysis/ac_history.csv
```

The CSV uses HA's integrated kWh counters as the accounting source:

- `sensor.julias_room_ac_energy`
- `sensor.johns_room_ac_energy`

Each row contains a bucketed kWh delta, derived average watts, estimated cost,
outdoor temperature, cloud coverage, weather condition, sun elevation/azimuth,
and the simple east/west room sun exposure flags.

Early results are only useful for pipeline validation. Correlations need days or
weeks of data, changing weather, and normal AC usage patterns before they mean
much.

The NixOS service ingests recent history every 15 minutes with a short overlap
window. Use a one-off longer lookback only when backfilling:

```sh
nix run nixpkgs#python3 -- modules/nixos/home-assistant-analysis/app.py \
  --db /var/lib/home-assistant-analysis/ac-analysis.sqlite3 \
  ingest \
  --base-url http://192.168.10.1:8123 \
  --token-file /run/secrets/home-assistant-mcp.env \
  --hours 72 \
  --bucket-minutes 15
```
