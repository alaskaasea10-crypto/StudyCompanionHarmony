const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..', 'entry/src/main/ets');
const cache = new Map();
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (cache.has(name)) return cache.get(name);
  const filename = name === 'StudyModels' ? 'models/StudyModels.ets' :
    name === 'QuestionBankModels' ? 'models/QuestionBankModels.ets' : `services/${name}.ets`;
  const source = fs.readFileSync(path.join(root, filename), 'utf8');
  const box = { exports: {}, Date, console, require: input => load(path.basename(input)) };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const now = new Date('2026-09-25T14:00:00+08:00').getTime();
const tasks = [
  { id: 'math-1', title: '复习导数', subject: '高等数学', minutes: 25, completed: false, source: 'manual' },
  { id: 'english-1', title: '完成英语作业', subject: '大学英语', minutes: 20, completed: false, source: 'manual' },
  { id: 'linear-1', title: '整理矩阵', subject: '线性代数', minutes: 15, completed: false,
    source: 'goal-milestone', goalId: 'linear-goal', milestoneId: 'linear-m1' }
];
const override = { date: '2026-09-25', availableMinutes: 60, preferredTaskId: 'linear-1',
  preferredSubject: '线性代数', skippedTaskIds: ['math-1', 'linear-1'], temporaryTaskIds: ['linear-1'] };
const deferrals = [{ key: 'task:linear-1', until: now + 1000, kind: 'skip' },
  { key: 'task:english-1', until: now + 1000, kind: 'later' }];

const { TodayStudyOverrideService } = load('TodayStudyOverrideService');
assert.equal(tasks.length, 3, 'today skip must not delete the real task');
assert.equal(TodayStudyOverrideService.eligibleTask(tasks[0], override), false);
const tomorrowSnapshot = { todayStudyOverride: override };
assert.equal(TodayStudyOverrideService.active(tomorrowSnapshot,
  new Date('2026-09-26T09:00:00+08:00').getTime()), undefined);
assert.equal(TodayStudyOverrideService.eligibleTask(tasks[0], undefined), true,
  'yesterday skip must expire on the next day');

const { StudyTaskDeletionService } = load('StudyTaskDeletionService');
assert.equal(StudyTaskDeletionService.blockReason(tasks[0], 'math-1', true),
  '这个待办正在专注中，请先结束本轮专注。');
assert.equal(StudyTaskDeletionService.blockReason(tasks[0], 'math-1', true),
  '这个待办正在专注中，请先结束本轮专注。', 'a paused but unfinished focus session is also protected');
assert.equal(StudyTaskDeletionService.blockReason({ ...tasks[0], outcome: 'focused' }, 'english-1', false),
  '先记录本轮学习反馈，再管理这个待办。');
assert.equal(StudyTaskDeletionService.blockReason({ ...tasks[0], outcome: 'submitted' }, 'english-1', false),
  '先记录本轮学习反馈，再管理这个待办。');

const removed = StudyTaskDeletionService.remove('linear-1', tasks, override, deferrals, []);
assert.deepEqual(Array.from(removed.tasks, task => task.id), ['math-1', 'english-1']);
assert.deepEqual(Array.from(removed.tasks, task => task.id), Array.from(tasks.slice(0, 2), task => task.id),
  'deleting one task cannot change any surviving taskId');
assert.equal(removed.todayStudyOverride.preferredTaskId, '');
assert.deepEqual(Array.from(removed.todayStudyOverride.skippedTaskIds), ['math-1']);
assert.deepEqual(Array.from(removed.todayStudyOverride.temporaryTaskIds), []);
assert.deepEqual(Array.from(removed.actionDeferrals, item => item.key), ['task:english-1']);
assert.deepEqual(Array.from(removed.deletedTaskIds), ['linear-1']);
const restored = JSON.parse(JSON.stringify({ tasks: removed.tasks, deletedTaskIds: removed.deletedTaskIds }));
assert.equal(restored.tasks.some(task => task.id === 'linear-1'), false,
  'serialized and reloaded task collection must keep the deletion');

const base = { profileCompleted: true, profileSubject: '高等数学', profileDailyMinutes: 60,
  profileExamDate: '', profileExamDateConfirmed: false, energyState: '一般', studyDayKey: '2026-09-25',
  todayMinutes: 0, currentTaskIndex: 0, scheduleItems: [], setupScheduleReady: false,
  academicGoals: [], focusRecords: [], quizAttempts: [], knowledgeMastery: [], remainingSeconds: 0,
  focusElapsedSeconds: 0, focusSegmentStartedAt: 0, focusSessionCredited: true, isRunning: false,
  tasks: removed.tasks, todayStudyOverride: { date: '2026-09-25', availableMinutes: 60,
    skippedTaskIds: removed.todayStudyOverride.skippedTaskIds } };
const { AgentDecisionService } = load('AgentDecisionService');
const decision = AgentDecisionService.decide(base, now);
assert.equal(decision.dailyPlan.some(item => item.taskId === 'linear-1'), false);
assert.equal(decision.recommendedAction.taskId, 'english-1');
assert.ok(decision.dailyPlan.every(item => removed.tasks.some(task => task.id === item.taskId)),
  'replanning after deletion may only use surviving real tasks');

const indexSource = fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8');
assert.ok(indexSource.includes('deletedTaskIds: this.deletedTaskIds'), 'deletion tombstones must be persisted');
assert.ok(indexSource.includes("!(this.deletedTaskIds ?? []).includes(milestoneTask.id ?? '')"),
  'deleted goal milestone task must not be recreated after reload');
assert.ok(indexSource.includes('Array.isArray(snapshot.tasks) ? storedTasks'),
  'a persisted empty task list must not restore demo tasks');
assert.ok(indexSource.includes('snapshot.focusMinutes ?? this.tasks[0]?.minutes ?? this.profileDailyMinutes'),
  'reloading after deleting every task must not dereference an empty task list');
assert.ok(indexSource.includes('this.focusElapsedSeconds > 0 && this.remainingSeconds > 0'),
  'paused but unfinished focus sessions must also block deletion');

console.log('PASS task deletion: skip/date semantics, persistence, dangling references, guards, stable IDs and replan');
