#!/usr/bin/env python3
"""Export Home Assistant AC/weather history for quick local analysis.

This intentionally uses only the Python standard library so it can run through
plain nixpkgs Python before we decide which data-science stack to keep.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import statistics
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path


DEFAULT_ENTITIES = {
    "cost_per_kwh": "input_number.ac_cost_per_kwh",
    "julias_power_w": "sensor.julias_room_ac_power",
    "johns_power_w": "sensor.johns_room_ac_power",
    "julias_energy_kwh": "sensor.julias_room_ac_energy",
    "johns_energy_kwh": "sensor.johns_room_ac_energy",
    "outdoor_temp_f": "sensor.ac_outdoor_temperature",
    "cloud_coverage_pct": "sensor.ac_cloud_coverage",
    "weather_condition": "sensor.ac_weather_condition",
    "sun_elevation_deg": "sensor.ac_sun_elevation",
    "sun_azimuth_deg": "sensor.ac_sun_azimuth",
    "julias_sun_exposure": "binary_sensor.julias_room_ac_sun_exposure",
    "johns_sun_exposure": "binary_sensor.johns_room_ac_sun_exposure",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export AC power and weather/sun context from Home Assistant history."
    )
    parser.add_argument("--base-url", default="http://192.168.10.1:8123")
    parser.add_argument("--token-file", default="/run/secrets/home-assistant-mcp.env")
    parser.add_argument("--hours", type=float, default=24.0)
    parser.add_argument("--bucket-minutes", type=int, default=15)
    parser.add_argument(
        "--csv",
        default=".ha-ac-analysis/ac_history.csv",
        help="CSV output path, or '-' to skip writing a file.",
    )
    return parser.parse_args()


def read_token(token_file: str) -> str:
    for env_name in ("HA_MCP_TOKEN", "API_ACCESS_TOKEN", "HA_TOKEN"):
        token = os.environ.get(env_name)
        if token:
            return token

    path = Path(token_file)
    if path.exists():
        for line in path.read_text().splitlines():
            if not line or line.lstrip().startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key in {"HA_MCP_TOKEN", "API_ACCESS_TOKEN", "HA_TOKEN"}:
                return value.strip().strip('"').strip("'")

    raise SystemExit(
        "No Home Assistant token found. Set HA_MCP_TOKEN or provide --token-file."
    )


def ha_get_json(base_url: str, token: str, path: str, params: dict[str, str]) -> object:
    query = urllib.parse.urlencode(params)
    url = f"{base_url.rstrip('/')}{path}"
    if query:
        url = f"{url}?{query}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Home Assistant API error {exc.code}: {body}") from exc


def parse_ha_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)


def scalar(value: object) -> float | str | None:
    if value is None:
        return None
    text = str(value)
    if text in {"unknown", "unavailable", "None", ""}:
        return None
    if text == "on":
        return 1.0
    if text == "off":
        return 0.0
    try:
        return float(text)
    except ValueError:
        return text


def fetch_history(
    base_url: str,
    token: str,
    start: datetime,
    end: datetime,
    entities: dict[str, str],
) -> dict[str, list[tuple[datetime, float | str | None]]]:
    raw = ha_get_json(
        base_url,
        token,
        f"/api/history/period/{start.isoformat()}",
        {
            "end_time": end.isoformat(),
            "filter_entity_id": ",".join(entities.values()),
        },
    )
    if not isinstance(raw, list):
        raise SystemExit("Unexpected history response shape.")

    entity_to_key = {entity_id: key for key, entity_id in entities.items()}
    series: dict[str, list[tuple[datetime, float | str | None]]] = {
        key: [] for key in entities
    }
    for entity_history in raw:
        if not entity_history:
            continue
        for point in entity_history:
            entity_id = point.get("entity_id")
            key = entity_to_key.get(entity_id)
            if key is None:
                continue
            timestamp = parse_ha_time(point["last_updated"])
            series[key].append((timestamp, scalar(point.get("state"))))

    for points in series.values():
        points.sort(key=lambda item: item[0])
    return series


def bucket_rows(
    series: dict[str, list[tuple[datetime, float | str | None]]],
    start: datetime,
    end: datetime,
    bucket_minutes: int,
) -> list[dict[str, object]]:
    step = timedelta(minutes=bucket_minutes)
    rows: list[dict[str, object]] = []

    bucket_start = floor_bucket(start, bucket_minutes)
    final_bucket_end = floor_bucket(end, bucket_minutes)
    while bucket_start < final_bucket_end:
        bucket_end = bucket_start + step
        bucket_hours_actual = (bucket_end - bucket_start).total_seconds() / 3600
        julias_kwh = delta_between(
            series["julias_energy_kwh"], bucket_start, bucket_end
        )
        johns_kwh = delta_between(
            series["johns_energy_kwh"], bucket_start, bucket_end
        )
        total_kwh = julias_kwh + johns_kwh

        julias_avg_power = kwh_to_average_watts(julias_kwh, bucket_hours_actual)
        johns_avg_power = kwh_to_average_watts(johns_kwh, bucket_hours_actual)
        total_avg_power = kwh_to_average_watts(total_kwh, bucket_hours_actual)
        julias_instant_power = time_weighted_average(
            series["julias_power_w"], bucket_start, bucket_end
        )
        johns_instant_power = time_weighted_average(
            series["johns_power_w"], bucket_start, bucket_end
        )
        rate = numeric(latest_at(series["cost_per_kwh"], bucket_end))

        rows.append(
            {
                "timestamp": bucket_end.isoformat(),
                "julias_kwh": round(julias_kwh, 6),
                "johns_kwh": round(johns_kwh, 6),
                "total_kwh": round(total_kwh, 6),
                "cost": round(total_kwh * rate, 6),
                "julias_avg_power_w": round(julias_avg_power, 3),
                "johns_avg_power_w": round(johns_avg_power, 3),
                "total_avg_power_w": round(total_avg_power, 3),
                "julias_instant_power_w": round(julias_instant_power, 3),
                "johns_instant_power_w": round(johns_instant_power, 3),
                "outdoor_temp_f": round_or_none(
                    time_weighted_average(
                        series["outdoor_temp_f"], bucket_start, bucket_end
                    ),
                    2,
                ),
                "cloud_coverage_pct": round_or_none(
                    time_weighted_average(
                        series["cloud_coverage_pct"], bucket_start, bucket_end
                    ),
                    2,
                ),
                "weather_condition": latest_at(series["weather_condition"], bucket_end),
                "sun_elevation_deg": round_or_none(
                    time_weighted_average(
                        series["sun_elevation_deg"], bucket_start, bucket_end
                    ),
                    2,
                ),
                "sun_azimuth_deg": round_or_none(
                    time_weighted_average(
                        series["sun_azimuth_deg"], bucket_start, bucket_end
                    ),
                    2,
                ),
                "julias_sun_exposure": bool(
                    numeric(latest_at(series["julias_sun_exposure"], bucket_end))
                ),
                "johns_sun_exposure": bool(
                    numeric(latest_at(series["johns_sun_exposure"], bucket_end))
                ),
            }
        )
        bucket_start = bucket_end

    return rows


def floor_bucket(value: datetime, bucket_minutes: int) -> datetime:
    if bucket_minutes <= 0:
        raise ValueError("bucket_minutes must be positive")
    minute = value.minute - (value.minute % bucket_minutes)
    return value.replace(minute=minute, second=0, microsecond=0)


def delta_between(
    points: list[tuple[datetime, float | str | None]], start: datetime, end: datetime
) -> float:
    start_value = numeric(latest_at(points, start))
    end_value = numeric(latest_at(points, end))
    delta = end_value - start_value
    if delta < 0:
        return 0.0
    return delta


def kwh_to_average_watts(kwh: float, hours: float) -> float:
    if hours <= 0:
        return 0.0
    return kwh * 1000 / hours


def latest_at(
    points: list[tuple[datetime, float | str | None]], timestamp: datetime
) -> float | str | None:
    latest: float | str | None = None
    for point_time, value in points:
        if point_time > timestamp:
            break
        latest = value
    return latest


def time_weighted_average(
    points: list[tuple[datetime, float | str | None]], start: datetime, end: datetime
) -> float:
    numeric_points = [(ts, numeric(value)) for ts, value in points if value is not None]
    if not numeric_points or end <= start:
        return 0.0

    current: float | None = None
    for point_time, value in numeric_points:
        if point_time <= start:
            current = value
        else:
            break
    if current is None:
        current = numeric_points[0][1]

    cursor = start
    weighted_total = 0.0
    for point_time, value in numeric_points:
        if point_time <= start:
            continue
        if point_time > end:
            break
        duration = (point_time - cursor).total_seconds()
        if duration > 0:
            weighted_total += current * duration
        cursor = point_time
        current = value

    duration = (end - cursor).total_seconds()
    if duration > 0:
        weighted_total += current * duration

    return weighted_total / (end - start).total_seconds()


def numeric(value: object) -> float:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if math.isfinite(float(value)):
            return float(value)
    return 0.0


def round_or_none(value: float | None, digits: int) -> float | None:
    if value is None:
        return None
    return round(value, digits)


def pearson(rows: list[dict[str, object]], x_key: str, y_key: str) -> float | None:
    pairs = [
        (numeric(row.get(x_key)), numeric(row.get(y_key)))
        for row in rows
        if row.get(x_key) is not None and row.get(y_key) is not None
    ]
    if len(pairs) < 3:
        return None
    xs = [x for x, _ in pairs]
    ys = [y for _, y in pairs]
    if statistics.pstdev(xs) == 0 or statistics.pstdev(ys) == 0:
        return None
    x_mean = statistics.mean(xs)
    y_mean = statistics.mean(ys)
    numerator = sum((x - x_mean) * (y - y_mean) for x, y in pairs)
    denominator = math.sqrt(
        sum((x - x_mean) ** 2 for x in xs) * sum((y - y_mean) ** 2 for y in ys)
    )
    return numerator / denominator


def avg_when(rows: list[dict[str, object]], flag_key: str, value_key: str, flag: bool) -> float | None:
    values = [numeric(row.get(value_key)) for row in rows if row.get(flag_key) is flag]
    if not values:
        return None
    return statistics.mean(values)


def write_csv(path: str, rows: list[dict[str, object]]) -> None:
    if path == "-":
        return
    output = Path(path)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def print_summary(rows: list[dict[str, object]], csv_path: str) -> None:
    if not rows:
        print("No rows exported.")
        return

    total_kwh = sum(numeric(row["total_kwh"]) for row in rows)
    total_cost = sum(numeric(row["cost"]) for row in rows)
    print(f"Rows: {len(rows)}")
    print(f"Range: {rows[0]['timestamp']} to {rows[-1]['timestamp']}")
    if csv_path != "-":
        print(f"CSV: {csv_path}")
    print(f"Estimated AC energy: {total_kwh:.4f} kWh")
    print(f"Estimated AC cost: ${total_cost:.4f}")
    print()

    print("Correlations with average total power from energy deltas:")
    for key, label in (
        ("outdoor_temp_f", "outdoor temp"),
        ("cloud_coverage_pct", "cloud coverage"),
        ("sun_elevation_deg", "sun elevation"),
    ):
        corr = pearson(rows, key, "total_avg_power_w")
        value = "n/a" if corr is None else f"{corr:+.3f}"
        print(f"  {label}: {value}")
    print()

    print("Average room power from energy deltas by simple sun-exposure proxy:")
    for room, flag_key, power_key in (
        ("Julia", "julias_sun_exposure", "julias_avg_power_w"),
        ("John", "johns_sun_exposure", "johns_avg_power_w"),
    ):
        exposed = avg_when(rows, flag_key, power_key, True)
        shaded = avg_when(rows, flag_key, power_key, False)
        exposed_text = "n/a" if exposed is None else f"{exposed:.1f} W"
        shaded_text = "n/a" if shaded is None else f"{shaded:.1f} W"
        print(f"  {room}: exposed {exposed_text}; not exposed {shaded_text}")


def main() -> int:
    args = parse_args()
    token = read_token(args.token_file)
    end = datetime.now(UTC)
    start = end - timedelta(hours=args.hours)
    series = fetch_history(
        args.base_url,
        token,
        start - timedelta(hours=1),
        end,
        DEFAULT_ENTITIES,
    )
    rows = bucket_rows(series, start, end, args.bucket_minutes)
    if not rows:
        raise SystemExit("No history rows were produced.")
    write_csv(args.csv, rows)
    print_summary(rows, args.csv)
    return 0


if __name__ == "__main__":
    sys.exit(main())
