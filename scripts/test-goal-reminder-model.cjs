const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const now = new Date('2026-09-27T12:00:00+08:00').getTime();
class FixedDate extends Date {
  constructor(...args) { super(...(args.length > 0 ? args : [now])); }
  static now() { return now; }
}
const cache = new Map();
function evaluate(source, extra = {}) {
  const box = { exports: {}, Date: FixedDate, console, ...extra };
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  }}).outputText, box);
  return box.exports;
}
function load(name) {
  if (cache.has(name)) return cache.get(name);
  const candidates = [path.join(ets, `services/${name}.ets`), path.join(ets, `utils/${name}.ets`)];
  const file = candidates.find(candidate => fs.existsSync(candidate));
  if (!file) return {};
  const loaded = evaluate(fs.readFileSync(file, 'utf8'), {
    require: request => load(path.basename(request).replace(/\.ets$/, ''))
  });
  cache.set(name, loaded);
  return loaded;
}

const GoalPlanningService = load('GoalPlanningService').GoalPlanningService;
const LearningActionService = load('LearningActionService').LearningActionService;
const TaskOutcomeService = load('TaskOutcomeService').TaskOutcomeService;
const ProfileCompletionService = load('ProfileCompletionService').ProfileCompletionService;
const future = { id: 'goal-math', title: '高等数学考试', type: '考试', subject: '高等数学',
  deadline: '2026-09-28', estimatedMinutes: 300, completed: false, createdAt: 1 };
const expired = { id: 'goal-english', title: '大学英语考试', type: '考试', subject: '大学英语',
  deadline: '2026-09-26', estimatedMinutes: 300, completed: false, createdAt: 2 };
const task = { id: 'task-math-stable', title: '巩固基本求导规则', subject: '高等数学', minutes: 25,
  completed: false, source: 'manual', createdAt: 3, completedAt: 0, goalId: future.id };

// A-D: future/current reminders are deadline driven, expired history persists but is not active.
const storedGoals = [expired, future];
const priority = GoalPlanningService.prioritize(storedGoals, [task], now);
assert.equal(priority.goal.id, future.id);
assert.equal(priority.reason, '还有1天');
assert.deepEqual(GoalPlanningService.activeGoals(storedGoals, now).map(goal => goal.id), [future.id]);
assert.equal(storedGoals.length, 2, 'filtering an expired goal must not delete it from persistence');
assert.equal(GoalPlanningService.prioritize([future], [{ ...task, completed: true }], now).goal.id, future.id,
  'a future reminder must remain active even when every task is complete');
assert.equal(GoalPlanningService.prioritize([{ ...future, completed: true }], [], now).goal.id, future.id,
  'a legacy milestone-completion flag must not hide a future reminder');

const indexSource = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const planPage = fs.readFileSync(path.join(ets, 'pages/PlanPage.ets'), 'utf8');
const homePage = fs.readFileSync(path.join(ets, 'pages/HomePage.ets'), 'utf8');

// E-G/K-M: real feedback changes the same task only; goals no longer advance or create tasks.
const recordStart = indexSource.indexOf('  private recordTaskResult(');
const recordEnd = indexSource.indexOf('  private submitSelfResult()', recordStart);
assert.ok(recordStart >= 0 && recordEnd > recordStart);
const Harness = evaluate(`class Harness {
  tasks = []; academicGoals = []; todayStudyOverride = { date: '' }; preferredTaskId = '';
  actionDeferrals = []; persisted = 0; persistSilently() { this.persisted++; }
  ${indexSource.slice(recordStart, recordEnd)}
} exports.Harness = Harness;`, { TaskOutcomeService }).Harness;
const focused = TaskOutcomeService.focused(task, now - 60000);
const harness = new Harness();
harness.tasks = [focused]; harness.academicGoals = [future, expired];
const idsBefore = harness.tasks.map(item => item.id);
const goalsBefore = harness.academicGoals.map(goal => goal.id);
harness.recordTaskResult(0, true, '', 'normal');
assert.equal(harness.tasks.length, 1);
assert.deepEqual(harness.tasks.map(item => item.id), idsBefore);
assert.deepEqual(harness.academicGoals.map(goal => goal.id), goalsBefore);
assert.equal(harness.tasks[0].completed, true);
assert.equal(indexSource.includes('ensureGoalMilestoneTask'), false);
assert.equal(indexSource.includes('advanceGoalMilestone'), false);
assert.equal(indexSource.includes('GoalPlanningService.taskFor'), false);

// H/J: candidates are only existing StudyTasks; Today override can still prioritize a real stable taskId.
const other = { id: 'task-english-stable', title: '完成英语作业', subject: '大学英语', minutes: 20,
  completed: false, source: 'manual', createdAt: 4, completedAt: 0 };
const snapshot = { profileSubject: '高等数学', profileDailyMinutes: 60, tasks: [task, other],
  academicGoals: [future, expired], scheduleItems: [], setupScheduleReady: false, focusRecords: [],
  currentTaskIndex: 0, isRunning: false, remainingSeconds: 0, focusElapsedSeconds: 0,
  todayMinutes: 0, studyDayKey: '2026-09-27', energyState: '一般',
  todayStudyOverride: { date: '2026-09-27', availableMinutes: 30, preferredTaskId: other.id } };
const candidates = LearningActionService.candidates(snapshot, now);
assert.equal(JSON.stringify(candidates.map(item => item.task.id).sort()),
  JSON.stringify([task.id, other.id].sort()));
assert.equal(candidates[0].task.id, other.id);
assert.equal(LearningActionService.decide(snapshot, [], now).taskId, other.id);

// I: AcademicGoal remains in local snapshots, excluded from planning context.
assert.ok(indexSource.includes('academicGoals: this.academicGoals'));
assert.ok(indexSource.includes('academicGoals: []'));
assert.ok(indexSource.includes('GoalPlanningService.prioritize(this.academicGoals'));

// UI: no expired goal in the main list and no task/milestone management in the goal center.
assert.ok(planPage.includes('ForEach(this.currentGoals()'));
assert.ok(planPage.includes('暂无进行中的学习目标'));
for (const text of ['关联任务', '完成情况', '按阶段推进', '查看阶段', '收起阶段']) {
  assert.equal(planPage.includes(text), false);
}
assert.ok(homePage.includes("'暂未设置学习目标'"));

// N: first-launch gate remains explicit and legacy migration still requires real saved learning evidence.
const completeProfile = { profileName: '小林', profileMajor: '计算机科学与技术', profileSubject: '高等数学',
  profileExamDate: '2026-09-28', profileDailyMinutes: 60, profilePreferredTime: '晚间',
  academicGoals: [future], tasks: [task] };
assert.equal(ProfileCompletionService.completed({ ...completeProfile, profileCompleted: false }), false);
assert.equal(ProfileCompletionService.completed({ ...completeProfile, profileCompleted: true }), true);
assert.equal(ProfileCompletionService.completed(completeProfile), true);

console.log('PASS goal reminder model: deadline-only active goals, no milestone task generation, stable task flow and profile gate');
