const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const box = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'entry/src/main/ets/services/PlanetGrowthService.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, box);
const calculate = box.exports.PlanetGrowthService.calculate;
const now = Date.parse('2026-09-10T13:00:00+08:00');
assert.equal(calculate([], [], [], now).level, 1);
assert.equal(calculate([], [], [], now).experience, 0);
const focus = [{ elapsedSeconds: 60, dayKey: '2026-09-09' }];
assert.equal(calculate(focus, [{ dayKey: '2026-09-09' }], ['2026-09-09'], now).experience, 10);
assert.equal(calculate(focus, [], ['2026-09-10'], now).experience, 25);
assert.equal(calculate([], [], ['2026-09-08', '2026-09-10'], now).experience, 20);
assert.equal(calculate([{ elapsedSeconds: 59, dayKey: '2026-09-10' }], [], [], now).experience, 0);
assert.equal(calculate([], [], ['invalid', '2026-02-30', '2026-09-11'], now).experience, 0);
const days = Array.from({ length: 28 }, (_, i) => new Date(Date.parse('2026-08-01') + i * 86400000).toISOString().slice(0, 10));
assert.equal(calculate([], [], days.slice(0, 7), now).level, 2);
assert.equal(calculate([], [], days.slice(0, 14), now).stage, 2);
const grown = calculate([], [], days, now);
assert.equal(grown.stage, 3);
assert.equal(grown.experience, 415);
assert.equal(grown.progress, 15);
assert.equal(grown.remaining, 85);
assert.equal(calculate([], [], days, now + 7 * 86400000).experience, grown.experience);
console.log('PASS: daily deduplication, streak bonus, gaps, invalid/future dates, level thresholds, no decay');
