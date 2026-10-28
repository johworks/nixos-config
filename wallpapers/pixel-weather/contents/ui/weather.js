// Open-Meteo current estimates: https://open-meteo.com/en/docs
// Solar approximation: https://gml.noaa.gov/grad/solcalc/solareqns.PDF
function clamp(value, minimum, maximum) { return Math.max(minimum, Math.min(maximum, value)); }
function location(latitude, longitude) {
    function coordinate(value, limit) {
        if ((typeof value !== "string" && typeof value !== "number") || String(value).trim() === "") return null;
        var number = Number(value);
        return isFinite(number) && Math.abs(number) <= limit ? number : null;
    }
    var lat = coordinate(latitude, 90), lon = coordinate(longitude, 180);
    return lat === null || lon === null ? null : { latitude: lat, longitude: lon, key: lat + "," + lon };
}
function url(place) {
    return "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude
        + "&current=temperature_2m,cloud_cover,rain,showers,snowfall,weather_code,wind_speed_10m,wind_direction_10m"
        + "&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm&timeformat=unixtime&timezone=auto&forecast_days=1";
}
function parse(payload, now) {
    if (!payload || payload.error || !payload.current || !payload.current_units) throw new Error("Invalid weather response");
    var c = payload.current, u = payload.current_units;
    var units = { time: "unixtime", interval: "seconds", temperature_2m: "°C", cloud_cover: "%", rain: "mm", showers: "mm", snowfall: "cm", weather_code: "wmo code", wind_speed_10m: "km/h", wind_direction_10m: "°" };
    for (var key in units) if (u[key] !== units[key]) throw new Error("Unexpected weather units: " + key);
    function value(key, low, high) {
        var n = c[key];
        if (typeof n !== "number" || !isFinite(n) || n < low || n > high) throw new Error("Invalid weather field: " + key);
        return n;
    }
    var time = value("time", 946684800, now / 1000 + 3600);
    if (now / 1000 - time > 7200) throw new Error("Weather estimate is over two hours old");
    var interval = value("interval", 1, 3600);
    var code = value("weather_code", 0, 99);
    var descriptions = {0:"Clear sky",1:"Mainly clear",2:"Partly cloudy",3:"Overcast",45:"Fog",48:"Rime fog",51:"Light drizzle",53:"Drizzle",55:"Dense drizzle",56:"Freezing drizzle",57:"Freezing drizzle",61:"Light rain",63:"Rain",65:"Heavy rain",66:"Freezing rain",67:"Heavy freezing rain",71:"Light snow",73:"Snow",75:"Heavy snow",77:"Snow grains",80:"Rain showers",81:"Rain showers",82:"Heavy showers",85:"Snow showers",86:"Heavy snow showers",95:"Thunderstorm",96:"Thunderstorm / hail",97:"Heavy thunderstorm",99:"Thunderstorm / hail"};
    if (!descriptions[code]) throw new Error("Unsupported weather code");
    return { time: time * 1000, interval: interval, temperature: value("temperature_2m", -100, 65),
        cloud: value("cloud_cover", 0, 100), liquid: (value("rain", 0, 300) + value("showers", 0, 300)) * 3600 / interval,
        snow: value("snowfall", 0, 100), code: code, description: descriptions[code],
        windSpeed: value("wind_speed_10m", 0, 500), windDirection: value("wind_direction_10m", 0, 360),
        timezone: typeof payload.timezone === "string" ? payload.timezone.slice(0, 80) : "UTC" };
}
function solar(now, place) {
    // UTC arithmetic plus longitude never depends on the harness timezone or
    // a cached civil UTC offset. DST changes therefore cannot jump the sun.
    var date = new Date(now), year = date.getUTCFullYear();
    var yearStart = Date.UTC(year, 0, 1), yearEnd = Date.UTC(year + 1, 0, 1);
    var days = (yearEnd - yearStart) / 86400000;
    var gamma = 2 * Math.PI / days * ((now - yearStart) / 86400000 - 0.5);
    var eq = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma) - 0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma));
    var decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma) - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma) - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma);
    var minutes = date.getUTCHours() * 60 + date.getUTCMinutes() + date.getUTCSeconds() / 60 + eq + 4 * place.longitude;
    var angle = ((((minutes % 1440) + 1440) % 1440) / 4 - 180) * Math.PI / 180;
    var lat = place.latitude * Math.PI / 180;
    var altitude = Math.asin(clamp(Math.sin(lat) * Math.sin(decl) + Math.cos(lat) * Math.cos(decl) * Math.cos(angle), -1, 1)) * 180 / Math.PI;
    return { altitude: altitude, angle: angle,
        phase: altitude < -6 ? "Night" : altitude < 6 ? (angle < 0 ? "Dawn" : "Dusk") : "Day" };
}
function season(now, place) {
    // A smooth annual palette in the location's mean solar calendar, opposite
    // in the southern hemisphere. This is tone, not changing tree geometry.
    var local = new Date(now + place.longitude / 360 * 86400000);
    var month = local.getUTCMonth() + (local.getTime() - Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1)) / 86400000 / new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + 1, 0)).getUTCDate();
    var phase = ((month - 0.5 + (place.latitude < 0 ? 6 : 0) + 12) % 12) / 3;
    var index = Math.floor(phase), mix = (1 - Math.cos((phase - index) * Math.PI)) / 2;
    var warmth = [-85, 10, 65, 100];
    return { warmth: warmth[index] * (1 - mix) + warmth[(index + 1) % 4] * mix,
        name: ["Winter", "Spring", "Summer", "Autumn"][Math.floor((phase + 0.5) % 4)] };
}
function scene(sample, now, place) {
    var weather = sample || {cloud: 40, liquid: 0, windSpeed: 0, windDirection: 0};
    var sun = solar(now, place), palette = season(now, place);
    var daylight = clamp((sun.altitude + 6) / 38, 0, 1);
    daylight = daylight * daylight * (3 - 2 * daylight);
    var horizon = Math.exp(-Math.pow(sun.altitude / 12, 2));
    var rain = clamp(Math.sqrt(weather.liquid / 5) * 100, 0, 100);
    return { phase: sun.phase, season: palette.name, controls: {
        Brightness: Math.round(46 + 64 * daylight - weather.cloud * 0.12 * daylight),
        Warmth: Math.round(clamp(-85 * (1 - daylight) + palette.warmth * daylight * 0.65 + horizon * 135, -100, 100)),
        // Map elevation into the painted sky, whose terrain horizon is above
        // the screen bottom. Low sun can still be occluded by the mountains.
        SunX: clamp(50 + Math.sin(sun.angle) * 44, 6, 94), SunY: clamp(60 - sun.altitude * 0.65, 8, 94),
        SunStrength: Math.round(clamp((sun.altitude + 0.8) / 8, 0, 1) * (1 - weather.cloud / 125) * 100),
        CloudAmount: weather.cloud, CloudDarkness: clamp(weather.cloud * 0.55 + rain * 0.35, 0, 100),
        // Meteorological bearing is where wind comes FROM; use its eastward
        // component for this screen-space view (west wind moves right).
        Wind: Math.round(clamp(-Math.sin(weather.windDirection * Math.PI / 180) * weather.windSpeed / 60, -1, 1) * 100) || 0,
        RainIntensity: Math.round(rain)
    }};
}
