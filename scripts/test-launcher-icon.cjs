const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');

const app = fs.readFileSync(path.join(root, 'AppScope/app.json5'), 'utf8');
const moduleConfig = fs.readFileSync(path.join(root, 'entry/src/main/module.json5'), 'utf8');
assert.ok(app.includes('"icon": "$media:layered_image"'));
assert.ok(moduleConfig.includes('"icon": "$media:layered_image"'));
for (const base of ['AppScope/resources/base/media', 'entry/src/main/resources/base/media']) {
  const layered = fs.readFileSync(path.join(root, base, 'layered_image.json'), 'utf8');
  const launcher = fs.readFileSync(path.join(root, base, 'launcher_planet.svg'), 'utf8');
  const inAppPlanet = fs.readFileSync(path.join(root, base, 'study_planet.svg'), 'utf8');
  assert.ok(layered.includes('"foreground" : "$media:launcher_planet"'));
  assert.ok(layered.includes('"background" : "$media:planet_icon_background"'));
  assert.ok(launcher.includes('<g transform="translate(0 2)">'), 'launcher foreground moves down by only 2 units');
  assert.ok(!launcher.includes('scale('), 'launcher planet size must remain unchanged');
  assert.ok(!inAppPlanet.includes('translate(0 2)'), 'shared in-app/start-window planet remains unchanged');
}
console.log('PASS launcher icon: real layered resource chain, preserved background/scale and 2-unit vertical centering');
