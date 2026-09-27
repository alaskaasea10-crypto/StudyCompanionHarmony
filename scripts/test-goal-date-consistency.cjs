const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const serviceBox = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,
  'entry/src/main/ets/services/GoalPlanningService.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, serviceBox);
const GoalPlanningService = serviceBox.exports.GoalPlanningService;

const indexSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const start = indexSource.indexOf('  private examDays(');
const end = indexSource.indexOf('  private beijingDayKey()', start);
const activeStart = indexSource.indexOf('  private activeGoal(');
const activeEnd = indexSource.indexOf('  private addAcademicGoal()', activeStart);
assert.ok(start >= 0 && end > start && activeStart >= 0 && activeEnd > activeStart);
const methods = `${indexSource.slice(start, end)}\n${indexSource.slice(activeStart, activeEnd)}`;
const harnessBox = { exports: {}, Date, GoalPlanningService };
vm.runInNewContext(ts.transpileModule(`class GoalDateHarness {
  academicGoals = []; tasks = []; profileGoal = ''; profileSubject = ''; profileExamDate = '';
  ${methods}
} exports.GoalDateHarness = GoalDateHarness;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, harnessBox);

const now = new Date('2026-09-27T12:00:00+08:00').getTime();
const harness = new harnessBox.exports.GoalDateHarness();
harness.profileGoal = '高等数学考试';
harness.profileSubject = '高等数学';
harness.profileExamDate = '2026-09-23';
harness.academicGoals = [{ id: 'goal-math-real', title: '高等数学考试', type: '考试', subject: '高等数学',
  deadline: '2026-09-28', estimatedMinutes: 300, completed: false, createdAt: 1 }];
harness.tasks = [{ id: 'task-math-real', title: '巩固基本求导规则', subject: '高等数学', minutes: 30,
  completed: false, source: 'goal-milestone', goalId: 'goal-math-real' }];
assert.equal(harness.activeGoal(now).goal.id, 'goal-math-real');
assert.equal(harness.authoritativeGoalTitle(now), '高等数学考试');
assert.equal(harness.authoritativeGoalSubject(now), '高等数学');
assert.equal(harness.authoritativeGoalDeadline(now), '2026-09-28');
assert.equal(harness.examDays(now), 1);

// Page wiring and persisted Agent snapshot must consume that same authority, not the stale legacy field.
assert.match(indexSource, /profileGoal:\s*this\.authoritativeGoalTitle\(\)/);
assert.match(indexSource, /profileExamDate:\s*this\.authoritativeGoalDeadline\(\)/);
assert.match(indexSource, /activeGoalTitle:\s*this\.activeGoal\(\)\?\.goal\.title/);
assert.match(indexSource, /profileExamDate:\s*authoritativeGoal\?\.deadline \?\? this\.profileExamDate/);
assert.equal(indexSource.includes("'2026-09-23'"), false);
assert.equal(indexSource.includes("'2026-09-28'"), false);

const profileSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/ProfilePage.ets'), 'utf8');
assert.match(profileSource, /if \(this\.examDays < 0\)/);
assert.match(profileSource, /if \(this\.examDays === 0\)/);
assert.ok(profileSource.includes('还有${this.examDays}天'));

console.log('PASS goal date consistency: stable goalId authority, snapshot/page wiring and date boundaries');
