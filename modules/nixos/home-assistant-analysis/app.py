#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import os
import sqlite3
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ENTITIES = {
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


class HomeAssistantUnavailable(Exception):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Home Assistant AC analysis service")
    parser.add_argument("--db", default=os.environ.get("AC_ANALYSIS_DB", "ac-analysis.sqlite3"))
    sub = parser.add_subparsers(dest="command", required=True)

    ingest = sub.add_parser("ingest", help="Fetch HA history and upsert bucket rows")
    ingest.add_argument("--base-url", default=os.environ.get("HA_BASE_URL", "http://127.0.0.1:8123"))
    ingest.add_argument("--token-file", default=os.environ.get("HA_TOKEN_FILE", "/run/secrets/home-assistant-mcp.env"))
    ingest.add_argument("--hours", type=float, default=float(os.environ.get("AC_ANALYSIS_LOOKBACK_HOURS", "4")))
    ingest.add_argument("--bucket-minutes", type=int, default=int(os.environ.get("AC_ANALYSIS_BUCKET_MINUTES", "15")))

    serve = sub.add_parser("serve", help="Serve the local analysis dashboard")
    serve.add_argument("--host", default=os.environ.get("AC_ANALYSIS_HOST", "127.0.0.1"))
    serve.add_argument("--port", type=int, default=int(os.environ.get("AC_ANALYSIS_PORT", "8091")))

    return parser.parse_args()


def read_token(token_file: str) -> str:
    for env_name in ("HA_MCP_TOKEN", "API_ACCESS_TOKEN", "HA_TOKEN"):
        token = os.environ.get(env_name)
        if token:
            return token

    path = Path(token_file)
    for line in path.read_text().splitlines():
        if not line or line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in {"HA_MCP_TOKEN", "API_ACCESS_TOKEN", "HA_TOKEN"}:
            return value.strip().strip('"').strip("'")

    raise SystemExit(f"No HA token found in {token_file}")


def ha_get_json(base_url: str, token: str, path: str, params: dict[str, str]) -> object:
    query = urllib.parse.urlencode(params)
    url = f"{base_url.rstrip('/')}{path}"
    if query:
        url = f"{url}?{query}"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Home Assistant API error {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise HomeAssistantUnavailable(str(exc)) from exc


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


def numeric(value: object) -> float:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if math.isfinite(float(value)):
            return float(value)
    return 0.0


def latest_at(points: list[tuple[datetime, float | str | None]], timestamp: datetime) -> float | str | None:
    latest: float | str | None = None
    for point_time, value in points:
        if point_time > timestamp:
            break
        latest = value
    return latest


def delta_between(points: list[tuple[datetime, float | str | None]], start: datetime, end: datetime) -> float:
    delta = numeric(latest_at(points, end)) - numeric(latest_at(points, start))
    return max(delta, 0.0)


def time_weighted_average(points: list[tuple[datetime, float | str | None]], start: datetime, end: datetime) -> float | None:
    numeric_points = [(ts, numeric(value)) for ts, value in points if value is not None]
    if not numeric_points or end <= start:
        return None

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


def fetch_history(base_url: str, token: str, start: datetime, end: datetime) -> dict[str, list[tuple[datetime, float | str | None]]]:
    raw = ha_get_json(
        base_url,
        token,
        f"/api/history/period/{start.isoformat()}",
        {
            "end_time": end.isoformat(),
            "filter_entity_id": ",".join(ENTITIES.values()),
        },
    )
    if not isinstance(raw, list):
        raise SystemExit("Unexpected history response shape")

    entity_to_key = {entity_id: key for key, entity_id in ENTITIES.items()}
    series: dict[str, list[tuple[datetime, float | str | None]]] = {key: [] for key in ENTITIES}
    for entity_history in raw:
        for point in entity_history:
            key = entity_to_key.get(point.get("entity_id"))
            if key is None:
                continue
            series[key].append((parse_ha_time(point["last_updated"]), scalar(point.get("state"))))
    for points in series.values():
        points.sort(key=lambda item: item[0])
    return series


def bucket_rows(series: dict[str, list[tuple[datetime, float | str | None]]], start: datetime, end: datetime, bucket_minutes: int) -> list[dict[str, object]]:
    step = timedelta(minutes=bucket_minutes)
    rows: list[dict[str, object]] = []
    bucket_start = floor_bucket(start, bucket_minutes)
    final_bucket_end = floor_bucket(end, bucket_minutes)

    while bucket_start < final_bucket_end:
        bucket_end = bucket_start + step
        hours = (bucket_end - bucket_start).total_seconds() / 3600
        if hours <= 0:
            break

        julias_kwh = delta_between(series["julias_energy_kwh"], bucket_start, bucket_end)
        johns_kwh = delta_between(series["johns_energy_kwh"], bucket_start, bucket_end)
        total_kwh = julias_kwh + johns_kwh
        rate = numeric(latest_at(series["cost_per_kwh"], bucket_end))
        weather = latest_at(series["weather_condition"], bucket_end)

        rows.append(
            {
                "bucket_start": bucket_start.isoformat(),
                "bucket_end": bucket_end.isoformat(),
                "bucket_minutes": round(hours * 60, 3),
                "julias_kwh": round(julias_kwh, 6),
                "johns_kwh": round(johns_kwh, 6),
                "total_kwh": round(total_kwh, 6),
                "cost": round(total_kwh * rate, 6),
                "julias_avg_power_w": round(julias_kwh * 1000 / hours, 3),
                "johns_avg_power_w": round(johns_kwh * 1000 / hours, 3),
                "total_avg_power_w": round(total_kwh * 1000 / hours, 3),
                "outdoor_temp_f": rounded(time_weighted_average(series["outdoor_temp_f"], bucket_start, bucket_end), 2),
                "cloud_coverage_pct": rounded(time_weighted_average(series["cloud_coverage_pct"], bucket_start, bucket_end), 2),
                "weather_condition": weather if isinstance(weather, str) else "",
                "sun_elevation_deg": rounded(time_weighted_average(series["sun_elevation_deg"], bucket_start, bucket_end), 2),
                "sun_azimuth_deg": rounded(time_weighted_average(series["sun_azimuth_deg"], bucket_start, bucket_end), 2),
                "julias_sun_exposure": int(bool(numeric(latest_at(series["julias_sun_exposure"], bucket_end)))),
                "johns_sun_exposure": int(bool(numeric(latest_at(series["johns_sun_exposure"], bucket_end)))),
            }
        )
        bucket_start = bucket_end
    return rows


def floor_bucket(value: datetime, bucket_minutes: int) -> datetime:
    if bucket_minutes <= 0:
        raise ValueError("bucket_minutes must be positive")
    minute = value.minute - (value.minute % bucket_minutes)
    return value.replace(minute=minute, second=0, microsecond=0)


def rounded(value: float | None, digits: int) -> float | None:
    if value is None:
        return None
    return round(value, digits)


def connect(db_path: str) -> sqlite3.Connection:
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS ac_buckets (
          bucket_start TEXT PRIMARY KEY,
          bucket_end TEXT NOT NULL,
          bucket_minutes REAL NOT NULL,
          julias_kwh REAL NOT NULL,
          johns_kwh REAL NOT NULL,
          total_kwh REAL NOT NULL,
          cost REAL NOT NULL,
          julias_avg_power_w REAL NOT NULL,
          johns_avg_power_w REAL NOT NULL,
          total_avg_power_w REAL NOT NULL,
          outdoor_temp_f REAL,
          cloud_coverage_pct REAL,
          weather_condition TEXT NOT NULL,
          sun_elevation_deg REAL,
          sun_azimuth_deg REAL,
          julias_sun_exposure INTEGER NOT NULL,
          johns_sun_exposure INTEGER NOT NULL,
          updated_at TEXT NOT NULL
        )
        """
    )
    return conn


def upsert_rows(conn: sqlite3.Connection, rows: list[dict[str, object]]) -> None:
    now = datetime.now(UTC).isoformat()
    for row in rows:
        payload = {**row, "updated_at": now}
        conn.execute(
            """
            INSERT INTO ac_buckets (
              bucket_start, bucket_end, bucket_minutes, julias_kwh, johns_kwh,
              total_kwh, cost, julias_avg_power_w, johns_avg_power_w,
              total_avg_power_w, outdoor_temp_f, cloud_coverage_pct,
              weather_condition, sun_elevation_deg, sun_azimuth_deg,
              julias_sun_exposure, johns_sun_exposure, updated_at
            )
            VALUES (
              :bucket_start, :bucket_end, :bucket_minutes, :julias_kwh, :johns_kwh,
              :total_kwh, :cost, :julias_avg_power_w, :johns_avg_power_w,
              :total_avg_power_w, :outdoor_temp_f, :cloud_coverage_pct,
              :weather_condition, :sun_elevation_deg, :sun_azimuth_deg,
              :julias_sun_exposure, :johns_sun_exposure, :updated_at
            )
            ON CONFLICT(bucket_start) DO UPDATE SET
              bucket_end = excluded.bucket_end,
              bucket_minutes = excluded.bucket_minutes,
              julias_kwh = excluded.julias_kwh,
              johns_kwh = excluded.johns_kwh,
              total_kwh = excluded.total_kwh,
              cost = excluded.cost,
              julias_avg_power_w = excluded.julias_avg_power_w,
              johns_avg_power_w = excluded.johns_avg_power_w,
              total_avg_power_w = excluded.total_avg_power_w,
              outdoor_temp_f = excluded.outdoor_temp_f,
              cloud_coverage_pct = excluded.cloud_coverage_pct,
              weather_condition = excluded.weather_condition,
              sun_elevation_deg = excluded.sun_elevation_deg,
              sun_azimuth_deg = excluded.sun_azimuth_deg,
              julias_sun_exposure = excluded.julias_sun_exposure,
              johns_sun_exposure = excluded.johns_sun_exposure,
              updated_at = excluded.updated_at
            """,
            payload,
        )
    conn.commit()


def delete_unaligned_rows(conn: sqlite3.Connection, bucket_minutes: int) -> int:
    rows = conn.execute("SELECT bucket_start FROM ac_buckets").fetchall()
    stale = []
    for row in rows:
        timestamp = datetime.fromisoformat(row["bucket_start"])
        if (
            timestamp.minute % bucket_minutes != 0
            or timestamp.second != 0
            or timestamp.microsecond != 0
        ):
            stale.append(row["bucket_start"])
    if not stale:
        return 0
    conn.executemany(
        "DELETE FROM ac_buckets WHERE bucket_start = ?",
        [(bucket_start,) for bucket_start in stale],
    )
    conn.commit()
    return len(stale)


def ingest(args: argparse.Namespace) -> int:
    token = read_token(args.token_file)
    end = datetime.now(UTC)
    start = end - timedelta(hours=args.hours)
    try:
        series = fetch_history(args.base_url, token, start - timedelta(hours=1), end)
    except HomeAssistantUnavailable as exc:
        print(f"Home Assistant unavailable; skipping this ingest run: {exc}")
        return 0
    rows = bucket_rows(series, start, end, args.bucket_minutes)
    if not rows:
        print("No Home Assistant history rows available; skipping this ingest run")
        return 0
    with connect(args.db) as conn:
        deleted = delete_unaligned_rows(conn, args.bucket_minutes)
        upsert_rows(conn, rows)
    message = f"Upserted {len(rows)} AC analysis buckets into {args.db}"
    if deleted:
        message += f"; removed {deleted} old misaligned buckets"
    print(message)
    return 0


def rows_for_days(conn: sqlite3.Connection, days: int) -> list[dict[str, object]]:
    since = (datetime.now(UTC) - timedelta(days=days)).isoformat()
    cur = conn.execute(
        "SELECT * FROM ac_buckets WHERE bucket_end >= ? ORDER BY bucket_start",
        (since,),
    )
    return [dict(row) for row in cur.fetchall()]


def trim_leading_empty_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    for index, row in enumerate(rows):
        has_energy = numeric(row.get("total_kwh")) > 0
        has_weather = row.get("outdoor_temp_f") is not None
        if has_energy and has_weather:
            return rows[index:]
    return rows


def summarize(rows: list[dict[str, object]]) -> dict[str, object]:
    if not rows:
        return {"rows": 0}
    return {
        "rows": len(rows),
        "start": rows[0]["bucket_start"],
        "end": rows[-1]["bucket_end"],
        "bucket_minutes": rows[-1]["bucket_minutes"],
        "total_kwh": round(sum(numeric(row["total_kwh"]) for row in rows), 4),
        "julias_kwh": round(sum(numeric(row["julias_kwh"]) for row in rows), 4),
        "johns_kwh": round(sum(numeric(row["johns_kwh"]) for row in rows), 4),
        "cost": round(sum(numeric(row["cost"]) for row in rows), 4),
        "avg_temp_f": rounded(avg(row["outdoor_temp_f"] for row in rows), 1),
        "avg_total_power_w": rounded(avg(row["total_avg_power_w"] for row in rows), 1),
    }


def avg(values: object) -> float | None:
    nums = [numeric(value) for value in values if value is not None]
    if not nums:
        return None
    return sum(nums) / len(nums)


INDEX_HTML = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AC Analysis</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 24px; background: #101418; color: #e6edf3; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
    .card { background: #182028; border: 1px solid #2b3642; border-radius: 8px; padding: 16px; }
    h1, h2 { margin: 0 0 12px; }
    .metric { font-size: 28px; font-weight: 650; }
    .muted { color: #9fb0c0; font-size: 13px; }
    canvas { width: 100%; height: 220px; background: #0d1117; border-radius: 6px; }
  </style>
</head>
<body>
  <h1>AC Analysis</h1>
  <p class="muted">Bucketed from Home Assistant energy counters. Refreshes every minute.</p>
  <div id="summary" class="grid"></div>
  <div class="grid" style="margin-top: 16px;">
    <div class="card">
      <h2>Energy per 15-min Bucket</h2>
      <p class="muted">Y-axis: kWh used during each completed bucket. X-axis: time.</p>
      <canvas id="energy"></canvas>
    </div>
    <div class="card">
      <h2>Outdoor Temp vs Avg AC Power</h2>
      <p class="muted">X-axis: outdoor temp °F. Y-axis: average watts from bucket kWh.</p>
      <canvas id="scatter"></canvas>
    </div>
  </div>
<script>
async function load() {
  const res = await fetch('/api/data?days=7');
  const data = await res.json();
  renderSummary(data.summary);
  drawLine(document.getElementById('energy'), data.rows, 'total_kwh');
  drawScatter(document.getElementById('scatter'), data.rows, 'outdoor_temp_f', 'total_avg_power_w');
}
function renderSummary(s) {
  if (!s.rows) {
    document.getElementById('summary').innerHTML =
      '<div class="card"><div class="muted">Status</div><div class="metric">Waiting for ingest</div></div>';
    return;
  }
  const cards = [
    ['Total energy', `${s.total_kwh ?? 0} kWh`],
    ['Total cost', `$${s.cost ?? 0}`],
    ['Julia energy', `${s.julias_kwh ?? 0} kWh`],
    ['John energy', `${s.johns_kwh ?? 0} kWh`],
    ['Avg outside temp', `${s.avg_temp_f ?? 'n/a'} °F`],
    ['Window', `${formatTime(s.start)} - ${formatTime(s.end)}`],
    ['Buckets', `${s.rows ?? 0} x ${s.bucket_minutes ?? '?'} min`],
  ];
  document.getElementById('summary').innerHTML = cards.map(([k,v]) =>
    `<div class="card"><div class="muted">${k}</div><div class="metric">${v}</div></div>`
  ).join('');
}
function formatTime(value) {
  if (!value) return 'n/a';
  return new Date(value).toLocaleString();
}
function clearCanvas(canvas) {
  const rect = canvas.getBoundingClientRect();
  canvas.width = Math.max(1, Math.floor(rect.width * devicePixelRatio));
  canvas.height = Math.max(1, Math.floor(rect.height * devicePixelRatio));
  const ctx = canvas.getContext('2d');
  ctx.scale(devicePixelRatio, devicePixelRatio);
  ctx.clearRect(0, 0, rect.width, rect.height);
  ctx.strokeStyle = '#314151';
  ctx.fillStyle = '#9fb0c0';
  ctx.font = '12px system-ui';
  return [ctx, rect.width, rect.height];
}
function bounds(values) {
  const nums = values.filter(v => Number.isFinite(v));
  return [Math.min(...nums), Math.max(...nums)];
}
function drawLine(canvas, rows, key) {
  const [ctx, w, h] = clearCanvas(canvas);
  const vals = rows.map(r => Number(r[key])).filter(Number.isFinite);
  if (vals.length < 2) return;
  const [min, max] = bounds(vals);
  ctx.beginPath();
  rows.forEach((r, i) => {
    const x = 28 + i * (w - 44) / Math.max(rows.length - 1, 1);
    const y = h - 24 - ((Number(r[key]) - min) / Math.max(max - min, 0.0001)) * (h - 44);
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  });
  ctx.strokeStyle = '#58a6ff';
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.fillStyle = '#9fb0c0';
  ctx.fillText(`${max.toFixed(3)} kWh`, 8, 16);
  ctx.fillText(`${min.toFixed(3)} kWh`, 8, h - 8);
}
function drawScatter(canvas, rows, xKey, yKey) {
  const [ctx, w, h] = clearCanvas(canvas);
  const points = rows.map(r => [Number(r[xKey]), Number(r[yKey])]).filter(([x,y]) => Number.isFinite(x) && Number.isFinite(y));
  if (points.length < 2) return;
  const [minX, maxX] = bounds(points.map(p => p[0]));
  const [minY, maxY] = bounds(points.map(p => p[1]));
  ctx.fillStyle = '#3fb950';
  for (const [xv, yv] of points) {
    const x = 28 + ((xv - minX) / Math.max(maxX - minX, 0.0001)) * (w - 44);
    const y = h - 24 - ((yv - minY) / Math.max(maxY - minY, 0.0001)) * (h - 44);
    ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2); ctx.fill();
  }
  ctx.fillStyle = '#9fb0c0';
  ctx.fillText(`${minX.toFixed(0)}°F`, 28, h - 8);
  ctx.fillText(`${maxX.toFixed(0)}°F`, w - 52, h - 8);
  ctx.fillText(`${maxY.toFixed(0)} W`, 8, 16);
}
load();
setInterval(load, 60000);
</script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    db_path = "ac-analysis.sqlite3"

    def do_GET(self) -> None:
        url = urllib.parse.urlparse(self.path)
        if url.path == "/":
            self.respond(200, "text/html; charset=utf-8", INDEX_HTML.encode())
            return
        if url.path == "/api/data":
            params = urllib.parse.parse_qs(url.query)
            days = int(params.get("days", ["7"])[0])
            with connect(self.db_path) as conn:
                rows = trim_leading_empty_rows(rows_for_days(conn, days))
            payload = json.dumps({"summary": summarize(rows), "rows": rows}).encode()
            self.respond(200, "application/json", payload)
            return
        self.respond(404, "text/plain", b"not found")

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"{self.address_string()} - {fmt % args}")

    def respond(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def serve(args: argparse.Namespace) -> int:
    Handler.db_path = args.db
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Serving AC analysis on http://{args.host}:{args.port}")
    server.serve_forever()
    return 0


def main() -> int:
    args = parse_args()
    if args.command == "ingest":
        return ingest(args)
    if args.command == "serve":
        return serve(args)
    raise SystemExit(f"unknown command {args.command}")


if __name__ == "__main__":
    sys.exit(main())
