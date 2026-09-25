const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const cache = new Map();

function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (cache.has(name)) return cache.get(name);
  const box = { exports: {}, console, require: input => input.startsWith('@kit.') ? {} : load(path.basename(input)) };
  const serviceFile = path.join(root, `entry/src/main/ets/services/${name}.ets`);
  const filename = fs.existsSync(serviceFile) ? serviceFile :
    path.join(root, `entry/src/main/ets/utils/${name}.ets`);
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const widget = load('StudyWidgetService').StudyWidgetService;
const decision = load('AgentDecisionService').AgentDecisionService;
const task = { id: 'task-1', title: '复习矩阵乘法', subject: '线性代数', minutes: 20,
  completed: false, source: 'manual' };
const snapshot = { profileCompleted: true, profileSubject: '线性代数', profileDailyMinutes: 60,
  profileExamDateConfirmed: false, academicGoals: [], tasks: [task], currentTaskIndex: 0,
  isRunning: false, remainingSeconds: 0, focusElapsedSeconds: 0, energyState: '一般',
  focusRecords: [], quizAttempts: [], scheduleItems: [], setupScheduleReady: false };

assert.equal(widget.fromSnapshot(snapshot).taskTitle, decision.decide(snapshot).recommendedAction.headline);
assert.equal(widget.fromSnapshot(snapshot).target, 'next');
assert.equal(widget.fromSnapshot({ ...snapshot, isRunning: true, remainingSeconds: 300 }).actionText,
  '回到专注');
assert.equal(widget.fromSnapshot({ ...snapshot, tasks: [{ ...task, outcome: 'focused' }],
  todayMinutes: 60, studyDayKey: new Date(Date.now() + 8 * 3600000).toISOString().substring(0, 10) })
  .actionText, '记录学习收获');
assert.equal(widget.fromSnapshot({ ...snapshot, tasks: [], currentTaskIndex: 0 }).actionText, '和 Agent 聊聊');
assert.equal(widget.fromSnapshot({ ...snapshot, profileCompleted: false }).target, 'home');
const internalSubject = widget.fromSnapshot({ ...snapshot,
  tasks: [{ ...task, title: '复习CollegeEnglish听力', subject: 'CollegeEnglish' }] });
assert.equal(internalSubject.subject, '大学英语');
assert.equal(internalSubject.taskTitle, '复习大学英语听力');
console.log('PASS widget: shares Agent decision, resumes focus, records results, handles empty plans and setup');
