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

const actions = load('LearningActionService').LearningActionService;
const decisions = load('AgentDecisionService').AgentDecisionService;
const overrides = load('TodayStudyOverrideService').TodayStudyOverrideService;
const deletion = load('StudyTaskDeletionService').StudyTaskDeletionService;
const day = '2026-09-25';
const at = time => new Date(`2026-09-25T${time}+08:00`).getTime();
const now = at('23:27:00');
const taskA = { id: 'real-a', title: '背公式', subject: '高等数学', minutes: 30,
  completed: false, source: 'manual' };
const taskB = { id: 'real-b', title: '完成阅读', subject: '大学英语', minutes: 25,
  completed: false, source: 'manual' };
const base = { profileCompleted: true, profileSubject: '高等数学', profileDailyMinutes: 60,
  energyState: '一般', studyDayKey: day, todayMinutes: 60, tasks: [taskA, taskB], currentTaskIndex: 0,
  scheduleItems: [], setupScheduleReady: false, academicGoals: [], focusRecords: [], quizAttempts: [],
  knowledgeMastery: [], remainingSeconds: 0, focusElapsedSeconds: 0, focusSegmentStartedAt: 0,
  focusSessionCredited: true, isRunning: false,
  todayStudyOverride: { date: day, availableMinutes: 60 } };

// 原总预算已用完，不做调整时保持 no-action。
assert.equal(actions.focusedMinutes(base, now), 60);
assert.equal(actions.budget(base, now), 0);
const exhausted = decisions.decide(base, now);
assert.equal(exhausted.recommendedAction.stage, 'wait');
assert.equal(exhausted.recommendedAction.headline, '今天原定安排已经完成');
assert.equal(exhausted.dailyPlan.length, 0);

// 用户说“接下来再学30分钟”：内部兼容为当天总预算90，真实剩余30。
const totalAfterAddingThirty = actions.totalBudgetForAdditional(base, 30, now);
assert.equal(totalAfterAddingThirty, 90);
const extended = { ...base, todayStudyOverride: { date: day, availableMinutes: totalAfterAddingThirty } };
assert.equal(actions.budget(extended, now), 30);
const extendedDecision = decisions.decide(extended, now);
assert.equal(extendedDecision.recommendedAction.stage, 'execute');
assert.equal(extendedDecision.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 30);
assert.equal(extendedDecision.recommendedAction.taskId, extendedDecision.dailyPlan[0].taskId);
assert.equal(new Set(extendedDecision.dailyPlan.map(item => item.taskId)).size, extendedDecision.dailyPlan.length);

// 同时指定真实待办只改排序，不更换任务身份。
const preferred = { ...extended, todayStudyOverride: { ...extended.todayStudyOverride,
  preferredTaskId: taskB.id } };
const preferredDecision = decisions.decide(preferred, now);
assert.equal(preferredDecision.recommendedAction.taskId, taskB.id);
assert.equal(preferredDecision.dailyPlan[0].taskId, taskB.id);
assert.equal(preferredDecision.dailyPlan[0].suggestedMinutes, 25);
assert.equal(preferred.tasks[1].id, taskB.id);

// 只选偏好但预算仍为0，不强制启动任务。
const preferenceWithoutTime = decisions.decide({ ...base,
  todayStudyOverride: { date: day, availableMinutes: 60, preferredTaskId: taskB.id } }, now);
assert.equal(preferenceWithoutTime.recommendedAction.stage, 'wait');
assert.equal(preferenceWithoutTime.dailyPlan.length, 0);

// completed / skipped 不能被偏好复活。
const completedPreferred = decisions.decide({ ...preferred,
  tasks: [taskA, { ...taskB, completed: true }] }, now);
assert.equal(completedPreferred.dailyPlan.some(item => item.taskId === taskB.id), false);
const skippedPreferred = decisions.decide({ ...preferred, todayStudyOverride: {
  ...preferred.todayStudyOverride, skippedTaskIds: [taskB.id] } }, now);
assert.equal(skippedPreferred.dailyPlan.some(item => item.taskId === taskB.id), false);

// ongoing focus / pending feedback 始终高于新的时间和偏好调整。
const ongoing = decisions.decide({ ...preferred, currentTaskIndex: 0, isRunning: true,
  focusSegmentStartedAt: now - 60000, focusSessionCredited: false, focusElapsedSeconds: 0,
  remainingSeconds: 29 * 60 }, now);
assert.equal(ongoing.recommendedAction.stage, 'resume');
assert.equal(ongoing.recommendedAction.taskId, taskA.id);
const pending = decisions.decide({ ...preferred, tasks: [{ ...taskA, outcome: 'focused' }, taskB] }, now);
assert.equal(pending.recommendedAction.stage, 'verify');
assert.equal(pending.recommendedAction.taskId, taskA.id);

// 增加预算不会制造候选：没有 eligible task 时进入真实空状态，不再误报时间用完。
const noEligible = decisions.decide({ ...extended,
  tasks: [{ ...taskA, completed: true }, { ...taskB, completed: true }] }, now);
assert.equal(noEligible.recommendedAction.stage, 'plan');
assert.notEqual(noEligible.recommendedAction.headline, '今天原定安排已经完成');
assert.equal(noEligible.dailyPlan.length, 0);

// 原有60→30 / 60→15 / 30→60重规划仍只使用原真实 taskId。
const fresh = { ...base, todayMinutes: 0, studyDayKey: day };
const planFor = minutes => decisions.decide({ ...fresh,
  todayStudyOverride: { date: day, availableMinutes: minutes } }, now);
const sixty = planFor(60);
const thirty = planFor(30);
const fifteen = planFor(15);
const sixtyAgain = planFor(60);
assert.equal(sixty.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 55);
assert.equal(thirty.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 30);
assert.equal(fifteen.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 15);
assert.deepEqual(Array.from(sixtyAgain.dailyPlan, item => item.taskId),
  Array.from(sixty.dailyPlan, item => item.taskId));
for (const plan of [sixty, thirty, fifteen, sixtyAgain]) {
  assert.equal(plan.dailyPlan.every(item => [taskA.id, taskB.id].includes(item.taskId)), true);
}

// 深夜不写死特殊分支；当天有效，北京时00:00旧 override 立即失效。
for (const time of ['23:27:00', '23:45:00', '23:50:00', '23:59:00']) {
  const moment = at(time);
  assert.equal(overrides.active(preferred, moment)?.preferredTaskId, taskB.id);
  assert.equal(decisions.decide(preferred, moment).recommendedAction.taskId, taskB.id);
}
const midnight = new Date('2026-09-26T00:00:00+08:00').getTime();
assert.equal(overrides.active(preferred, midnight), undefined);

// 删除偏好任务后仍清理悬空引用，不影响其他任务。
const removed = deletion.remove(taskB.id, preferred.tasks, preferred.todayStudyOverride, [], []);
assert.equal(removed.todayStudyOverride.preferredTaskId, '');
assert.equal(removed.tasks.some(item => item.id === taskB.id), false);
assert.equal(removed.tasks.some(item => item.id === taskA.id), true);

const actionSource = fs.readFileSync(path.join(root,
  'entry/src/main/ets/services/LearningActionService.ets'), 'utf8');
const focusSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
assert.ok(actionSource.includes('今天原定安排已经完成'));
assert.ok(actionSource.includes('还想继续？可以调整今天安排'));
assert.ok(focusSource.includes('this.resetFocus();'));
assert.ok(focusSource.includes('this.startTimer();'));
assert.ok(!actionSource.includes('hour == 23'));

console.log('PASS today budget hotfix: additional time, preferred identity, guards, late hours and rollover');
