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

const { AgentDecisionService: decisions } = load('AgentDecisionService');
const { LearningActionService: actions } = load('LearningActionService');
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
assert.equal(initial.dailyPlan.length, 1);
assert.equal(initial.dailyPlan[0].taskId, task.id);
assert.equal(initial.dailyPlan[0].suggestedMinutes, 25);
assert.equal(initial.dailyPlan[0].evidence[0].source, '建档时保存的初始建议');

const linearLater = { id: 'linear-2', title: '整理线性代数笔记', subject: '线性代数',
  minutes: 20, completed: false, source: 'manual' };
const calculus = { id: 'calculus-1', title: '练习导数', subject: '高等数学',
  minutes: 20, completed: false, source: 'manual' };
const english = { id: 'english-1', title: '完成英语阅读', subject: '大学英语',
  minutes: 20, completed: false, source: 'manual' };
const multi = { ...base, tasks: [task, linearLater, calculus, english],
  todayStudyOverride: { date: '2026-09-20', availableMinutes: 60 } };
const originalTasks = JSON.stringify(multi.tasks);
const multiPlan = decisions.decide(multi, now);
assert.deepEqual(Array.from(multiPlan.dailyPlan, item => item.taskId), ['t1', 'linear-2', 'calculus-1']);
assert.deepEqual(Array.from(multiPlan.dailyPlan, item => item.suggestedMinutes), [25, 20, 15]);
assert.deepEqual(Array.from(multiPlan.dailyPlan, item => item.order), [1, 2, 3]);
assert.equal(multiPlan.dailyPlan.every(item => item.evidence.length > 0 &&
  item.evidence[0].value.includes('尚未完成')), true);
assert.equal(multiPlan.dailyPlan[2].evidence.some(item => item.label === '建议时长' &&
  item.value === '15分钟' && item.source === '任务原定时长与今日可安排时间'), true);
assert.equal(JSON.stringify(multi.tasks), originalTasks);
assert.equal(multiPlan.dailyPlan.some(item => item.evidence.some(evidence =>
  evidence.value.includes('2026-10-04'))), false);
const resuming = decisions.decide({ ...multi, isRunning: true, focusSegmentStartedAt: now - 60000,
  focusMinutes: 25, focusElapsedSeconds: 0, remainingSeconds: 24 * 60 }, now);
assert.equal(resuming.recommendedAction.stage, 'resume');
assert.equal(resuming.dailyPlan[0].taskId, task.id);
assert.equal(resuming.dailyPlan[0].suggestedMinutes, 24);
const afterCompletion = decisions.decide({ ...multi,
  tasks: [{ ...task, completed: true }, linearLater, calculus, english] }, now);
assert.equal(afterCompletion.dailyPlan.some(item => item.taskId === task.id), false);
assert.equal(decisions.decide({ ...base, tasks: [] }, now).dailyPlan.length, 0);

const confirmed = decisions.decide({ ...base, profileExamDateConfirmed: true }, now);
assert.equal(confirmed.evidence.some(item => item.label === '已确认考试日期' && item.value === '还有14天'), true);
assert.equal(decisions.decide({ ...base, profileExamDate: '2026-02-31',
  profileExamDateConfirmed: true }, now).evidence.some(item => item.label === '已确认考试日期'), false);

const actualClass = { id: 'imported-class', weekday: 7, startTime: '09:00', endTime: '11:00',
  course: '数学', location: '' };
const inClass = decisions.decide({ ...base, scheduleItems: [actualClass] }, now);
assert.equal(inClass.recommendedAction.stage, 'wait');
assert.equal(inClass.evidence.some(item => item.label === '课表空档'), true);
assert.equal(inClass.dailyPlan.length, 0);

const manualTask = { ...task, id: 'manual-1', title: '复习特征值', source: 'manual-adjustment' };
const selected = decisions.decide({ ...base, tasks: [task, manualTask],
  todayStudyOverride: { date: '2026-09-20', preferredTaskId: manualTask.id } }, now);
assert.equal(selected.recommendedAction.headline, manualTask.title);
assert.equal(selected.priority, '优先处理');
assert.equal(selected.reasonChain[0].data.includes('设为了当前安排'), true);
assert.equal(selected.dailyPlan[0].taskId, manualTask.id);
assert.equal(selected.dailyPlan[0].evidence.some(item => item.source === '手动调整'), true);

const focused = decisions.decide({ ...base, tasks: [{ ...task, outcome: 'focused', focusedAt: now }] }, now);
assert.equal(focused.recommendedAction.stage, 'verify');
assert.equal(focused.reasonChain[0].judgment, '先确认这次学习的结果');
assert.equal(focused.dailyPlan.length, 1);
assert.equal(focused.dailyPlan[0].taskId, task.id);
assert.equal(focused.dailyPlan[0].suggestedMinutes, 0);
assert.equal(decisions.decide({ ...base, tasks: [{ ...task, outcome: 'focused', focusedAt: now }],
  todayMinutes: 60 }, now).recommendedAction.stage, 'verify');
const deferred = decisions.decide({ ...base, actionDeferrals: [{ key: 'task:t1',
  until: now + 1800000, kind: 'later' }] }, now);
assert.equal(deferred.recommendedAction.stage, 'wait');
assert.equal(deferred.reasonChain[0].data, '当前建议已被暂缓');
assert.equal(deferred.dailyPlan.length, 0);
assert.equal(decisions.decide({ ...base, studyDayKey: '2026-09-19', todayMinutes: 60 }, now)
  .status.remainingGoalMinutes, 60);
// 同一个候选排序同时驱动当前行动与今日节奏；不依赖模型生成多科任务。
const math = { id: 'math-real', title: '完成高数复习', subject: '高等数学', minutes: 25,
  completed: false, goalId: 'goal-math' };
const englishReal = { id: 'english-real', title: '完成英语阅读', subject: '大学英语', minutes: 20,
  completed: false, goalId: 'goal-english' };
const linearReal = { id: 'linear-real', title: '整理线代笔记', subject: '线性代数', minutes: 15,
  completed: false, goalId: 'goal-linear' };
const goals = [
  { id: 'goal-math', title: '高数期末', subject: '高等数学', deadline: '2026-09-21', completed: false },
  { id: 'goal-english', title: '英语作业', subject: '大学英语', deadline: '2026-09-24', completed: false },
  { id: 'goal-linear', title: '线代章节', subject: '线性代数', deadline: '2026-09-28', completed: false }
];
const today = { date: '2026-09-20', availableMinutes: 90 };
const realSubjects = { ...base, tasks: [englishReal, linearReal, math], academicGoals: goals,
  todayStudyOverride: today };
const unchanged = JSON.stringify(realSubjects.tasks);
const scheduled = decisions.decide(realSubjects, now);
assert.deepEqual(Array.from(scheduled.dailyPlan, item => item.taskId),
  ['math-real', 'english-real', 'linear-real']);
assert.equal(scheduled.recommendedAction.taskId, scheduled.dailyPlan[0].taskId);
assert.equal(new Set(scheduled.dailyPlan.map(item => item.taskId)).size, scheduled.dailyPlan.length);
assert.equal(JSON.stringify(realSubjects.tasks), unchanged);
const sixtyMinutePlan = decisions.decide({ ...realSubjects,
  todayStudyOverride: { date: '2026-09-20', availableMinutes: 60 } }, now);
assert.deepEqual(Array.from(sixtyMinutePlan.dailyPlan, item => item.taskId),
  ['math-real', 'english-real', 'linear-real']);
assert.equal(sixtyMinutePlan.recommendedAction.taskId, sixtyMinutePlan.dailyPlan[0].taskId);
assert.equal(sixtyMinutePlan.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 60);
const thirtyMinutePlan = decisions.decide({ ...realSubjects,
  todayStudyOverride: { date: '2026-09-20', availableMinutes: 30 } }, now);
assert.deepEqual(Array.from(thirtyMinutePlan.dailyPlan, item => item.taskId),
  ['math-real', 'english-real']);
assert.equal(thirtyMinutePlan.recommendedAction.taskId, thirtyMinutePlan.dailyPlan[0].taskId);
assert.equal(thirtyMinutePlan.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 30);
assert.equal(thirtyMinutePlan.dailyPlan[0].taskId, sixtyMinutePlan.dailyPlan[0].taskId,
  'changing the confirmed budget must not replace the real StudyTask id');
const realTaskIds = new Set(realSubjects.tasks.map(item => item.id));
assert.equal(thirtyMinutePlan.dailyPlan.every(item => realTaskIds.has(item.taskId)), true,
  'a smaller budget may only retain real existing StudyTask ids');
const fifteenMinutePlan = decisions.decide({ ...realSubjects,
  todayStudyOverride: { date: '2026-09-20', availableMinutes: 15 } }, now);
assert.equal(fifteenMinutePlan.dailyPlan.length, 1);
assert.equal(fifteenMinutePlan.recommendedAction.taskId, fifteenMinutePlan.dailyPlan[0].taskId);
assert.equal(fifteenMinutePlan.dailyPlan[0].suggestedMinutes, 15);
assert.equal(realTaskIds.has(fifteenMinutePlan.dailyPlan[0].taskId), true,
  'the 15-minute action must be a shortened real task, not a demo task');
const expandedAgain = decisions.decide({ ...realSubjects,
  todayStudyOverride: { date: '2026-09-20', availableMinutes: 60 } }, now);
assert.deepEqual(Array.from(expandedAgain.dailyPlan, item => item.taskId),
  Array.from(sixtyMinutePlan.dailyPlan, item => item.taskId));
assert.equal(expandedAgain.dailyPlan.some(item =>
  !thirtyMinutePlan.dailyPlan.some(shortItem => shortItem.taskId === item.taskId)), true,
  'raising 30 minutes back to 60 may restore other real candidates');
assert.equal(JSON.stringify(realSubjects.tasks), unchanged,
  '60 -> 30 -> 15 -> 60 replanning must not create or mutate StudyTask data');
const finishedMath = decisions.decide({ ...realSubjects,
  tasks: [englishReal, linearReal, { ...math, completed: true }] }, now);
assert.equal(finishedMath.recommendedAction.taskId, 'english-real');
assert.equal(finishedMath.dailyPlan.some(item => item.taskId === math.id), false);
const preferredEnglish = decisions.decide({ ...realSubjects,
  todayStudyOverride: { ...today, preferredTaskId: englishReal.id } }, now);
assert.equal(preferredEnglish.recommendedAction.taskId, englishReal.id);
assert.equal(preferredEnglish.dailyPlan[0].taskId, englishReal.id);
const nextDay = now + 86400000;
const expired = decisions.decide({ ...realSubjects,
  todayStudyOverride: { ...today, preferredTaskId: englishReal.id } }, nextDay);
assert.equal(expired.recommendedAction.taskId, math.id);
const unknownTime = decisions.decide({ ...realSubjects,
  todayStudyOverride: { date: '2026-09-20' } }, now);
assert.equal(unknownTime.dailyPlan.length, 1);
assert.equal(actions.freeMinutes(realSubjects, now), undefined);
const ongoing = decisions.decide({ ...realSubjects, currentTaskIndex: 1, isRunning: true,
  remainingSeconds: 600, focusSegmentStartedAt: now - 1000,
  todayStudyOverride: { ...today, availableMinutes: 15, preferredTaskId: math.id } }, now);
assert.equal(ongoing.recommendedAction.stage, 'resume');
assert.equal(ongoing.recommendedAction.taskId, linearReal.id);
assert.equal(ongoing.dailyPlan[0].taskId, linearReal.id);
const pending = decisions.decide({ ...realSubjects,
  tasks: [englishReal, { ...linearReal, outcome: 'focused' }, math],
  todayStudyOverride: { ...today, availableMinutes: 15, preferredTaskId: math.id } }, now);
assert.equal(pending.recommendedAction.stage, 'verify');
assert.equal(pending.recommendedAction.taskId, linearReal.id);
assert.equal(pending.dailyPlan[0].taskId, linearReal.id);
const temporary = { id: 'today-only', title: '临时整理课堂笔记', subject: '大学英语',
  minutes: 15, completed: false, source: 'today-temporary' };
const withTemporary = { ...realSubjects, tasks: [englishReal, linearReal, math, temporary],
  todayStudyOverride: { ...today, temporaryTaskIds: [temporary.id], preferredTaskId: temporary.id } };
assert.equal(decisions.decide(withTemporary, now).recommendedAction.taskId, temporary.id);
assert.equal(decisions.decide(withTemporary, nextDay).dailyPlan.some(item => item.taskId === temporary.id), false);
const skipped = decisions.decide({ ...realSubjects,
  todayStudyOverride: { ...today, skippedTaskIds: [math.id] } }, now);
assert.equal(skipped.dailyPlan.some(item => item.taskId === math.id), false);
assert.equal(decisions.decide({ ...realSubjects,
  todayStudyOverride: { ...today, availableMinutes: 0 } }, now).recommendedAction.stage, 'wait');
const delayed = decisions.decide({ ...realSubjects, actionDeferrals: [
  { key: `task:${math.id}`, until: now + 1800000, kind: 'later' }] }, now);
assert.equal(delayed.dailyPlan.some(item => item.taskId === math.id), false);
// 真正执行首页调整方法，确认改偏好不会改旧任务 ID 或中断专注；临时任务只创建一次。
const indexSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const adjustMethod = indexSource.slice(indexSource.indexOf('  private adjustTodayTask('),
  indexSource.indexOf('  private recordTaskResult('));
const adjustmentBox = { exports: {}, Date, console, LearningActionService: actions };
vm.runInNewContext(ts.transpileModule(`class AdjustmentHarness {
  tasks = []; todayStudyOverride = { date: '' }; preferredTaskId = ''; actionDeferrals = [];
  isRunning = true; focusElapsedSeconds = 30; currentTaskIndex = 0; persistCount = 0;
  profileSubject = '线性代数'; profileDailyMinutes = 60; actionClock = 0; actionMessage = '';
  studyDayKey = '2026-09-20'; todayMinutes = 0; focusRecords = []; quizAttempts = [];
  remainingSeconds = 0; focusSegmentStartedAt = 0; focusSessionCredited = true;
  energyState = '一般'; agentRequestId = 0; agentLoading = true; agentGenerated = true;
  beijingDayKey() { return '2026-09-20'; }
  snapshot() { return {
    tasks: this.tasks, profileDailyMinutes: this.profileDailyMinutes, studyDayKey: this.studyDayKey,
    todayMinutes: this.todayMinutes, focusRecords: this.focusRecords, quizAttempts: this.quizAttempts,
    isRunning: this.isRunning, focusElapsedSeconds: this.focusElapsedSeconds,
    focusSegmentStartedAt: this.focusSegmentStartedAt, focusSessionCredited: this.focusSessionCredited,
    remainingSeconds: this.remainingSeconds, energyState: this.energyState,
    todayStudyOverride: this.todayStudyOverride
  }; }
  persistSilently() { this.persistCount++; }
  ${adjustMethod}
} exports.AdjustmentHarness = AdjustmentHarness;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, adjustmentBox);
const adjustment = new adjustmentBox.exports.AdjustmentHarness();
adjustment.tasks = [math, englishReal];
adjustment.adjustTodayTask({ date: '2026-09-20', preferredTaskId: englishReal.id,
  availableMinutes: 60 }, '', '', 25);
assert.deepEqual(Array.from(adjustment.tasks, item => item.id), [math.id, englishReal.id]);
assert.equal(adjustment.isRunning, true);
assert.equal(adjustment.focusElapsedSeconds, 30);
assert.equal(adjustment.currentTaskIndex, 0);
assert.equal(adjustment.todayStudyOverride.preferredTaskId, englishReal.id);
const idsBeforeBudgetOnlyChange = JSON.stringify(adjustment.tasks.map(item => item.id));
adjustment.adjustTodayTask({ date: '2026-09-20', availableMinutes: 30 }, '', '', 25);
assert.equal(adjustment.todayStudyOverride.availableMinutes, 30);
assert.equal(JSON.stringify(adjustment.tasks.map(item => item.id)), idsBeforeBudgetOnlyChange,
  'saving a budget-only override must not create or replace StudyTask ids');
assert.equal(adjustment.isRunning, true,
  'changing the budget must not interrupt an ongoing focus session');
adjustment.adjustTodayTask({ date: '2026-09-20', availableMinutes: 60 },
  '临时整理课堂笔记', '大学英语', 15);
assert.equal(adjustment.tasks.length, 3);
const stableTemporaryId = adjustment.tasks[2].id;
assert.equal(adjustment.todayStudyOverride.temporaryTaskIds[0], stableTemporaryId);
adjustment.adjustTodayTask({ date: '2026-09-20', availableMinutes: 60 }, '', '', 15);
assert.equal(adjustment.tasks.length, 3);
assert.equal(adjustment.tasks[2].id, stableTemporaryId);
// 页面输入的是“从现在起追加的时长”；已专注60分钟后输入30，底层兼容字段保存总预算90。
adjustment.isRunning = false;
adjustment.todayMinutes = 0;
adjustment.focusRecords = [
  { dayKey: new Date(Date.now() + 8 * 3600000).toISOString().substring(0, 10), elapsedSeconds: 3600 },
  { dayKey: '2026-09-20', elapsedSeconds: 3600 }
];
adjustment.focusElapsedSeconds = 0;
adjustment.adjustTodayTask({ date: '2026-09-20', availableMinutes: 30,
  preferredTaskId: englishReal.id }, '', '', 25);
assert.equal(adjustment.todayStudyOverride.availableMinutes, 90);
assert.equal(adjustment.todayStudyOverride.preferredTaskId, englishReal.id);
assert.equal(actions.budget(adjustment.snapshot(), now), 30);
assert.equal(adjustment.agentLoading, false);
assert.equal(adjustment.agentGenerated, false);
assert.ok(adjustment.agentRequestId > 0);
assert.equal(indexSource.includes('ensureGoalMilestoneTask'), false);
assert.equal(indexSource.includes('advanceGoalMilestone'), false);
assert.equal(indexSource.includes('GoalPlanningService.taskFor'), false);
console.log('PASS Agent decision: evidence, confirmed-time plan, budget, no mutation, state safety');
