const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');
function script(file) {
  const context = vm.createContext({});
  vm.runInContext(readFileSync(join(__dirname, file), 'utf8'), context);
  return context;
}
const weather = script('contents/ui/weather.js'), fixtures = script('weather-fixtures.js');
const boston = weather.location('42.35843', '-71.05977');
const now = Date.parse('2026-10-18T17:00:00Z');
const sample = changes => weather.parse(fixtures.response(now, changes), now);
const knobs = changes => weather.scene(sample(changes), now, boston).controls;

test('fixed coordinates validate zero, poles and invalid inputs before URL construction', () => {
  assert.equal(weather.location(0, 0).key, '0,0');
  assert.ok(weather.location('-90', '180'));
  for (const pair of [['',1],[' ',1],[null,1],[false,1],[NaN,1],[91,0],[0,-181],['42oops',0],[{},0]]) assert.equal(weather.location(...pair), null);
  const url = new URL(weather.url(boston));
  assert.equal(url.protocol, 'https:');
  assert.equal(url.searchParams.get('timeformat'), 'unixtime');
  assert.equal(url.searchParams.get('timezone'), 'auto');
  assert.equal(url.searchParams.get('wind_speed_unit'), 'kmh');
});

test('documented sunny, overcast, rain, snow-only and highwind values drive independent knobs', () => {
  const clear = knobs({cloud_cover:0, wind_speed_10m:0, wind_direction_10m:0});
  assert.equal(clear.CloudAmount, 0);
  assert.equal(clear.Wind, 0);
  assert.equal(clear.RainIntensity, 0);
  assert.ok(clear.SunStrength > 80);
  const cloud = knobs({cloud_cover:100, weather_code:3});
  assert.equal(cloud.CloudAmount,100);
  assert.ok(cloud.CloudDarkness > clear.CloudDarkness && cloud.SunStrength < clear.SunStrength);
  const wet = sample({rain:0.25, showers:0.25, weather_code:63});
  assert.equal(wet.liquid,2,'900s accumulation converts to mm/hour without including snow');
  assert.ok(weather.scene(wet,now,boston).controls.RainIntensity > 50);
  const snow = sample({rain:0, showers:0, snowfall:0.5, weather_code:73, temperature_2m:-4});
  assert.equal(snow.snow,0.5,'snow remains in cm over the current interval');
  assert.equal(weather.scene(snow,now,boston).controls.RainIntensity,0);
  assert.ok(knobs({wind_speed_10m:200,wind_direction_10m:270}).Wind === 100);
  assert.ok(knobs({wind_speed_10m:200,wind_direction_10m:90}).Wind === -100);
  assert.equal(knobs({rain:100,showers:100}).RainIntensity,100);
});

test('strict response validation rejects malformed, missing, wrong-unit, old and out-of-range values', () => {
  for (const payload of [null,{},[],{error:true},{current:{},current_units:{}}]) assert.throws(() => weather.parse(payload, now));
  for (const changes of [{cloud_cover:null},{rain:'0'},{showers:-1},{snowfall:NaN},{wind_speed_10m:Infinity},{temperature_2m:100},{cloud_cover:101},{weather_code:4},{weather_code:1.5},{interval:0},{interval:86400},{time:now/1000-7201},{time:now/1000+3601}]) assert.throws(() => sample(changes));
  const payload=fixtures.response(now,{});
  payload.current_units.snowfall='mm';
  assert.throws(() => weather.parse(payload,now));
  const zero=sample({temperature_2m:0, cloud_cover:0, rain:0, showers:0, snowfall:0, wind_speed_10m:0, wind_direction_10m:0});
  assert.equal(zero.temperature,0);
});

test('solar position uses location and UTC, including Boston sunrise, DST transitions and polar days', () => {
  // Sunrise/sunset from the actual Boston Open-Meteo probe; NOAA approximation
  // should be near the refracted horizon, without relying on these timestamps.
  for(const seconds of [1792321242,1792360646]) assert.ok(Math.abs(weather.solar(seconds*1000,boston).altitude + 0.833) < 1);
  for(const [before,after] of [['2026-03-08T06:59:00Z','2026-03-08T07:00:00Z'],['2026-11-01T05:59:00Z','2026-11-01T06:00:00Z']]) {
    const first=weather.solar(Date.parse(before),boston), second=weather.solar(Date.parse(after),boston);
    assert.equal(first.phase,'Night');
    assert.equal(second.phase,'Night');
    assert.ok(Math.abs(first.altitude-second.altitude)<0.3,'DST cannot jump solar time by an hour');
  }
  assert.equal(weather.solar(Date.parse('2026-06-21T16:45:00Z'),boston).phase,'Day');
  assert.equal(weather.solar(Date.parse('2026-10-18T21:57:00Z'),boston).phase,'Dusk');
  assert.equal(weather.solar(Date.parse('2026-06-21T04:00:00Z'),weather.location(90,0)).phase,'Day');
  assert.equal(weather.solar(Date.parse('2026-12-21T04:00:00Z'),weather.location(90,0)).phase,'Night');
  for(const time of ['2026-06-21T00:00Z','2026-06-21T12:00Z']) {
    const output=weather.scene(null,Date.parse(time),weather.location(90,180));
    assert.ok(Object.values(output.controls).every(Number.isFinite));
  }
});

test('season is gradual across dates/leap days, longitude rollover and opposite hemispheres', () => {
  const north=weather.location(42,0), south=weather.location(-42,0);
  const january=Date.parse('2026-01-15T12:00Z'), july=Date.parse('2026-07-15T12:00Z');
  assert.equal(weather.season(january,north).name,'Winter');
  assert.equal(weather.season(january,south).name,'Summer');
  assert.equal(weather.season(july,south).name,'Winter');
  assert.equal(weather.season(Date.parse('2026-10-15T12:00Z'),north).name,'Autumn');
  for(const time of ['2026-01-01T00:00Z','2024-02-29T00:00Z','2026-03-01T00:00Z']) {
    const epoch=Date.parse(time);
    assert.ok(Math.abs(weather.season(epoch,north).warmth-weather.season(epoch-60000,north).warmth)<0.01);
  }
  const rollover=Date.parse('2026-01-01T00:30Z');
  assert.ok(Math.abs(weather.season(rollover,weather.location(42,-180)).warmth-weather.season(rollover-86400000,weather.location(42,180)).warmth)<1e-8);
});

test('fallback and visual fixtures provide legible night, moving/hidden sun and distinct seasonal palettes', () => {
  const outputs={};
  for(const name of ['noon','dusk','night','autumn','winter']) {
    const fixture=fixtures.scenario(name);
    outputs[name]=weather.scene(weather.parse(fixture.response,fixture.now),fixture.now,boston);
  }
  assert.ok(outputs.noon.controls.Brightness > outputs.night.controls.Brightness);
  assert.ok(outputs.night.controls.Brightness >= 40);
  assert.equal(outputs.night.controls.SunStrength,0);
  assert.ok(outputs.night.controls.RainIntensity > 0);
  assert.ok(outputs.dusk.controls.SunX > outputs.noon.controls.SunX);
  assert.ok(outputs.autumn.controls.Warmth > outputs.winter.controls.Warmth + 70);
  assert.equal(weather.scene(null,now,boston).controls.RainIntensity,0,'first-load assumption is dry, not stale precipitation');
});
