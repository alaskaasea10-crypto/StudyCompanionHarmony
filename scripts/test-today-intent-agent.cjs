const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const now = new Date('2026-09-27T14:00:00+08:00').getTime();
class Clock extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
const cache = new Map();
let online = false;
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (name === 'AgentClient') return { AgentClient: { generateTodayPlan: async () => {
    if (!online) throw new Error('offline');
    throw new Error('no paid requests in regression');
  } } };
  if (cache.has(name)) return cache.get(name);
  const file = ['services', 'models', 'utils'].map(folder => path.join(ets, folder, name + '.ets')).find(fs.existsSync);
  const box = { exports: {}, Date: Clock, console, require: id => load(path.basename(id)) };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports); return box.exports;
}
const { TodayIntentService: intents } = load('TodayIntentService');
const { TodayStudyOverrideService: overrides } = load('TodayStudyOverrideService');
const { LearningActionService: actions } = load('LearningActionService');
const { AgentDecisionService: decisions } = load('AgentDecisionService');
const { LearningDecisionPolicy: policy } = load('LearningDecisionPolicy');
const { PlanValidator: validator } = load('PlanValidator');
const { TaskOutcomeService: outcomes } = load('TaskOutcomeService');
const { GoalPlanningService: goals } = load('GoalPlanningService');
const { LearningPlanningOrchestrator: orchestrator } = load('LearningPlanningOrchestrator');
const math = { id: 'real-math', title: '考前冲刺', subject: 'AdvancedMath', minutes: 25, completed: false,
  source: 'manual', goalId: 'goal-math' };
const linear = { id: 'real-linear', title: '回顾线性代数核心知识点', subject: 'LinearAlgebra', minutes: 25,
  source: 'manual', completed: false };
const mathNext = { ...math, id: 'real-math-next', title: '整理高数错题', minutes: 30 };
const base = { profileCompleted: true, profileSubject: '线性代数', profileDailyMinutes: 60,
  profileExamDate: '2026-09-28', profileExamDateConfirmed: true, energyState: '一般', studyDayKey: '2026-09-27',
  tasks: [linear, math, mathNext], currentTaskIndex: 0, remainingSeconds: 0, isRunning: false,
  focusRecords: [], focusElapsedSeconds: 0, focusSegmentStartedAt: 0, focusSessionCredited: true,
  todayMinutes: 0, quizAttempts: [], knowledgeMastery: [], setupScheduleReady: false, scheduleItems: [],
  academicGoals: [{ id: 'goal-math', title: '高数考试', subject: '高等数学', deadline: '2026-09-28', completed: false }],
  todayStudyOverride: { date: '2026-09-27', availableMinutes: 60 } };
const clone = obj => JSON.parse(JSON.stringify(obj));
const apply = (text, snapshot = base) => {
  const before = JSON.stringify(snapshot);
  const result = intents.resolve(text, snapshot, now);
  assert.equal(JSON.stringify(snapshot), before, 'resolution must not mutate tasks or caller state');
  assert.equal(result.kind, 'commit');
  return { ...clone(snapshot), tasks: clone(snapshot.tasks).concat(result.createdTasks ?? []), todayStudyOverride: result.override };
};
const action = s => decisions.decide(s, now).recommendedAction;
const ids = s => Array.from(decisions.decide(s, now).dailyPlan, item => item.taskId);
const beforeIds = base.tasks.map(task => task.id);
assert.equal(action(base).taskId, linear.id);
for (const text of ['今天复习高等数学', '我现在想复习高数', '今天我想复习高等数学。']) {
  const state = apply(text); assert.equal(action(state).taskId, math.id);
  assert.ok(ids(state).every(id => id === math.id || id === mathNext.id));
}
console.log('PASS A/B: explicit subject wins over previous recommendation');
const thirty = apply('今天只有30分钟，复习高数');
assert.equal(thirty.todayStudyOverride.availableMinutes, 30);
assert.equal(thirty.todayStudyOverride.intent.subject, '高等数学');
assert.equal(action(thirty).taskId, math.id);
assert.equal(decisions.decide(thirty, now).dailyPlan.reduce((n, p) => n + p.suggestedMinutes, 0), 30);
assert.equal(apply('今天只有30分钟', apply('今天复习高数')).todayStudyOverride.intent.subject, '高等数学');
console.log('PASS C: combined constraints and budget-only follow-up retain subject');
const missing = apply('今天复习大学英语');
assert.equal(ids(missing).length, 1);
assert.equal(overrides.subjectName(action(missing).subject), '大学英语');
assert.deepEqual(missing.tasks.slice(0, base.tasks.length).map(t => t.id), beforeIds);
const unknown = apply('今天复习量子力学');
assert.equal(ids(unknown).length, 1);
assert.equal(apply('今天先做考前冲刺').todayStudyOverride.preferredTaskId, math.id);
console.log('PASS D/E: no cross-subject fallback; exact existing taskId only');
assert.equal(intents.resolve('帮我安排一下今天', base, now).kind, 'plan');
const list = intents.resolve('后续的学习规划列出来我看看', thirty, now);
assert.equal(list.kind, 'show'); assert.match(list.message, /考前冲刺/); assert.match(list.message, /整理高数错题/);
assert.doesNotMatch(list.message, /今天先推进|milestone/);
console.log('PASS F/G: concrete real plan listing');
const later = { ...base, academicGoals: [{ ...base.academicGoals[0], deadline: '2026-10-27' }] };
assert.deepEqual(ids(base), ids(later));
assert.deepEqual(ids(base), ids({ ...base, academicGoals: [] }));
assert.equal(action(base).taskId, linear.id);
const expired = { ...base, academicGoals: [{ ...base.academicGoals[0], deadline: '2026-09-23' }] };
assert.equal(goals.activeGoals(expired.academicGoals, now).length, 0);
assert.deepEqual(ids(base), ids(expired));
console.log('PASS H/I/J/O: deadline/empty/expired goals cannot rank tasks');
const switched = apply('还是学线代吧', apply('今天学高数'));
assert.equal(action(switched).taskId, linear.id);
assert.equal(action(apply('我不想学线代了，今天学高数', switched)).taskId, math.id);
console.log('PASS K: latest positive instruction wins, negated subject ignored');
const completed = outcomes.submit({ ...math, outcome: 'focused', focusedAt: now - 60000 }, true, '', now, 'struggling');
const finished = { ...thirty, tasks: [linear, completed, mathNext] };
assert.equal(action(finished).taskId, mathNext.id);
assert.equal(action(finished).minutes, 18);
assert.equal(ids(finished).includes(math.id), false);
assert.equal(action(JSON.parse(JSON.stringify(finished))).taskId, mathNext.id);
assert.equal(overrides.active(thirty, now + 86400000), undefined);
assert.equal(action({ ...thirty, isRunning: true, remainingSeconds: 1200, focusSegmentStartedAt: now }).taskId, linear.id);
assert.equal(action({ ...thirty, tasks: [{ ...linear, outcome: 'focused' }, math] }).taskId, linear.id);
assert.match(intents.describe({ ...thirty, tasks: [{ ...linear, outcome: 'focused' }, math] }, now), /先完成待提交的反馈/);
console.log('PASS M/N: JSON restore, date expiry, feedback adaptation and state protection');

const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const methods = index.slice(index.indexOf('  private async commitTodayConversation('), index.indexOf('  private todayCourseHint('));
const feedback = index.slice(index.indexOf('  private recordTaskResult('), index.indexOf('  private openTaskResult('));
const harnessBox = { exports: {}, Date: Clock, console, TodayIntentService: intents, TaskOutcomeService: outcomes,
  StudyDecisionDebug: load('StudyDecisionDebug').StudyDecisionDebug, PlanValidator: validator,
  SmallPlanetConversationRouter: load('SmallPlanetConversationRouter').SmallPlanetConversationRouter,
  SmallPlanetSemanticValidator: load('SmallPlanetSemanticValidator').SmallPlanetSemanticValidator,
  LearningActionService: actions };
vm.runInNewContext(ts.transpileModule(`class Harness {
  state; todayStudyOverride; preferredTaskId = ''; actionClock = 0; todayIntentUndo = []; messages = [];
  agentRequestId = 0; agentCommitBusy = false; fail = false; disk = ''; tasks = []; actionDeferrals = [];
  todayStrategyText = ''; pendingSmallPlanetProposal=undefined; agentLoading=false;
  snapshot() { return {...this.state, tasks: this.tasks, todayStudyOverride: this.todayStudyOverride}; }
  beijingDayKey() { return '2026-09-27'; }
  async persistState() { if(this.fail) throw Error('storage failed'); this.disk = JSON.stringify(this.snapshot()); }
  persistSilently() { this.disk = JSON.stringify(this.snapshot()); }
  addFloatingMessage(role, text) { this.messages.push(text); }
  async addSmallPlanetReply(text, route, fallback) { this.addFloatingMessage('assistant', fallback); }
  requestTodayPlan() { throw Error('explicit intent must not require cloud'); }
  ${methods}
  ${feedback}
} exports.Harness = Harness;`, { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, harnessBox);

function request(s) {
  const d = decisions.decide(s, now);
  return policy.buildRequest({ requestText: '帮我安排今天', profile: { name: '', grade: '', major: '',
    subject: '高等数学', goal: '高数考试', examDate: '2026-09-28', dailyMinutes: 60,
    preferredTime: '', learningStyle: '', supportStyle: '' }, date: '2026-09-27', examDays: 1,
    energyState: '一般', scheduleReady: false, scheduleItems: [], tasks: s.tasks,
    metrics: { todayFocusMinutes: 0, todayFocusSessionCount: 0, quizAttemptCount: 0, quizCorrectCount: 0 },
    quizAttempts: [], knowledgeMastery: [], academicGoals: s.academicGoals,
    todayStudyOverride: s.todayStudyOverride, confirmedAvailableMinutes: 30,
    localDailyPlanTaskIds: d.dailyPlan.map(p => p.taskId), localDailyPlanMinutes: d.dailyPlan.map(p => p.suggestedMinutes),
    eligibleTaskIds: actions.candidates(s, now).map(c => c.task.id), protectedStage: d.recommendedAction.stage });
}
(async () => {
  const h = new harnessBox.exports.Harness(); h.state = clone(base); h.tasks = clone(base.tasks);
  h.todayStudyOverride = clone(base.todayStudyOverride);
  await h.handleTodayConversation('今天复习高数');
  assert.equal(action(h.snapshot()).taskId, math.id);
  assert.match(h.messages.at(-1), /考前冲刺/);
  assert.equal(action(JSON.parse(h.disk)).taskId, math.id);
  await h.handleTodayConversation('今天只有30分钟');
  assert.equal(h.todayStudyOverride.availableMinutes, 30);
  await h.handleTodayConversation('还是学线代吧'); assert.equal(action(h.snapshot()).taskId, linear.id);
  await h.handleTodayConversation('返回上一步'); assert.equal(action(h.snapshot()).taskId, math.id);
  assert.equal(h.todayStudyOverride.availableMinutes, 30);
  h.fail = true;
  await h.handleTodayConversation('还是学线代吧');
  assert.equal(action(h.snapshot()).taskId, math.id);
  assert.match(h.floatingAgentError, /没有保存成功/);
  h.fail = false;
  h.tasks[1] = { ...h.tasks[1], outcome: 'focused', focusedAt: now - 1000 };
  h.recordTaskResult(1, true, '', 'struggling');
  assert.equal(h.todayStudyOverride.intent.subject, '高等数学');
  assert.equal(action(h.snapshot()).taskId, mathNext.id);
  assert.equal(action(h.snapshot()).minutes, 18);
  assert.equal((index.match(/decision: this\.agentDecision\(\)/g) || []).length, 2);
  const stored = new Map();
  const { StudyRepository } = load('StudyRepository');
  const repository = new StudyRepository({
    get: async (key, fallback) => stored.get(key) ?? fallback,
    put: async (key, value) => { stored.set(key, value); }, flush: async () => {}
  });
  await repository.saveChecked(h.snapshot());
  const reopened = await repository.load();
  assert.equal(reopened.todayStudyOverride.intent.subject, '高等数学');
  assert.equal(action(reopened).taskId, mathNext.id);
  assert.equal(action(reopened).minutes, 18);
  console.log('PASS L/M/N: actual Index commit + persist + rollback + undo + feedback methods; shared page decision');
  const req = request(thirty);
  assert.equal(req.context.academicGoals, undefined);
  assert.equal(req.context.examDays, 999); assert.equal(req.profile.examDate, ''); assert.equal(req.profile.goal, '');
  assert.equal(req.context.unfinishedTasks.some(t => t.goalId !== undefined), false);
  const fallback = await orchestrator.decide(req, []);
  assert.equal(fallback.plan.source, 'local-fallback');
  assert.equal(fallback.plan.tasks[0].taskId, math.id); assert.match(fallback.plan.summary, /考前冲刺/);
  const requestMethod = index.slice(index.indexOf('  private requestTodayPlan('), index.indexOf('  private async acceptAgentPlan('));
  const cloudBox = { exports: {}, Date: Clock, console, Harness: harnessBox.exports.Harness,
    TodayIntentService: intents, TodayStudyOverrideService: overrides,
    PlanValidator: validator, LearningPlanningOrchestrator: orchestrator,
    LearningDecisionPolicy: { planningBudget: policy.planningBudget.bind(policy),
      priorityEvidence: () => [], buildRequest: input => request(input.snapshot) } };
  vm.runInNewContext(ts.transpileModule(`class CloudHarness extends Harness {
    profileCompleted = true; profileDailyMinutes = 60; bankPlanMode = false; agentLoading = false;
    availableMinutesToday() { return 30; }
    learningContextInput() { return {snapshot: this.snapshot()}; }
    setAgentPreview(plan) { this.agentGenerated = true; this.agentPreviewTasks = plan.tasks; }
    ${requestMethod}
  } exports.CloudHarness = CloudHarness;`, { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText, cloudBox);
  const cloud = new cloudBox.exports.CloudHarness();
  cloud.state = clone(thirty); cloud.tasks = clone(thirty.tasks); cloud.todayStudyOverride = clone(thirty.todayStudyOverride);
  cloud.requestTodayPlan('帮我安排今天', false, true);
  for (let n = 0; n < 20 && cloud.agentLoading; n++) await new Promise(resolve => setTimeout(resolve, 5));
  assert.equal(cloud.agentLoading, false);
  assert.match(cloud.messages.at(-1), /考前冲刺/);
  assert.match(cloud.messages.at(-1), /整理高数错题/);
  assert.equal(action(JSON.parse(cloud.disk)).taskId, math.id);
  assert.equal(cloud.agentGenerated, false, 'a committed chat plan must not remain an unaccepted preview');
  console.log('PASS F/L: actual requestTodayPlan -> offline validator -> commit -> persisted UI-derived response');
  const forged = { ...fallback.plan, tasks: [{ taskId: linear.id, title: linear.title, subject: linear.subject,
    minutes: 25, priority: 1, type: 'review' }] };
  assert.throws(() => validator.validateExisting(forged, { ...req, context: { ...req.context,
    eligibleTaskIds: base.tasks.map(t => t.id) } }), /不存在/);
  for (const name of ['LearningActionService', 'AgentDecisionService']) {
    const source = fs.readFileSync(path.join(ets, 'services', name + '.ets'), 'utf8');
    assert.doesNotMatch(source, /daysUntil|deadlineScore|goalUrgency|examUrgency|goalDeadlinePriority|linkedDeadline/);
  }
  assert.deepEqual(base.tasks.map(t => t.id), beforeIds);
  console.log('PASS cloud fallback, hard subject validation, reminder isolation, static ranking guard, no task mutation');
})().catch(error => { console.error(error); process.exitCode = 1; });
