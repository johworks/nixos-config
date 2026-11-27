const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');
function script(name) {
  const context = vm.createContext({});
  vm.runInContext(readFileSync(join(__dirname, 'contents/ui', name), 'utf8'), context);
  return context;
}
const sky = script('celestial.js'), catalog = script('star-catalog.js').stars;
const near = (actual, expected, tolerance = 1e-4) => assert.ok(Math.abs(actual - expected) < tolerance, `${actual} ≈ ${expected}`);
const epoch = Date.parse('2000-01-01T12:00:00Z');

test('GMST follows USNO J2000 reference and an independent Julian-century polynomial', () => {
  near(sky.sidereal(epoch), 18.697375);
  // Standard GMST polynomial in degrees (same mean equinox convention),
  // evaluated independently without the implementation's midnight split.
  for (const date of ['1987-04-10T19:21:00Z', '2026-10-19T03:00:00Z', '2050-06-01T00:00:00Z']) {
    const now = Date.parse(date), days = now / 86400000 + 2440587.5 - 2451545, t = days / 36525;
    const degrees = 280.46061837 + 360.98564736629 * days + .000387933 * t*t - t*t*t/38710000;
    const expected = ((degrees / 15) % 24 + 24) % 24;
    near(sky.sidereal(now), expected, .00003);
  }
});

test('horizontal geometry fixes meridian, horizon, longitude sign and azimuth quadrants', () => {
  // At J2000 UT noon Greenwich's sidereal angle is 18.697375h (USNO).
  // Synthetic equatorial directions give exact spherical reference cases.
  const ra = 18.697375;
  let h = sky.horizontal(ra, 0, epoch, 30, 0);
  near(h.altitude, 60); near(h.azimuth, 180);
  h = sky.horizontal(ra + 6, 0, epoch, 0, 0);
  near(h.altitude, 0); near(h.azimuth, 90);
  h = sky.horizontal(ra - 6, 0, epoch, 0, 0);
  near(h.altitude, 0); near(h.azimuth, 270);
  near(sky.horizontal(ra, 0, epoch, 0, 90).azimuth, 270);
  near(sky.horizontal(ra, 0, epoch, 0, -90).azimuth, 90);
  h = sky.horizontal(ra + 12, 0, epoch, 0, 0);
  near(h.altitude, -90);
  near(sky.horizontal(0, 90, epoch, 42.35843, -71.05977).altitude, 42.35843);
  near(sky.horizontal(0, -90, epoch, -42, 0).altitude, 42);
  const utc = Date.parse('2026-11-01T06:30:00Z'), civil = Date.parse('2026-11-01T01:30:00-05:00');
  assert.equal(utc, civil);
  assert.deepEqual(sky.horizontal(6.752481, -16.716111, utc, 42, -71), sky.horizontal(6.752481, -16.716111, civil, 42, -71));
});

test('west pinhole handles north/south handedness, horizon culls and aspect', () => {
  function vector(az, alt) {
    const a = az * Math.PI/180, h = alt * Math.PI/180;
    return { east: Math.cos(h)*Math.sin(a), north: Math.cos(h)*Math.cos(a), up: Math.sin(h) };
  }
  const center = sky.project(vector(270,30),1280,720);
  near(center.x,.5); near(center.y,.5);
  const north = sky.project(vector(300,30),1280,720), south = sky.project(vector(240,30),1280,720);
  assert.ok(north.x > .5 && south.x < .5);
  near(north.x + south.x,1);
  for (const v of [vector(270,-1),vector(90,30),vector(0,0),vector(180,0)]) assert.equal(sky.project(v,1280,720),null);
  // Azimuth seam isn't a special case: both north-edge rays face away here.
  assert.equal(sky.project(vector(359.99,0),1280,720),null);
  assert.equal(sky.project(vector(.01,0),1280,720),null);
  const wide = sky.project(vector(285,50),1280,720), tall = sky.project(vector(285,50),720,1280);
  near(wide.x,tall.x); near((.5-wide.y)*720/1280,(.5-tall.y)*1280/720);
  assert.equal(sky.project(vector(270,30),0,720),null);
});

test('catalog is bounded and retains independently identifiable BSC bright stars', () => {
  assert.equal(catalog.length,904);
  assert.equal(new Set(catalog.map(s=>s[0])).size,904);
  const sirius = catalog.find(s=>s[0]===2491), vega = catalog.find(s=>s[0]===7001);
  near(sirius[1],6+45/60+8.9/3600,1e-6); near(sirius[2],-(16+42/60+58/3600),1e-6); near(sirius[3],-1.46);
  near(vega[1],18+36/60+56.3/3600,1e-6); near(vega[2],38+47/60+1/3600,1e-6);
  for (const [hr,ra,dec,mag] of catalog) assert.ok(hr>0 && ra>=0 && ra<24 && dec>=-90 && dec<=90 && mag<=4.5);
  function positions(now) { return catalog.map(s=>sky.project(sky.horizontal(s[1],s[2],Date.parse(now),42.35843,-71.05977),1280,720)).filter(Boolean); }
  const early=positions('2026-10-19T03:00:00Z'), late=positions('2026-10-19T07:00:00Z');
  assert.ok(early.length>30 && early.length<300);
  assert.notDeepEqual(early,late,'real UTC hours change the visible pattern');
});

test('mean lunar phase matches published NASA 2026 new/quarter/full dates within one day', () => {
  const dates = [['2026-01-18T19:52Z',0],['2026-01-26T04:47Z',.25],['2026-02-01T22:09Z',.5],['2026-02-09T12:43Z',.75],['2026-02-17T12:01Z',0],['2026-10-10T15:50Z',0],['2026-10-18T16:13Z',.25],['2026-10-26T04:12Z',.5],['2026-11-01T20:28Z',.75]];
  for (const [date,expected] of dates) {
    const actual = sky.phase(Date.parse(date));
    assert.ok(Math.min(Math.abs(actual-expected),1-Math.abs(actual-expected))<1/29.530588,`${date}: ${actual}`);
  }
  near(sky.illumination(0),0); near(sky.illumination(.25),.5); near(sky.illumination(.5),1);
  near(sky.illumination(.75),.5); assert.equal(sky.phaseName(.75),'Last quarter');
  assert.equal(sky.darkness(20),0); assert.equal(sky.darkness(-2),0);
  assert.equal(sky.darkness(-7),.5); assert.equal(sky.darkness(-12),1);
  assert.equal(sky.transmission(1,1),0); assert.equal(sky.transmission(0,1),1);
});
