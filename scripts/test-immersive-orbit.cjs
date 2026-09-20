const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const ts = require(process.argv[2]);
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const immersiveSource = fs.readFileSync('entry/src/main/ets/components/ImmersiveOrbit.ets', 'utf8');
const formatBody = immersiveSource.match(/private countdownText\(\): string \{([\s\S]*?)\n  \}/)[1];
const formatBox = { exports: {} };
vm.runInNewContext(ts.transpileModule(`exports.format = function() {${formatBody}}`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText, formatBox);
for (const [seconds, expected] of [[1500, '25:00'], [1499, '24:59'], [60, '01:00'],
  [9, '00:09'], [0, '00:00'], [-5, '00:00'], [NaN, '00:00']]) {
  assert.equal(formatBox.exports.format.call({ remainingSeconds: seconds }), expected);
}
assert.ok(source.includes('remainingSeconds: this.remainingSeconds,\n        collectiveMinutes:'),
  'immersive countdown uses the existing focus clock');
assert.ok(!immersiveSource.includes('setInterval'), 'fullscreen must not create a second countdown');
const behavior = source.slice(source.indexOf('  @State private orbitImmersive'), source.indexOf('  aboutToAppear(): void'));
const calls = [];
let fail = false;
const win = {
  getPreferredOrientation: () => 1,
  getWindowProperties: () => ({ isLayoutFullScreen: false }),
  setPreferredOrientation: async value => { calls.push(['orientation', value]); },
  setWindowLayoutFullScreen: async value => { calls.push(['layout', value]); },
  setWindowSystemBarEnable: async value => { if (fail && !value.length) throw Error('denied'); calls.push(['bars', value]); }
};
let now = 1000;
const box = { exports: {}, Date: { now: () => now }, window: {
  Orientation: { UNSPECIFIED: 0, AUTO_ROTATION_LANDSCAPE: 7 }, getLastWindow: async () => win
}};
vm.runInNewContext(ts.transpileModule(`class Subject { ${behavior.replace(/@State /g, '')} }
exports.Subject = Subject;`, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, box);
function make() {
  const app = new box.exports.Subject();
  app.currentTab = 3; app.profileLoaded = true; app.profileCompleted = true; app.orbitPageVisible = true;
  app.getUIContext = () => ({ getHostContext: () => ({}), getPromptAction: () => ({ showToast: () => {} }) });
  return app;
}
(async () => {
  const app = make();
  await app.enterOrbit();
  assert.equal(app.orbitImmersive, true);
  assert.equal(calls[0][1], 7);
  await app.exitOrbit();
  assert.equal(app.orbitImmersive, false);
  assert.equal(calls.at(-1)[1], 1);
  assert.equal(app.orbitWindow, undefined);
  fail = true;
  await app.enterOrbit();
  assert.equal(app.orbitImmersive, false);
  assert.equal(app.orbitChanging, false);
  assert.equal(calls.at(-1)[1], 1, 'failure restores orientation');
  fail = false;
  const cancelled = make();
  const entry = cancelled.enterOrbit();
  await cancelled.exitOrbit();
  await entry;
  assert.equal(cancelled.orbitImmersive, false, 'back during entry cancels transition');
  const tilted = make();
  let entered = 0;
  tilted.enterOrbit = () => { entered++; tilted.orbitTiltArmed = false; };
  tilted.orbitGravity({ x: 9, y: 0 });
  now += 700;
  tilted.orbitGravity({ x: 9, y: 0 });
  assert.equal(entered, 1);
  now += 700;
  tilted.orbitGravity({ x: 9, y: 0 });
  assert.equal(entered, 1, 'staying sideways does not reopen after exit');
  tilted.orbitGravity({ x: 0, y: 9 });
  tilted.orbitPageVisible = false;
  tilted.orbitGravity({ x: -9, y: 0 });
  now += 700;
  tilted.orbitGravity({ x: -9, y: 0 });
  assert.equal(entered, 1, 'hidden focus page cannot trigger rotation');
  console.log('PASS immersive: landscape, restoration, failure rollback, cancellation and tilt debounce');
})().catch(error => { console.error(error); process.exitCode = 1; });
