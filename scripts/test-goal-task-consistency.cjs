const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const box = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(ets,
  'services/GoalPlanningService.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, box);
const GoalPlanningService = box.exports.GoalPlanningService;

const now = new Date('2026-09-27T12:00:00+08:00').getTime();
const future = { id: 'goal-math', title: '高等数学考试', type: '考试', subject: '高等数学',
  deadline: '2026-09-28', estimatedMinutes: 300, completed: false, createdAt: now - 86400000 };
const expired = { ...future, id: 'goal-english', title: '大学英语考试', subject: '大学英语',
  deadline: '2026-09-26' };
const tasks = [
  { id: 'task-stable-1', title: '巩固求导', subject: '高等数学', minutes: 25, completed: false,
    goalId: future.id, milestoneId: 'legacy-m1', source: 'goal-milestone', createdAt: 1 },
  { id: 'task-stable-2', title: '整理英语作业', subject: '大学英语', minutes: 20, completed: true,
    goalId: expired.id, milestoneId: 'legacy-m1', source: 'goal-milestone', createdAt: 2 }
];
const ids = tasks.map(task => task.id);

assert.equal(GoalPlanningService.prioritize([expired, future], tasks, now).goal.id, future.id);
assert.equal(GoalPlanningService.prioritize([expired], tasks, now), undefined);
assert.equal(GoalPlanningService.prioritize([future], [], now).goal.id, future.id,
  'a future goal remains a reminder even when it has no linked task');
assert.deepEqual(tasks.map(task => task.id), ids, 'goal reminder selection must not mutate task identity');

const legacy = GoalPlanningService.decompose({ ...expired, createdAt: now });
assert.ok(legacy.every(item => item.dueDate <= expired.deadline),
  'legacy milestone metadata remains date guarded');
assert.equal(typeof GoalPlanningService.taskFor, 'undefined');
assert.equal(typeof GoalPlanningService.nextMilestone, 'undefined');

const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const planPage = fs.readFileSync(path.join(ets, 'pages/PlanPage.ets'), 'utf8');
assert.equal(index.includes('ensureGoalMilestoneTask'), false);
assert.equal(index.includes('advanceGoalMilestone'), false);
assert.equal(index.includes('GoalPlanningService.taskFor'), false);
assert.equal(planPage.includes("Text('关联任务')"), false);
assert.equal(planPage.includes("Text('完成情况')"), false);
assert.equal(planPage.includes('GoalTaskProgressService'), false);
assert.ok(planPage.includes('GoalPlanningService.activeGoals'));
assert.ok(planPage.includes('暂无进行中的学习目标'));
assert.equal(fs.existsSync(path.join(ets, 'services/GoalTaskProgressService.ets')), false,
  'the no-longer-used goal/task progress selector should not remain as dead production code');

console.log('PASS goal/task consistency: legacy links persist, reminder UI is task-free and no milestone task is generated');
