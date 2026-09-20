const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  const filename = name === 'StudyModels' ? 'models/StudyModels.ets' :
    name === 'QuestionBankModels' ? 'models/QuestionBankModels.ets' : `services/${name}.ets`;
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets', filename), 'utf8');
  const box = { exports: {}, Date, console, require: input => load(path.basename(input)) };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const { AgentDecisionService: decisions } = load('AgentDecisionService');
const now = new Date('2026-09-20T10:00:00+08:00').getTime();
const task = { id: 't1', title: '整理矩阵乘法', subject: '线性代数', minutes: 25,
  completed: false, source: 'profile' };
const base = { profileCompleted: true, profileSubject: '线性代数', profileDailyMinutes: 60,
  profileExamDate: '2026-10-04', profileExamDateConfirmed: false, energyState: '一般',
  studyDayKey: '2026-09-20', todayMinutes: 0, tasks: [task], currentTaskIndex: 0,
  scheduleItems: [{ id: 'demo-math', weekday: 7, startTime: '09:00', endTime: '11:00',
    course: '演示课', location: '' }], setupScheduleReady: true,
  academicGoals: [{ id: 'g1', title: '线性代数考试', subject: '线性代数',
    deadline: '2026-10-04', completed: false, createdAt: now }],
  focusRecords: [], quizAttempts: [], knowledgeMastery: [], remainingSeconds: 0,
  focusElapsedSeconds: 0, isRunning: false };

const initial = decisions.decide(base, now);
assert.equal(initial.recommendedAction.stage, 'execute');
assert.equal(initial.confidenceLevel, '依据有限');
assert.equal(initial.evidence.some(item => item.label === '已确认考试日期'), false);
assert.equal(initial.evidence.some(item => item.label === '课表空档'), false);
assert.equal(initial.status.weakPointCount, undefined);
assert.equal(initial.status.recentTrend, '记录不足，暂不判断趋势');

const confirmed = decisions.decide({ ...base, profileExamDateConfirmed: true }, now);
assert.equal(confirmed.evidence.some(item => item.label === '已确认考试日期' && item.value === '还有14天'), true);
assert.equal(decisions.decide({ ...base, profileExamDate: '2026-02-31',
  profileExamDateConfirmed: true }, now).evidence.some(item => item.label === '已确认考试日期'), false);

const actualClass = { id: 'imported-class', weekday: 7, startTime: '09:00', endTime: '11:00',
  course: '数学', location: '' };
const inClass = decisions.decide({ ...base, scheduleItems: [actualClass] }, now);
assert.equal(inClass.recommendedAction.stage, 'wait');
assert.equal(inClass.evidence.some(item => item.label === '课表空档'), true);

const manualTask = { ...task, id: 'manual-1', title: '复习特征值', source: 'manual-adjustment' };
const selected = decisions.decide({ ...base, tasks: [task, manualTask], preferredTaskId: manualTask.id }, now);
assert.equal(selected.recommendedAction.headline, manualTask.title);
assert.equal(selected.priority, '优先处理');
assert.equal(selected.reasonChain[0].data.includes('设为了当前安排'), true);

const focused = decisions.decide({ ...base, tasks: [{ ...task, outcome: 'focused', focusedAt: now }] }, now);
assert.equal(focused.recommendedAction.stage, 'verify');
assert.equal(focused.reasonChain[0].judgment, '先确认这次学习的结果');
assert.equal(decisions.decide({ ...base, tasks: [{ ...task, outcome: 'focused', focusedAt: now }],
  todayMinutes: 60 }, now).recommendedAction.stage, 'verify');
const deferred = decisions.decide({ ...base, actionDeferrals: [{ key: 'task:t1',
  until: now + 1800000, kind: 'later' }] }, now);
assert.equal(deferred.recommendedAction.stage, 'wait');
assert.equal(deferred.reasonChain[0].data, '当前建议已被暂缓');
assert.equal(decisions.decide({ ...base, studyDayKey: '2026-09-19', todayMinutes: 60 }, now)
  .status.remainingGoalMinutes, 60);
console.log('PASS Agent decision: confirmed evidence, missing data, demo exclusion, manual choice, result state, day rollover');
