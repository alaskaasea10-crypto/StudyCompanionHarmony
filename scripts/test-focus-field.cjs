const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const serviceSource = fs.readFileSync(path.join(root,
  'entry/src/main/ets/services/FocusFieldService.ets'), 'utf8');
const box = { exports: {}, console, require: () => ({}) };
vm.runInNewContext(ts.transpileModule(serviceSource, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, box);
const service = box.exports.FocusFieldService;

let previous = service.starProfile(0);
for (const minutes of [1, 29, 30, 60, 120, 240, 600, 10000]) {
  const profile = service.starProfile(minutes);
  assert.ok(profile.starCount > previous.starCount);
  assert.ok(profile.brightness > previous.brightness);
  assert.ok(profile.meteorInterval < previous.meteorInterval);
  assert.ok(profile.starCount <= 300 && profile.brightness <= 1 && profile.meteorInterval >= 4);
  previous = profile;
}
for (const invalid of [-1, NaN, Infinity]) {
  assert.equal(service.starProfile(invalid).starCount, 76);
}
assert.ok(service.starProfile(30).starCount - service.starProfile(29.99).starCount < 0.02,
  'growth is continuous, not a milestone switch');
assert.equal(service.memberProgress({ status: '专注中', taskProgress: 72 }), 72);
assert.equal(service.memberProgress({ status: '休息中' }), 0);

const focusPage = fs.readFileSync(path.join(root,
  'entry/src/main/ets/pages/FocusPage.ets'), 'utf8');
for (const signal of ['加油', '稳住', '休息一下']) {
  assert.ok(focusPage.includes(`sendQuietSignal('${signal}')`));
}
const orbitField = fs.readFileSync(path.join(root,
  'entry/src/main/ets/components/OrbitField.ets'), 'utf8');
assert.ok(orbitField.includes('ProgressType.Ring'));
assert.ok(!/demoMilestone|drawDemo|playMilestone|极光共振|光场日出/.test(focusPage + orbitField));

const indexSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const minutesBody = indexSource.match(/private collectiveFocusMinutes\(\): number \{([\s\S]*?)\n  \}/)[1];
const minutesBox = { exports: {} };
vm.runInNewContext(ts.transpileModule(`exports.minutes = function() {${minutesBody}}`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText, minutesBox);
const state = {
  squadMembersForDisplay: () => [{ todayMinutes: 30 }, { todayMinutes: 20 }],
  focusMinutes: 25, focusElapsedSeconds: 300, remainingSeconds: 1200,
  isRunning: true, focusSessionCredited: false
};
assert.equal(minutesBox.exports.minutes.call(state), 55);
state.isRunning = false;
assert.equal(minutesBox.exports.minutes.call(state), 55, 'paused elapsed focus is retained');
state.remainingSeconds = 0;
state.focusSessionCredited = true;
assert.equal(minutesBox.exports.minutes.call(state), 50, 'archived focus is not counted twice');

console.log('PASS focus field: continuous bounded star growth, meteor frequency, progress rings and quiet signals');
