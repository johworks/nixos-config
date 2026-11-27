// Synthetic fixtures matching the documented current response and the Boston
// probe on 2026-10-18. Amounts are over interval900s: rain/showers mm, snow cm.
// https://open-meteo.com/en/docs (Current Weather / JSON Return Object)
function response(now, changes) {
    var current = {time: Math.floor(now / 900000) * 900, interval: 900, temperature_2m: 18,
        cloud_cover: 0, rain: 0, showers: 0, snowfall: 0, weather_code: 0,
        wind_speed_10m: 8, wind_direction_10m: 270};
    for (var key in (changes || {})) current[key] = changes[key];
    return {latitude: 42.365166, longitude: -71.0618, timezone: "America/New_York", utc_offset_seconds: -14400,
        current_units: {time: "unixtime", interval: "seconds", temperature_2m: "°C", cloud_cover: "%",
            rain: "mm", showers: "mm", snowfall: "cm", weather_code: "wmo code", wind_speed_10m: "km/h", wind_direction_10m: "°"},
        current: current};
}
function scenario(name) {
    var times = {noon:"2026-06-21T16:45:00Z",dusk:"2026-10-18T21:57:00Z",night:"2026-10-19T02:00:00Z",autumn:"2026-10-15T16:45:00Z",winter:"2026-01-15T16:45:00Z",
        "sky-night":"2026-10-19T03:00:00Z", "sky-later":"2026-10-19T07:00:00Z", "sky-overcast":"2026-10-19T03:00:00Z"};
    var now = Date.parse(times[name] || times.noon);
    var data = name === "night" ? {rain: 0.75, cloud_cover: 100, weather_code: 63, wind_speed_10m: 30, wind_direction_10m: 90, temperature_2m: 6} : {};
    if (name === "sky-overcast") data = {cloud_cover: 100, weather_code: 3};
    return {now: now, response: response(now, data)};
}
