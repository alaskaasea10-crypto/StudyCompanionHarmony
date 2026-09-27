const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const setup = fs.readFileSync(path.join(ets, 'pages/ProfileSetupPage.ets'), 'utf8');
const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const schedule = fs.readFileSync(path.join(ets, 'components/ScheduleImportCard.ets'), 'utf8');
const learningAction = fs.readFileSync(path.join(ets, 'services/LearningActionService.ets'), 'utf8');

// A/D/E: setup uses fixed subjects and the same real schedule importer, with no legacy scan control.
assert.equal(setup.includes("placeholder: '当前最重要的科目'"), false);
for (const subject of ['高等数学', '线性代数', '大学英语']) {
  assert.ok(setup.includes(`this.ChoiceChip('subject', '${subject}', '${subject}')`));
}
assert.ok(setup.includes("this.onChoiceChange(group, value)"));
assert.ok(setup.includes('ScheduleImportCard({'));
assert.match(setup, /onSelectImage:\s*\(\) => \{\s*this\.onImportSchedule\(\);/);
assert.equal(schedule.includes("'重新扫描'"), false);
assert.equal(schedule.includes("Button('智能扫描')"), false);
assert.equal(schedule.includes('onScanDocument'), false);
assert.ok(schedule.includes("this.setupScheduleReady ? '重新上传课表' : '直接选择课表截图'"));

// F/G/H: hours are display labels while persisted values remain minutes; two rows protect narrow phones.
for (const [minutes, label] of [[60, '1小时'], [120, '2小时'], [180, '3小时'], [240, '4小时'], [300, '5小时']]) {
  assert.ok(setup.includes(`this.ChoiceChip('minutes', '${minutes}', '${label}')`));
}
assert.equal(setup.includes("this.ChoiceChip('minutes', '30', '30分钟')"), false);
assert.equal(setup.includes("this.ChoiceChip('minutes', '90', '90分钟')"), false);
assert.match(index, /profileDailyMinutes = Math\.min\(300, Math\.max\(15,/);
assert.match(learningAction, /Math\.min\(300, Math\.max\(15, snapshot\.profileDailyMinutes/);
assert.match(learningAction, /const remaining: number = Math\.min\(300,/);

// B/C: execute the real choice and existing-goal synchronization methods.
const serviceBox = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(ets,
  'services/GoalPlanningService.ets'), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, serviceBox);
const GoalPlanningService = serviceBox.exports.GoalPlanningService;
const syncStart = index.indexOf('  private syncProfileToAcademicGoal()');
const syncEnd = index.indexOf('  private async loadBankEvidence()', syncStart);
const activeStart = index.indexOf('  private activeGoal(');
const activeEnd = index.indexOf('  private addAcademicGoal()', activeStart);
const choiceStart = index.indexOf('  private setChoice(');
const choiceEnd = index.indexOf('  private completedCount()', choiceStart);
assert.ok(syncStart >= 0 && syncEnd > syncStart && activeStart >= 0 && choiceStart >= 0);
const harnessSource = `class Harness {
  profileGrade = '大二'; profileGoal = '期末复习'; profilePreferredTime = '晚间';
  profileLearningStyle = '练习驱动'; profileSupportStyle = '温和陪伴';
  profileSubject = '高等数学'; profileExamDate = '2026-09-28'; profileDailyMinutes = 60;
  academicGoals = []; tasks = [];
  applyProfileToTasks() { throw new Error('existing profile must not be rebuilt'); }
  examDays() { return 1; }
  ${index.slice(syncStart, syncEnd)}
  ${index.slice(activeStart, activeEnd)}
  ${index.slice(choiceStart, choiceEnd)}
} exports.Harness = Harness;`;
const harnessBox = { exports: {}, Date, GoalPlanningService };
vm.runInNewContext(ts.transpileModule(harnessSource, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, harnessBox);
const harness = new harnessBox.exports.Harness();
const goal = GoalPlanningService.create('高等数学考试', '高等数学', '2026-09-28', 300, '期末复习');
goal.id = 'goal-stable'; goal.createdAt = 1;
harness.academicGoals = [goal];
harness.tasks = [{ id: 'task-stable', title: '整理导数笔记', subject: '高等数学', minutes: 25,
  completed: false, source: 'manual', goalId: goal.id, createdAt: 1 }];
const taskId = harness.tasks[0].id;
const taskTitle = harness.tasks[0].title;
const taskSubject = harness.tasks[0].subject;
harness.setChoice('subject', '线性代数');
harness.setChoice('minutes', '300');
harness.profileExamDate = '2026-10-01';
harness.syncProfileToAcademicGoal();
assert.equal(harness.profileSubject, '线性代数');
assert.equal(harness.profileDailyMinutes, 300);
assert.equal(harness.academicGoals[0].id, 'goal-stable');
assert.equal(harness.academicGoals[0].subject, '线性代数');
assert.equal(harness.academicGoals[0].deadline, '2026-10-01');
assert.equal(harness.tasks[0].id, taskId);
assert.equal(harness.tasks[0].title, taskTitle);
assert.equal(harness.tasks[0].subject, taskSubject,
  'editing a long-term reminder must not rewrite an existing executable task');

// Historical free-text subjects/minutes are displayed as compatibility information, not silently overwritten.
assert.ok(setup.includes('当前保存的科目：${formatSubjectName(this.profileSubject)}'));
assert.ok(setup.includes('当前保存为${this.profileDailyMinutes}分钟'));
assert.equal(index.includes("this.onTextChange('subject', value)"), false);

console.log('PASS profile setup hotfix: fixed choices, stable goal/task identity, hour persistence and shared schedule upload');
