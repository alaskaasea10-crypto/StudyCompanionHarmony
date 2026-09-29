const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const now = new Date('2026-09-27T12:00:00+08:00').getTime();
const serviceBox = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(ets,
  'services/GoalPlanningService.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, serviceBox);
const GoalPlanningService = serviceBox.exports.GoalPlanningService;

const expired = { id: 'goal-english-expired', title: '大学英语考试', type: '考试', subject: '大学英语',
  deadline: '2026-09-23', estimatedMinutes: 180, completed: false, createdAt: 1 };
const future = { id: 'goal-math-future', title: '高等数学考试', type: '考试', subject: '高等数学',
  deadline: '2026-11-01', estimatedMinutes: 300, completed: false, createdAt: 2 };
const tomorrow = { id: 'goal-linear-tomorrow', title: '线性代数复习', type: '考试', subject: '线性代数',
  deadline: '2026-09-28', estimatedMinutes: 240, completed: false, createdAt: 3 };
const today = { id: 'goal-today', title: '数据结构作业', type: '课程', subject: '数据结构',
  deadline: '2026-09-27', estimatedMinutes: 120, completed: false, createdAt: 4 };
const storedGoals = [expired, future, tomorrow, today];

// Expired history remains persisted, while every current consumer gets one sorted active projection.
assert.deepEqual(GoalPlanningService.activeGoals(storedGoals, now).map(goal => goal.id),
  [today.id, tomorrow.id, future.id]);
assert.equal(storedGoals.length, 4);
assert.equal(storedGoals.some(goal => goal.id === expired.id), true);
assert.equal(GoalPlanningService.daysUntil(today.deadline, now), 0);
assert.equal(GoalPlanningService.daysUntil(tomorrow.deadline, now), 1);
assert.equal(GoalPlanningService.prioritize(storedGoals, [], now).goal.id, today.id);

// Restore/normalization keeps history but produces the same active projection after restart.
const restored = storedGoals.map(goal => GoalPlanningService.normalize(goal));
assert.deepEqual(GoalPlanningService.activeGoals(restored, now).map(goal => goal.id),
  [today.id, tomorrow.id, future.id]);
assert.equal(restored.some(goal => goal.id === expired.id), true);

const learningHub = fs.readFileSync(path.join(ets, 'pages/LearningHubPage.ets'), 'utf8');
const home = fs.readFileSync(path.join(ets, 'pages/HomePage.ets'), 'utf8');
const plan = fs.readFileSync(path.join(ets, 'pages/PlanPage.ets'), 'utf8');
const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const agent = fs.readFileSync(path.join(ets, 'services/AgentDecisionService.ets'), 'utf8');

// LearningHub no longer has a direct !completed-only goal path and previews only two active goals.
assert.match(learningHub, /GoalPlanningService\.activeGoals\(this\.academicGoals, this\.now\)\.slice\(0, 2\)/);
assert.equal(learningHub.includes('this.academicGoals.filter((goal: AcademicGoal) => !goal.completed)'), false);
assert.ok(learningHub.includes("Text('暂未设置学习目标')"));

// Reminder UI shares active-goal authority; execution and cloud ranking exclude reminders.
assert.ok(home.includes("'暂未设置学习目标'"));
assert.match(plan, /GoalPlanningService\.activeGoals\(this\.academicGoals, this\.now\)/);
assert.doesNotMatch(agent, /GoalPlanningService|daysUntil|deadline/);
assert.doesNotMatch(index.slice(index.indexOf('  private learningContextInput('),
  index.indexOf('  private setAgentPreview(')), /GoalPlanningService|goal\.deadline/);
assert.match(index, /academicGoals: \[\]/);

// Goal expiry must not remove or recreate executable tasks or identity-bearing objects.
const task = { id: 'task-english-stable', title: '完成英语作业', subject: '大学英语', minutes: 25,
  completed: false, source: 'manual', createdAt: 10, completedAt: 0, goalId: expired.id };
assert.equal(task.id, 'task-english-stable');
assert.equal(task.goalId, expired.id);
assert.equal(storedGoals[0].id, expired.id);

console.log('PASS active goal global consistency: expired history retained, current consumers share sorted active goals');
