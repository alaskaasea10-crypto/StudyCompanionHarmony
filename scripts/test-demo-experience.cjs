const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');

function transpile(source) {
  return ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
}

function load(relative, requireImpl = () => ({})) {
  const box = { exports: {}, require: requireImpl, console };
  vm.runInNewContext(transpile(fs.readFileSync(path.join(root, relative), 'utf8')), box);
  return box.exports;
}

const models = load('entry/src/main/ets/models/StudyModels.ets');
const demoSchedule = models.createDemoSchedule();
const defaultMembers = models.createDefaultSquadMembers('小林');

// CASE A–F: the presentation schedule covers every weekday while keeping visible gaps.
assert.deepEqual(Array.from(new Set(demoSchedule.map(item => item.weekday))), [1, 2, 3, 4, 5]);
assert.deepEqual([1, 2, 3, 4, 5].map(day => demoSchedule.filter(item => item.weekday === day).length),
  [3, 2, 3, 3, 2]);
assert.equal(demoSchedule.length, 13);

// CASE G–H: stable unique demo IDs remain recognizable by every production guard.
const ids = demoSchedule.map(item => item.id);
assert.equal(new Set(ids).size, ids.length);
assert.ok(ids.every(id => id.startsWith('demo-')));

const learningAction = load('entry/src/main/ets/services/LearningActionService.ets', request => {
  if (request.includes('TodayStudyOverrideService')) {
    return { TodayStudyOverrideService: { active: () => undefined, date: () => '2026-09-27' } };
  }
  if (request.includes('StudyDataCenter')) {
    return { StudyDataCenter: { calculateMetrics: () => ({ todayFocusMinutes: 0 }) } };
  }
  if (request.includes('TaskOutcomeService')) {
    return { TaskOutcomeService: {} };
  }
  return {};
}).LearningActionService;

// CASE I: even with setupScheduleReady=true, demo items cannot prove a real timetable gap.
assert.equal(learningAction.freeMinutes({
  setupScheduleReady: true,
  scheduleItems: demoSchedule
}, new Date('2026-09-28T07:00:00+08:00').getTime()), undefined);

const indexSource = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const agentSource = fs.readFileSync(path.join(ets, 'services/AgentDecisionService.ets'), 'utf8');
const reminderSource = fs.readFileSync(path.join(ets, 'services/ActiveReminderService.ets'), 'utf8');

assert.match(agentSource,
  /setupScheduleReady === true[\s\S]*items\.every\(item => !item\.id\.startsWith\('demo-'\)\)/);
assert.match(reminderSource, /!item\.id\.startsWith\('demo-'\)/);

// CASE J: confirmed OCR/manual data replaces the array; it is never concatenated with demo items.
const confirmStart = indexSource.indexOf('private confirmScheduleImport()');
const confirmEnd = indexSource.indexOf('private updateScheduleDraftItems(', confirmStart);
const confirmBody = indexSource.slice(confirmStart, confirmEnd);
assert.ok(confirmBody.includes('this.scheduleItems = prepared;'));
assert.equal(confirmBody.includes('createDemoSchedule'), false);
assert.equal(confirmBody.includes('concat'), false);

const saveStart = indexSource.indexOf('private async saveScheduleEdits(');
const saveEnd = indexSource.indexOf('private useDemoSchedule()', saveStart);
const saveBody = indexSource.slice(saveStart, saveEnd);
assert.ok(saveBody.includes('this.scheduleItems = prepared;'));
assert.equal(saveBody.includes('concat'), false);

// CASE K–M: local companions exist exactly once and are explicitly demo members.
for (const name of ['小雨', '阿哲']) {
  assert.equal(defaultMembers.filter(member => member.name === name).length, 1);
}
const SquadService = load('entry/src/main/ets/services/SquadService.ets', request => {
  if (request.includes('StudyModels')) { return models; }
  return {};
}).SquadService;
const normalized = SquadService.normalizeMembers(defaultMembers, '小林');
for (const name of ['小雨', '阿哲']) {
  assert.equal(normalized.filter(member => member.name === name).length, 1);
  assert.equal(normalized.find(member => member.name === name).isDemo, true);
}
assert.equal(defaultMembers.find(member => member.name === '小雨').status, '专注中');
assert.equal(defaultMembers.find(member => member.name === '阿哲').status, '稍后学习');

const growthSource = fs.readFileSync(path.join(ets, 'pages/GrowthPage.ets'), 'utf8');
assert.ok(growthSource.includes('仅保存在本机'));
assert.equal(/WebSocket|socket|remote user|online API/i.test(growthSource), false);

// CASE N: local join/leave only changes the presentation squad state.
for (const method of ['private joinLocalSquad(', 'private leaveLocalSquad()']) {
  const start = indexSource.indexOf(method);
  const end = indexSource.indexOf('\n  private ', start + method.length);
  const body = indexSource.slice(start, end);
  for (const protectedState of ['tasks', 'academicGoals', 'todayStudyOverride', 'focusRecords',
    'knowledgeMastery', 'currentTaskIndex']) {
    assert.equal(body.includes(`this.${protectedState}`), false,
      `${method} must not mutate ${protectedState}`);
  }
}

// CASE O: seeded schedule/team data does not satisfy the explicit first-launch gate.
const ProfileCompletionService = load('entry/src/main/ets/services/ProfileCompletionService.ets').ProfileCompletionService;
assert.equal(ProfileCompletionService.completed({
  profileCompleted: false,
  scheduleItems: demoSchedule,
  squadMembers: defaultMembers,
  squadJoined: true
}), false);
assert.match(indexSource, /@State profileCompleted: boolean = false;/);

// CASE P: an existing snapshot wins, including explicit empty/left states.
assert.ok(indexSource.includes('this.scheduleItems = Array.isArray(snapshot.scheduleItems) ? storedSchedule : createDemoSchedule();'));
assert.ok(indexSource.includes('this.squadJoined = snapshot.squadJoined === undefined ? true : snapshot.squadJoined === true;'));
assert.ok(indexSource.includes("snapshot.squadInviteCode ?? (this.squadJoined ? 'LIGHT-DEMO' : '')"));
assert.ok(indexSource.includes("@State squadInviteCode: string = 'LIGHT-DEMO';"));
assert.ok(indexSource.includes('@State squadJoined: boolean = true;'));

console.log('PASS demo experience: 13 weekday courses, guarded demo context, local squad seed and snapshot precedence');
