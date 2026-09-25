const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const file = path.resolve(__dirname, '..', 'entry/src/main/ets/pages/HomePage.ets');
const fullSource = fs.readFileSync(file, 'utf8');
let source = fullSource.split('  build() {')[0];
source = source.replace(/^import .*;\n/gm, '')
  .replace(/@(Component|Prop|State)\s*/g, '')
  .replace('export struct HomePageView', 'class HomePageView') +
  '\n}\nexports.HomePageView = HomePageView;';
const box = { exports: {}, Date, console, Promise, setTimeout,
  formatSubjectName: value => value };
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, box);
const Page = box.exports.HomePageView;
const tasks = [
  { id: 'math-1', title: '复习导数', subject: '高等数学', minutes: 25, completed: false },
  { id: 'english-1', title: '英语作业', subject: '大学英语', minutes: 20, completed: false }
];

const automatic = new Page();
automatic.tasks = tasks;
automatic.todayDate = '2026-09-25';
automatic.todayStudyOverride = { date: '2026-09-25', availableMinutes: 60 };
const overlayStates = [];
automatic.onBusinessOverlayChange = visible => { overlayStates.push(visible); };
automatic.openTodayAdjust();
assert.equal(automatic.draftPriorityMode, 'auto');
assert.deepEqual(overlayStates, [true], 'opening today adjust must suppress the floating hint');
let saved;
automatic.onAdjustToday = override => { saved = override; };
automatic.saveTodayAdjust();
assert.equal(saved.preferredTaskId, '', 'automatic arrangement must clear preferredTaskId');
assert.equal(automatic.tasks.length, 2, 'automatic arrangement cannot create a task');
assert.deepEqual(overlayStates, [true, false], 'closing today adjust must restore the floating layer');

const manual = new Page();
manual.tasks = tasks;
manual.todayDate = '2026-09-25';
manual.todayStudyOverride = { date: '2026-09-25', availableMinutes: 60 };
manual.openTodayAdjust();
manual.selectDraftTask(1);
assert.equal(manual.draftPriorityMode, 'manual');
manual.onAdjustToday = override => { saved = override; };
manual.saveTodayAdjust();
assert.equal(saved.preferredTaskId, 'english-1', 'manual priority preserves the real taskId');

manual.openTodayAdjust();
assert.equal(manual.draftPriorityMode, 'auto', 'parent state remains the source of truth until saved state returns');
manual.todayStudyOverride = { date: '2026-09-25', preferredTaskId: 'english-1', skippedTaskIds: [] };
manual.openTodayAdjust();
assert.equal(manual.draftPriorityMode, 'manual');
manual.draftPriorityMode = 'auto';
manual.draftTaskIndex = -1;
manual.saveTodayAdjust();
assert.equal(saved.preferredTaskId, '', 'switching back to automatic must remove the old preferredTaskId');

manual.todayStudyOverride = { date: '2026-09-25', preferredTaskId: 'math-1', skippedTaskIds: [] };
manual.openTodayAdjust();
manual.toggleDraftSkip(1);
assert.equal(manual.tasks[manual.draftTaskIndex].id, 'math-1',
  'skipping another task cannot change the preferred task');
assert.deepEqual(Array.from(manual.draftSkippedTaskIds), ['english-1']);

assert.ok(fullSource.includes('小星球自动安排'));
assert.ok(fullSource.includes('我指定一个待办优先'));
assert.ok(!fullSource.includes('不指定，交给小星球安排'));
assert.ok(fullSource.includes('this.adjustOpen = false;'), 'the existing adjust sheet flow remains in place');
const indexSource = fs.readFileSync(path.resolve(__dirname, '..', 'entry/src/main/ets/pages/Index.ets'), 'utf8');
assert.ok(indexSource.includes('return AgentDecisionService.decide(this.snapshot(), this.actionClock);'),
  'automatic arrangement must continue using AgentDecisionService');

console.log('PASS today adjust UX: automatic/manual semantics, real preferred taskId, independent skip and no new task');
