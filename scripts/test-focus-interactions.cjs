const fs = require('fs');
const vm = require('vm');
const path = require('path');
const assert = require('assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '../entry/src/main/ets');
const serviceBox = { exports: {}, require: () => ({}) };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'services/FocusFieldService.ets'), 'utf8'), { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, serviceBox);
class Gradient { addColorStop() {} }
class DrawingContext {
  createRadialGradient() { return new Gradient(); }
  createLinearGradient() { return new Gradient(); }
}
for (const method of ['save', 'restore', 'translate', 'scale', 'rotate', 'beginPath', 'arc',
  'ellipse', 'fill', 'stroke', 'moveTo', 'lineTo', 'bezierCurveTo', 'closePath', 'clearRect', 'fillRect', 'clip']) {
  DrawingContext.prototype[method] = (...args) => {
    for (const arg of args) if (typeof arg === 'number') assert.ok(Number.isFinite(arg), `${method}: invalid geometry`);
  };
}
// Compile actual component behavior, excluding declarative ArkUI builders.
function loadBehavior(file, name, before) {
  let source = fs.readFileSync(path.join(root, file), 'utf8').split(before)[0];
  source = source.replace(/^import .*;\n/gm, '')
    .replace(/@(Component|Prop|State|Watch\('[^']*'\))\s*/g, '')
    .replace(`export struct ${name}`, `class ${name}`) + `\n}\nexports.Subject = ${name};`;
  const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const sandbox = {
    exports: {}, CanvasRenderingContext2D: DrawingContext, RenderingContextSettings: class {},
    FocusFieldService: serviceBox.exports.FocusFieldService,
    clearInterval: () => {}
  };
  vm.runInNewContext(js, sandbox);
  return sandbox.exports.Subject;
}
const Page = loadBehavior('pages/FocusPage.ets', 'FocusPageView', '  @Builder');
const page = new Page();
page.squadMembers = [{ id: 'rain', name: '小雨', status: '专注中', isSelf: false }];
let sent = '';
page.onQuietSignal = (id, signal) => { sent = `${id}:${signal}`; };
page.sendQuietSignal('加油');
assert.equal(page.quietSignalMessage, '已悄悄送给小雨');
assert.equal(sent, 'rain:加油');
page.squadMembers = [
  { id: 'self', name: '我', status: '专注中', isSelf: true, isDemo: false },
  { id: 'rain', name: '小雨', status: '专注中', isSelf: false, isDemo: true }
];
assert.equal(page.focusingCount(), 1);
assert.ok(page.focusingSummary().includes('含体验成员'));
const Orbit = loadBehavior('components/OrbitField.ets', 'OrbitField', '  build() {');
const orbit = new Orbit();
for (const width of [280, 320, 400]) {
  orbit.fieldWidth = width;
  for (let i = 0; i < 3; i++) {
    let previous;
    for (let frame = 0; frame < 2000; frame++) {
      orbit.orbitPhase = (frame * 0.05 * 360 / 55) % 360;
      const point = orbit.companionLabelPoint(i);
      if (previous) assert.ok(Math.hypot(point[0] - previous[0], point[1] - previous[1]) < 1.5,
        'labels must remain continuous across the entire motion cycle');
      assert.ok(point[0] >= 4 && point[0] + 52 <= width - 4, 'names remain inside the viewport');
      const centerX = 180 * width / 360;
      const centerY = 163 * width / 360;
      const nearX = Math.max(point[0], Math.min(point[0] + 52, centerX));
      const nearY = Math.max(point[1], Math.min(point[1] + 24, centerY));
      assert.ok(Math.hypot(nearX - centerX, nearY - centerY) > 48 * width / 360,
        'text bounds must stay outside the central planet and its halo for the complete orbit');
      previous = point;
    }
  }
}
for (let i = 0; i < 3; i++) {
  orbit.orbitPhase = 0;
  const start = orbit.companionPoint(i);
  orbit.orbitPhase = 180;
  const opposite = orbit.companionPoint(i);
  assert.ok(Math.abs(start[0] + opposite[0] - 360) < 0.0001);
  assert.ok(Math.abs(start[1] + opposite[1] - 326) < 0.0001, 'half revolution reaches the opposite side');
  orbit.orbitPhase = 360;
  const end = orbit.companionPoint(i);
  assert.ok(Math.hypot(start[0] - end[0], start[1] - end[1]) < 0.0001, 'full revolution returns smoothly');
}
const fieldSource = fs.readFileSync(path.join(root, 'components/OrbitField.ets'), 'utf8');
assert.ok(!fieldSource.includes('.rotate({ angle: this.orbitPhase })'), 'names and status stay horizontal');
assert.ok(!fieldSource.includes(".backgroundColor('#CC101626')"), 'labels have no dark backing');
const Backdrop = loadBehavior('components/FocusCosmosBackdrop.ets', 'FocusCosmosBackdrop', '  build() {');
for (const [width, height] of [[800, 360], [1100, 500], [360, 800]]) {
  const backdrop = new Backdrop();
  backdrop.immersive = true; backdrop.ready = true;
  backdrop.canvasWidth = width; backdrop.canvasHeight = height;
  const dots = [];
  backdrop.context.arc = (x, y) => dots.push([x, y]);
  backdrop.paint();
  const earlyCount = dots.length;
  assert.ok(dots.filter(([x]) => x < width * 0.2).length > 12, 'left wing has visible stars');
  assert.ok(dots.filter(([x]) => x > width * 0.8).length > 12, 'right wing has visible stars');
  backdrop.collectiveMinutes = 300;
  dots.length = 0;
  backdrop.paint();
  assert.ok(dots.length > earlyCount, 'panoramic stars grow with collective focus too');
}
const counts = [];
for (const minutes of [0, 120, 600]) {
  const field = new Orbit();
  field.ready = true;
  field.collectiveMinutes = minutes;
  for (let t = 0; t <= 240; t += 0.05) {
    field.time = t;
    field.draw();
    assert.ok(field.meteors.length <= 3, 'live particles stay bounded');
  }
  counts.push(field.meteorSerial);
  assert.equal(field.collectiveMinutes, minutes, 'rendering cannot alter focus history');
}
assert.ok(counts[0] < counts[1] && counts[1] < counts[2], 'longer focus produces more meteors');
orbit.ready = true;
orbit.collectiveMinutes = 0;
orbit.time = 2;
orbit.draw();
const meteor = orbit.meteors[0];
const trajectory = JSON.stringify(meteor);
orbit.collectiveMinutes = 600;
orbit.time += 0.05;
orbit.draw();
assert.equal(JSON.stringify(orbit.meteors[0]), trajectory, 'growth cannot reset a flying meteor');
assert.ok(orbit.richness > 0 && orbit.richness < 0.1, 'growth eases into the new star density');
orbit.time = meteor.born + meteor.duration + 0.1;
orbit.draw();
assert.ok(!orbit.meteors.includes(meteor), 'expired particles are released');
console.log('PASS: quiet signals, continuous labels, finite geometry, progressive meteor frequency, smooth growth and particle cleanup.');
