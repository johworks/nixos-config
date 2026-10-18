// Persistent knobs use understandable integer UI units; rendering uses this
// single bounded normalized state. Presets are writers, never render modes.
var keys = ["Brightness", "Warmth", "SunX", "SunY", "SunStrength", "CloudAmount", "CloudDarkness", "Wind", "RainIntensity"];
function preset(name) {
    if (name === "cloudy")
        return { Brightness: 90, Warmth: -60, SunX: 73, SunY: 34, SunStrength: 0, CloudAmount: 100, CloudDarkness: 20, Wind: 35, RainIntensity: 0 };
    if (name === "rainy")
        return { Brightness: 65, Warmth: -80, SunX: 73, SunY: 34, SunStrength: 0, CloudAmount: 100, CloudDarkness: 85, Wind: 60, RainIntensity: 100 };
    return { Brightness: 100, Warmth: 100, SunX: 73, SunY: 34, SunStrength: 100, CloudAmount: 100, CloudDarkness: 0, Wind: 35, RainIntensity: 0 };
}
function bounded(value, minimum, maximum, fallback) {
    var number = Number(value);
    return value === undefined || value === null || !isFinite(number) ? fallback : Math.max(minimum, Math.min(maximum, number));
}
function normalize(values) {
    var v = values || {}, d = preset("sunny");
    return {
        brightness: bounded(v.Brightness, 0, 150, d.Brightness) / 100,
        warmth: bounded(v.Warmth, -100, 100, d.Warmth) / 100,
        sunX: bounded(v.SunX, 0, 100, d.SunX) / 100,
        sunY: bounded(v.SunY, 0, 100, d.SunY) / 100,
        sunStrength: bounded(v.SunStrength, 0, 100, d.SunStrength) / 100,
        cloudAmount: bounded(v.CloudAmount, 0, 100, d.CloudAmount) / 100,
        cloudDarkness: bounded(v.CloudDarkness, 0, 100, d.CloudDarkness) / 100,
        wind: bounded(v.Wind, -100, 100, d.Wind) / 100,
        rain: bounded(v.RainIntensity, 0, 100, d.RainIntensity) / 100
    };
}
function writePreset(target, name, prefix) {
    var values = preset(name), start = prefix || "";
    for (var i = 0; i < keys.length; i++) target[start + keys[i]] = values[keys[i]];
    // Commit last for every preset path, including context actions after reset.
    target[start + "ControlsVersion"] = 1;
}
function migrate(configuration, prefix) {
    var start = prefix || "";
    if (configuration[start + "ControlsVersion"] >= 1) return false;
    var weather = configuration[start + "Weather"];
    writePreset(configuration, weather === 2 ? "rainy" : weather === 1 ? "cloudy" : "sunny", start);
    return true;
}
