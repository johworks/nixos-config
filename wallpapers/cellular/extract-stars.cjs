// Reproduce star-catalog.js from CDS V/50/catalog.gz; no network at runtime.
const { readFileSync, writeFileSync } = require('node:fs');
const { gunzipSync } = require('node:zlib');
const { createHash } = require('node:crypto');
const { join } = require('node:path');
const input = readFileSync(process.argv[2]);
const expected = '3dc44b1e90be8fbe5bcc7656032560f51275f985c7e3f783c9028e1838ec7bed';
if (createHash('sha256').update(input).digest('hex') !== expected) throw new Error('Unexpected catalog bytes; inspect source before updating extraction');
const stars = [];
for (const line of gunzipSync(input).toString('ascii').split('\n')) {
  if (!line.slice(75,83).trim() || !line.slice(102,107).trim()) continue;
  const hr = Number(line.slice(0,4)), magnitude = Number(line.slice(102,107));
  if (magnitude > 4.5) continue;
  const ra = Number(line.slice(75,77)) + Number(line.slice(77,79))/60 + Number(line.slice(79,83))/3600;
  const dec = (line[83] === '-' ? -1 : 1) * (Number(line.slice(84,86)) + Number(line.slice(86,88))/60 + Number(line.slice(88,90))/3600);
  if (![hr,ra,dec,magnitude].every(Number.isFinite)) throw new Error('Invalid catalog record');
  stars.push([hr,Number(ra.toFixed(6)),Number(dec.toFixed(6)),magnitude]);
}
writeFileSync(join(__dirname, 'contents/ui/star-catalog.js'),
  '// Generated from CDS V/50 BSC5; provenance/filter/reproduction in SKY.md.\n'
  + '// [HR identifier, J2000 RA hours, J2000 declination degrees, V magnitude]\nvar stars = [\n'
  + stars.map(star => '    ' + JSON.stringify(star)).join(',\n') + '\n];\n');
process.stdout.write(`${stars.length} catalog stars, V <= 4.5\n`);
