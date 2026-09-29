const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const now = Date.parse('2026-09-28T14:00:00+08:00');
class Clock extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
const cache = new Map();
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (name === '@kit.ArkData') return {};
  if (cache.has(name)) return cache.get(name);
  const file = ['services', 'models', 'utils'].map(folder => path.join(ets, folder, name + '.ets')).find(fs.existsSync);
  const box = { exports: {}, Date: Clock, console, require: id => load(path.basename(id)) };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports); return box.exports;
}
const intents = load('TodayIntentService').TodayIntentService;
const decisions = load('AgentDecisionService').AgentDecisionService;
const overrides = load('TodayStudyOverrideService').TodayStudyOverrideService;
const validator = load('PlanValidator').PlanValidator;
const debug = load('StudyDecisionDebug').StudyDecisionDebug;
const router = load('SmallPlanetConversationRouter').SmallPlanetConversationRouter;
const semanticValidator = load('SmallPlanetSemanticValidator').SmallPlanetSemanticValidator;
const clone = value => JSON.parse(JSON.stringify(value));
const math = { id: 'math-1', title: '复习高等数学', subject: 'AdvancedMath', minutes: 25,
  completed: false, source: 'manual' };
const linear = { id: 'linear-1', title: '复习线性代数', subject: 'LinearAlgebra', minutes: 25,
  completed: false, source: 'manual' };
const base = { profileCompleted: true, profileDailyMinutes: 60, tasks: [math, linear],
  todayStudyOverride: { date: '2026-09-28', availableMinutes: 60, preferredTaskId: linear.id,
    preferredSubject: '线性代数', intent: { action: 'execute', scope: 'today', source: 'user-chat',
      subject: '线性代数', taskId: linear.id } }, currentTaskIndex: 0, isRunning: false,
  remainingSeconds: 0, focusRecords: [], todayMinutes: 0, studyDayKey: '2026-09-28',
  actionDeferrals: [], deletedTaskIds: [], setupScheduleReady: false, scheduleItems: [],
  quizAttempts: [], knowledgeMastery: [] };

for (const text of ['为什么这么安排？', '为什么你建议我先学线性代数？', '为什么先学这个？',
  '这个安排合理吗？', '我有点看不懂这个计划']) {
  const before = JSON.stringify(base);
  const result = intents.resolve(text, base, now);
  assert.equal(result.kind, 'explain', text);
  assert.equal(result.override, undefined);
  assert.equal(result.createdTasks, undefined);
  assert.equal(JSON.stringify(base), before);
}
console.log('PASS explanation intents are read-only routes');

const switchResult = intents.resolve('还是学线代吧', { ...clone(base), todayStudyOverride: {
  ...clone(base.todayStudyOverride), preferredTaskId: math.id, preferredSubject: '高等数学',
  intent: { action: 'execute', scope: 'today', source: 'user-chat', subject: '高等数学', taskId: math.id }
} }, now);
assert.equal(switchResult.kind, 'commit');
assert.equal(switchResult.override.preferredSubject, '线性代数');
const additive = intents.resolve('别全学高数，我也想复习一下线代', base, now);
assert.equal(additive.kind, 'clarify');
assert.equal(additive.override, undefined);
assert.match(additive.message, /还没有替换当前安排/);
console.log('PASS explicit switch remains deterministic; additive multi-subject wording does not collapse to a switch');

const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const methods = index.slice(index.indexOf('  private smallPlanetHistory('), index.indexOf('  private todayCourseHint('));
let mode = 'success';
const requests = [];
const harnessBox = { exports: {}, Date: Clock, console, TodayIntentService: intents,
  AgentDecisionService: decisions, TodayStudyOverrideService: overrides, PlanValidator: validator,
  StudyDecisionDebug: debug, SmallPlanetConversationRouter: router,
  SmallPlanetSemanticValidator: semanticValidator,
  LearningActionService: load('LearningActionService').LearningActionService,
  SmallPlanetClient: { reply: async request => {
    requests.push(clone(request));
    if (mode === 'failure') throw new Error('offline');
    return { ok: true, reply: '因为这是你当前明确选择的线性代数任务，我先保留它。', source: 'openpangu',
      understanding: { mode: 'explain', intent: 'explain_current_plan', executionRequested: false,
        subjects: [{ subject: '线性代数', reason: '当前明确选择' }], needsExplanation: true,
        confirmationRequired: false, allocation: [] } };
  } } };
vm.runInNewContext(ts.transpileModule(`class Harness {
  state; tasks=[]; academicGoals=[]; todayStudyOverride={date:'2026-09-28'}; actionClock=Date.now(); currentTaskIndex=0;
  isRunning=false; setupScheduleReady=false; scheduleItems=[]; floatingAgentMessages=[]; todayStrategyText='';
  pendingSmallPlanetProposal=undefined; agentLoading=false;
  todayIntentUndo=[]; agentRequestId=0; agentGenerated=false; floatingPlanPending=false; agentCommitBusy=false;
  actionDeferrals=[]; preferredTaskId=''; floatingAgentError=''; todayCommitSettlement=Promise.resolve();
  snapshot(){return {...this.state,tasks:this.tasks,todayStudyOverride:this.todayStudyOverride};}
  availableMinutesToday(){return 60;} beijingDayKey(){return '2026-09-28';}
  async persistState(){throw Error('read-only explanation must not persist');}
  addFloatingMessage(role,text,mode){this.floatingAgentMessages.push({id:String(this.floatingAgentMessages.length),role,text,mode,createdAt:Date.now()});}
  requestTodayPlan(){throw Error('explanation must not request a new plan');}
  ${methods}
} exports.Harness=Harness;`, { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, harnessBox);

(async () => {
  const h = new harnessBox.exports.Harness();
  h.state = clone(base); h.tasks = clone(base.tasks); h.todayStudyOverride = clone(base.todayStudyOverride);
  h.floatingAgentMessages = [{ id: 'old-u', role: 'user', text: '今天学线代', mode: 'planning', createdAt: now - 2 },
    { id: 'old-a', role: 'assistant', text: '已经保留线代安排。', mode: 'planning', createdAt: now - 1 }];
  const beforeTasks = JSON.stringify(h.tasks); const beforeOverride = JSON.stringify(h.todayStudyOverride);
  await h.handleTodayConversation('为什么你建议我先学线性代数？');
  assert.equal(requests.length, 1);
  assert.equal(requests[0].route, 'advice-or-explanation');
  assert.equal(requests[0].operationResult, 'proposed');
  assert.equal(requests[0].persisted, false);
  assert.equal(requests[0].conversationContext.length, 2);
  assert.match(h.floatingAgentMessages.at(-1).text, /当前明确选择/);
  assert.equal(JSON.stringify(h.tasks), beforeTasks);
  assert.equal(JSON.stringify(h.todayStudyOverride), beforeOverride);

  mode = 'failure';
  await h.handleTodayConversation('为什么这么安排？');
  assert.equal(requests.length, 2);
  assert.match(h.floatingAgentMessages.at(-1).text, /因为|所以|当前/);
  assert.equal(JSON.stringify(h.tasks), beforeTasks);
  assert.equal(JSON.stringify(h.todayStudyOverride), beforeOverride);
  console.log('PASS routing: SmallPlanetClient success, context forwarding, deterministic fallback, and zero state mutation');
})().catch(error => { console.error(error); process.exitCode = 1; });
