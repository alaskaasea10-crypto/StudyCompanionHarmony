const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const now = Date.parse('2026-09-28T19:00:00+08:00');
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
const router = load('SmallPlanetConversationRouter').SmallPlanetConversationRouter;
const intents = load('TodayIntentService').TodayIntentService;
const decisions = load('AgentDecisionService').AgentDecisionService;
const overrides = load('TodayStudyOverrideService').TodayStudyOverrideService;
const semanticValidator = load('SmallPlanetSemanticValidator').SmallPlanetSemanticValidator;
const validator = load('PlanValidator').PlanValidator;
const debug = load('StudyDecisionDebug').StudyDecisionDebug;
const clone = value => JSON.parse(JSON.stringify(value));
const math = { id: 'math-1', title: '复习高等数学', subject: 'AdvancedMath', minutes: 40,
  completed: false, source: 'manual' };
const linear = { id: 'linear-1', title: '复习线性代数', subject: 'LinearAlgebra', minutes: 30,
  completed: false, source: 'manual' };
const base = { profileCompleted: true, profileDailyMinutes: 60, tasks: [math, linear],
  academicGoals: [{ id: 'goal-math', title: '高数考试', subject: '高等数学', deadline: '2026-10-01', completed: false }],
  todayStudyOverride: { date: '2026-09-28', availableMinutes: 60 }, currentTaskIndex: 0,
  isRunning: false, remainingSeconds: 0, focusRecords: [], todayMinutes: 0, studyDayKey: '2026-09-28',
  actionDeferrals: [], deletedTaskIds: [], setupScheduleReady: false, scheduleItems: [],
  quizAttempts: [], knowledgeMastery: [] };

assert.equal(router.decide('今天学高数', base, false).path, 'deterministic');
assert.equal(router.decide('还是学线代吧', base, false).path, 'deterministic');
const complexText = '我今晚只有一个小时，高数快考试了，但线代也落下不少，你觉得我应该怎么分配？为什么？';
const complex = router.decide(complexText, base, false);
assert.equal(complex.path, 'semantic'); assert.deepEqual(Array.from(complex.subjects), ['高等数学', '线性代数']);
assert.equal(complex.timeBudgetMinutes, 60);
assert.equal(router.decide('今晚就剩60分钟了，微积分考试更急，不过线代最近欠得也挺多，怎么弄比较好？', base, false).path, 'semantic');
assert.equal(router.decide('为什么你建议我先学线性代数？', base, false).path, 'semantic');
assert.equal(router.decide('你觉得我今天应该先学高数还是线代？', base, false).path, 'semantic');
assert.equal(router.decide('我今天真的一点都不想学，但高数马上考试了，我该怎么办？', base, false).path, 'semantic');
assert.equal(router.decide('线代最近落下不少，我今晚想补一下。', base, false).path, 'semantic');
console.log('PASS Cases 1-6/8/9 router: only unambiguous single actions use deterministic execution');

const proposal = { mode: 'advice', intent: 'allocate_study_time', executionRequested: false,
  subjects: [{ subject: '高等数学', reason: '目标日期信息' }, { subject: '线性代数', reason: '用户希望兼顾' }],
  timeBudgetMinutes: 60, needsExplanation: true, confirmationRequired: true,
  allocation: [{ taskId: math.id, minutes: 35 }, { taskId: linear.id, minutes: 25 }] };
const beforeValidation = JSON.stringify(base);
semanticValidator.validate(clone(proposal), base, now);
assert.equal(JSON.stringify(base), beforeValidation);
assert.throws(() => semanticValidator.validate({ ...clone(proposal), allocation: [{ taskId: 'fake', minutes: 20 }] }, base, now));
console.log('PASS semantic validator: real taskIds, bounded time, confirmation required, zero mutation');

const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const methods = index.slice(index.indexOf('  private smallPlanetHistory('), index.indexOf('  private todayCourseHint('));
let mode = 'success'; const requests = [];
const harnessBox = { exports: {}, Date: Clock, console, TodayIntentService: intents,
  AgentDecisionService: decisions, TodayStudyOverrideService: overrides, PlanValidator: validator,
  StudyDecisionDebug: debug, LearningActionService: load('LearningActionService').LearningActionService,
  SmallPlanetConversationRouter: router, SmallPlanetSemanticValidator: semanticValidator,
  SmallPlanetClient: { reply: async request => {
    requests.push(clone(request));
    if (mode === 'failure') throw new Error('timeout');
    if (request.understandingRequested) return { ok: true, source: 'openpangu',
      reply: '你今晚只有1小时，可以先给高数35分钟、线代25分钟。高数目标日期更近，线代也保留连续性；确认后我再调整。',
      understanding: clone(proposal) };
    return { ok: true, source: 'openpangu', reply: '已经按刚才确认的方案更新今天安排。' };
  } } };
vm.runInNewContext(ts.transpileModule(`class Harness {
  state; tasks=[]; academicGoals=[]; todayStudyOverride={date:'2026-09-28'}; actionClock=Date.now();
  currentTaskIndex=0; isRunning=false; setupScheduleReady=false; scheduleItems=[]; floatingAgentMessages=[];
  todayStrategyText=''; pendingSmallPlanetProposal=undefined; todayIntentUndo=[]; agentRequestId=0;
  agentGenerated=false; floatingPlanPending=false; agentCommitBusy=false; agentLoading=false;
  actionDeferrals=[]; preferredTaskId=''; floatingAgentError=''; todayCommitSettlement=Promise.resolve();
  snapshot(){return {...this.state,tasks:this.tasks,academicGoals:this.academicGoals,todayStudyOverride:this.todayStudyOverride};}
  availableMinutesToday(){return 60;} beijingDayKey(){return '2026-09-28';}
  async persistState(){this.disk=JSON.stringify(this.snapshot());}
  addFloatingMessage(role,text,mode){this.floatingAgentMessages.push({id:String(this.floatingAgentMessages.length),role,text,mode,createdAt:Date.now()});}
  requestTodayPlan(){throw Error('semantic route must not call today-plan');}
  ${methods}
} exports.Harness=Harness;`, { compilerOptions: { target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS } }).outputText, harnessBox);

(async () => {
  const h = new harnessBox.exports.Harness(); h.state = clone(base); h.tasks = clone(base.tasks);
  h.academicGoals = clone(base.academicGoals); h.todayStudyOverride = clone(base.todayStudyOverride);
  h.floatingAgentMessages = [{ id: 'old-u', role: 'user', text: '今天任务有点多', mode: 'planning', createdAt: now - 1 }];
  const beforeAdviceTasks = JSON.stringify(h.tasks); const beforeAdviceOverride = JSON.stringify(h.todayStudyOverride);
  await h.handleTodayConversation(complexText);
  assert.equal(requests.at(-1).understandingRequested, true);
  assert.equal(requests.at(-1).conversationContext.length, 1);
  assert.equal(JSON.stringify(h.tasks), beforeAdviceTasks);
  assert.equal(JSON.stringify(h.todayStudyOverride), beforeAdviceOverride);
  assert.equal(h.pendingSmallPlanetProposal.confirmationRequired, true);
  assert.ok(h.tasks.every(task => !task.title.includes('也落下不少')));
  await h.handleTodayConversation('行，就按你说的来。');
  assert.deepEqual(Array.from(h.todayStudyOverride.suggestedTaskIds), [math.id, linear.id]);
  assert.equal(h.todayStudyOverride.preferredTaskId, math.id);
  assert.equal(h.todayStudyOverride.preferredSubject, '');
  assert.equal(h.todayStudyOverride.availableMinutes, 60);
  assert.equal(h.pendingSmallPlanetProposal, undefined);
  console.log('PASS Case 3/5/6/7/9: advice is read-only, context reaches Pangu, confirmation alone persists real taskIds');

  mode = 'failure';
  const direct = new harnessBox.exports.Harness(); direct.state = clone(base); direct.tasks = clone(base.tasks);
  direct.academicGoals = clone(base.academicGoals); direct.todayStudyOverride = clone(base.todayStudyOverride);
  await direct.handleTodayConversation('今天学高数');
  assert.equal(direct.todayStudyOverride.preferredTaskId, math.id);
  const stable = JSON.stringify(direct.todayStudyOverride);
  await direct.handleTodayConversation('高数和线代怎么分配？');
  assert.equal(JSON.stringify(direct.todayStudyOverride), stable);
  assert.equal(direct.pendingSmallPlanetProposal, undefined);
  console.log('PASS Case 10: offline explicit command persists; complex advice falls back without mutation');
})().catch(error => { console.error(error); process.exitCode = 1; });
