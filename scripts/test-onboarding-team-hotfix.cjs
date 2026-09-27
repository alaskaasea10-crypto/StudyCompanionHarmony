const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const setup = fs.readFileSync(path.join(ets, 'pages/ProfileSetupPage.ets'), 'utf8');
const growth = fs.readFileSync(path.join(ets, 'pages/GrowthPage.ets'), 'utf8');
const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const models = fs.readFileSync(path.join(ets, 'models/StudyModels.ets'), 'utf8');
const completionSource = fs.readFileSync(path.join(ets, 'services/ProfileCompletionService.ets'), 'utf8');

const recentStart = setup.indexOf("this.SetupSection('3', '最近目标'");
const rhythmStart = setup.indexOf("this.SetupSection('4', '学习节奏'");
const recentGoal = setup.slice(recentStart, rhythmStart);
assert.ok(recentStart >= 0 && rhythmStart > recentStart);
assert.ok(recentGoal.includes("Text('考试/目标日期')"));
assert.equal(recentGoal.includes('profileDailyMinutes'), false,
  'the recent-goal section must not read or render daily study minutes');
assert.match(setup, /if \(group === 'minutes'\)[\s\S]*profileDailyMinutes\.toString\(\)/);
assert.ok(setup.includes("this.ChoiceChip('minutes', '60', '1小时')"),
  '60 minutes remains a real rhythm option after removing the stray target value');

assert.ok(growth.includes("Button('加入小队')"));
assert.ok(growth.includes("Text('我的小队')"));
assert.ok(growth.includes("Text('小队口令')"));
assert.ok(growth.includes("Button('复制')"));
assert.ok(growth.includes("Button('退出小队')"));
assert.ok(growth.includes("Text('退出学习小队？')"));
assert.ok(growth.includes('当前小队加入、成员与挑战状态仅保存在本机'));
assert.ok(index.includes('private joinLocalSquad(code: string)'));
assert.ok(index.includes('private leaveLocalSquad()'));
assert.ok(models.includes('squadJoined?: boolean;') && models.includes('squadName?: string;'));
assert.ok(index.includes('squadJoined: this.squadJoined') && index.includes('squadName: this.squadName'));
const leaveStart = index.indexOf('private leaveLocalSquad()');
const leaveEnd = index.indexOf('private async copySquadCode()', leaveStart);
const leaveBody = index.slice(leaveStart, leaveEnd);
for (const protectedState of ['profileCompleted', 'academicGoals', 'tasks', 'focusRecords', 'profileSubject']) {
  assert.equal(leaveBody.includes(`this.${protectedState}`), false,
    `leaving the local squad must not mutate ${protectedState}`);
}

const stripped = completionSource.replace(/^import .*;$/m, '');
const box = { exports: {}, console, require: () => ({}) };
vm.runInNewContext(ts.transpileModule(stripped, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, box);
const ProfileCompletionService = box.exports.ProfileCompletionService;
const completeLegacy = {
  profileName: '小林', profileMajor: '计算机科学与技术', profileSubject: '线性代数',
  profileExamDate: '2026-09-28', profileDailyMinutes: 60, profilePreferredTime: '晚间',
  tasks: [{ id: 'task-old' }], academicGoals: [{ id: 'goal-old' }]
};
assert.equal(ProfileCompletionService.completed({ ...completeLegacy, profileCompleted: false }), false,
  'an explicit incomplete setup must never be auto-migrated');
assert.equal(ProfileCompletionService.completed({ ...completeLegacy, profileCompleted: true }), true);
assert.equal(ProfileCompletionService.completed(completeLegacy), true,
  'a complete old snapshot without the boolean migrates once');
assert.equal(ProfileCompletionService.completed({ ...completeLegacy, tasks: [], academicGoals: [], profileCompleted: undefined }), false,
  'a few default-looking fields are insufficient migration evidence');

assert.ok(index.includes('@State profileCompleted: boolean = false;'));
assert.ok(index.includes('this.profileCompleted = ProfileCompletionService.completed(snapshot);'));
assert.ok(index.includes('this.profileCompleted = true;') && index.includes('this.profileSetupEditing = false;'));
assert.ok(index.includes('!this.profileCompleted || this.profileSetupEditing'));
const resetStart = index.indexOf('private async resetProfile()');
const resetEnd = index.indexOf('private hostAbilityContext()', resetStart);
const resetBody = index.slice(resetStart, resetEnd);
assert.ok(resetBody.includes('this.profileSetupEditing = true;'));
assert.equal(resetBody.includes('this.profileCompleted = false;'), false);

const syncStart = index.indexOf('private syncProfileToAcademicGoal()');
const syncEnd = index.indexOf('private async loadBankEvidence()', syncStart);
const syncBody = index.slice(syncStart, syncEnd);
assert.ok(syncBody.includes('goal.id === current.id'));
assert.equal(syncBody.includes('this.tasks = this.tasks.map'), false,
  'editing the profile goal must not rewrite executable StudyTasks');
assert.equal(syncBody.includes('GoalPlanningService.taskFor'), false,
  'editing the profile goal must not generate a milestone task');

console.log('PASS onboarding/team hotfix: target minutes isolated, local team lifecycle persisted, first-run and legacy completion guarded');
