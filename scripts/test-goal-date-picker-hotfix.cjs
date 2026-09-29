const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const serviceBox = { exports: {}, Date };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(ets,
  'services/GoalPlanningService.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, serviceBox);
const goals = serviceBox.exports.GoalPlanningService;
const now = new Date('2026-09-27T12:00:00+08:00').getTime();

// A/F/G/H: one strict persistence format and the existing Beijing day calculation.
assert.equal(goals.normalizeDeadline('2026-09-28'), '2026-09-28');
assert.equal(goals.normalizeDeadline('2026/09/28'), '');
assert.equal(goals.normalizeDeadline('2026-9-28'), '');
assert.equal(goals.normalizeDeadline('9月28日'), '');
assert.equal(goals.deadlineFromDate(new Date(2026, 8, 28)), '2026-09-28');
assert.equal(goals.daysUntil('2026-09-27', now), 0);
assert.equal(goals.daysUntil('2026-09-28', now), 1);
assert.equal(goals.daysUntil('2026-10-01', new Date('2026-09-30T12:00:00+08:00').getTime()), 1);

// D: editing keeps the original goal identity.
const original = goals.create('高等数学考试', '高等数学', '2026-09-28', 300);
original.id = 'goal-stable'; original.createdAt = 123;
const updated = goals.update(original, original.title, original.subject, '2026-10-05', original.estimatedMinutes);
assert.equal(updated.id, 'goal-stable');
assert.equal(updated.createdAt, 123);
assert.equal(updated.deadline, '2026-10-05');

const picker = fs.readFileSync(path.join(ets, 'components/GoalDatePickerField.ets'), 'utf8');
const profile = fs.readFileSync(path.join(ets, 'pages/ProfileSetupPage.ets'), 'utf8');
const plan = fs.readFileSync(path.join(ets, 'pages/PlanPage.ets'), 'utf8');
const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');

// B/C/E: native month-grid dialog owns its draft; only onAccept forwards a canonical value.
assert.match(picker, /CalendarPickerDialog\.show\(/);
assert.match(picker, /selected:\s*selected/);
assert.match(picker, /start:\s*today/);
assert.match(picker, /markToday:\s*true/);
assert.match(picker, /onAccept:[\s\S]*?this\.onConfirm\(deadline\)/);
assert.match(picker, /onCancel:[\s\S]*?value unchanged/);
assert.equal(picker.includes('TextInput'), false);

// All three former free-text date fields now share the same calendar field.
assert.ok(profile.includes('GoalDatePickerField({'));
assert.ok(plan.match(/GoalDatePickerField\(\{/g).length >= 2);
assert.equal(profile.includes("onTextChange('examDate'"), false);
assert.equal(plan.includes("placeholder: '截止日期 YYYY-MM-DD'"), false);

// I/J: persistence and page snapshots retain the one AcademicGoal authority; no task rebuild/ranking change.
assert.match(index, /GoalPlanningService\.normalizeDeadline\(deadline\)/);
assert.match(index, /return GoalPlanningService\.update\(goal, title, subject, normalizedDeadline, estimatedMinutes\)/);
assert.match(index, /profileExamDate:\s*this\.authoritativeGoalDeadline\(\)/);
assert.equal(index.includes('applyProfileToTasks();\n      return await this.updateAcademicGoal'), false);

console.log('PASS goal date picker hotfix: canonical deadline, calendar-only input, cancel safety and stable goal identity');
