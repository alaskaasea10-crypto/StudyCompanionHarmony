const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
let now = Date.parse('2026-09-28T14:00:00+08:00');
class Clock extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
const cache = new Map();
let modelPlan;
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (name === '@kit.ArkData') return {};
  if (name === 'AgentClient') return { AgentClient: { generateTodayPlan: async () => {
    if (modelPlan) return modelPlan;
    throw Error('offline regression, no network');
  } } };
  if (cache.has(name)) return cache.get(name);
  const file = ['services', 'models', 'utils'].map(dir => path.join(ets, dir, name + '.ets')).find(fs.existsSync);
  const box = { exports: {}, Date: Clock, console, require: id => load(path.basename(id)) };
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports); return box.exports;
}
const intents = load('TodayIntentService').TodayIntentService;
const overrides = load('TodayStudyOverrideService').TodayStudyOverrideService;
const actions = load('LearningActionService').LearningActionService;
const decisions = load('AgentDecisionService').AgentDecisionService;
const validator = load('PlanValidator').PlanValidator;
const outcomes = load('TaskOutcomeService').TaskOutcomeService;
const deletion = load('StudyTaskDeletionService').StudyTaskDeletionService;
const policy = load('LearningDecisionPolicy').LearningDecisionPolicy;
const orchestrator = load('LearningPlanningOrchestrator').LearningPlanningOrchestrator;
const Repository = load('StudyRepository').StudyRepository;
const clone = obj => JSON.parse(JSON.stringify(obj));
const math = { id: 'math-review-001', title: '高等数学核心知识点复习', subject: 'AdvancedMath', minutes: 40, completed: false, source: 'manual' };
const linear = { id: 'linear-001', title: '线性代数矩阵章节复习', subject: 'LinearAlgebra', minutes: 25, completed: false, source: 'manual' };
const base = { profileCompleted: true, profileSubject: '线性代数', profileDailyMinutes: 60,
  tasks: [linear, math], todayStudyOverride: { date: '2026-09-28', availableMinutes: 60 },
  currentTaskIndex: 0, remainingSeconds: 0, isRunning: false, focusElapsedSeconds: 0,
  focusSegmentStartedAt: 0, focusSessionCredited: true, focusRecords: [], todayMinutes: 0,
  studyDayKey: '2026-09-28', energyState: '一般', quizAttempts: [], knowledgeMastery: [],
  setupScheduleReady: false, scheduleItems: [], actionDeferrals: [], deletedTaskIds: [],
  academicGoals: [{ id: 'math-goal', title: '高等数学考试', subject: '高等数学', deadline: '2026-09-29', completed: false }] };
const decide = s => decisions.decide(s, now);
function apply(text, state = base, confirm = false) {
  const before = JSON.stringify(state);
  const r = intents.resolve(text, state, now, confirm);
  assert.equal(JSON.stringify(state), before, 'resolution is a pure proposal');
  assert.equal(r.kind, 'commit', `${text}: ${r.kind} ${r.message}`);
  validator.validateTodayCreation(state, r.intent, r.createdTasks || [], r.override, now);
  return { ...clone(state), tasks: clone(state.tasks).concat(r.createdTasks || []), todayStudyOverride: clone(r.override) };
}
function sameSubject(state, name) {
  const d = decide(state);
  assert.equal(overrides.subjectName(d.recommendedAction.subject), name);
  assert.equal(d.recommendedAction.taskId, d.dailyPlan[0]?.taskId);
  assert.ok(d.dailyPlan.every(p => overrides.subjectName(p.subject) === name));
  return d;
}
function request(s) {
  const d = decide(s);
  return policy.buildRequest({ requestText: '帮我安排今天', profile: { name: '', grade: '', major: '', subject: '高等数学',
    goal: '', examDate: '', dailyMinutes: 60, preferredTime: '', learningStyle: '', supportStyle: '' },
    date: overrides.date(now), energyState: '一般', examDays: 999, scheduleReady: s.setupScheduleReady,
    scheduleItems: s.scheduleItems, tasks: s.tasks, metrics: { todayFocusMinutes: 0, todayFocusSessionCount: 0,
      quizAttemptCount: 0, quizCorrectCount: 0 }, quizAttempts: [], knowledgeMastery: [],
    todayStudyOverride: s.todayStudyOverride, confirmedAvailableMinutes: s.todayStudyOverride?.availableMinutes,
    localDailyPlanTaskIds: d.dailyPlan.map(p => p.taskId), localDailyPlanMinutes: d.dailyPlan.map(p => p.suggestedMinutes),
    eligibleTaskIds: actions.candidates(s, now).map(c => c.task.id), protectedStage: d.recommendedAction.stage,
    protectedTaskId: ['resume', 'verify'].includes(d.recommendedAction.stage) ? d.recommendedAction.taskId : undefined });
}
const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
const methods = index.slice(index.indexOf('  private async commitTodayConversation('), index.indexOf('  private todayCourseHint('));
const harnessBox = { exports: {}, Date: Clock, console, PlanValidator: validator, TodayIntentService: intents,
  StudyDecisionDebug: load('StudyDecisionDebug').StudyDecisionDebug,
  SmallPlanetConversationRouter: load('SmallPlanetConversationRouter').SmallPlanetConversationRouter,
  SmallPlanetSemanticValidator: load('SmallPlanetSemanticValidator').SmallPlanetSemanticValidator,
  LearningActionService: actions };
vm.runInNewContext(ts.transpileModule(`class Harness {
  state; tasks=[]; todayStudyOverride; preferredTaskId=''; actionClock=0; todayIntentUndo=[];
  todayStrategyText=''; messages=[]; agentRequestId=0; agentCommitBusy=false; cloudRequests=0;
  pendingSmallPlanetProposal=undefined; agentLoading=false;
  snapshot() { return {...this.state, tasks:this.tasks, todayStudyOverride:this.todayStudyOverride}; }
  beijingDayKey() { return new Date(Date.now()+8*3600000).toISOString().slice(0,10); }
  async persistState() { await this.repository.saveChecked(this.snapshot()); }
  addFloatingMessage(role,text) { this.messages.push(text); }
  async addSmallPlanetReply(text, route, fallback) { this.addFloatingMessage('assistant', fallback); }
  requestTodayPlan() { this.cloudRequests++; }
  ${methods}
} exports.Harness=Harness;`, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText, harnessBox);
function harness(state) {
  const h = new harnessBox.exports.Harness(); h.state=clone(state); h.tasks=clone(state.tasks);
  h.todayStudyOverride=clone(state.todayStudyOverride); h.fail=false;
  const storage = new Map();
  h.repository = new Repository({ get: async (k,v) => storage.get(k) ?? v,
    put: async (k,v) => { if(h.fail) throw Error('disk failed'); storage.set(k,v); }, flush: async()=>{} });
  return h;
}
const pass = (letter, text) => console.log(`PASS ${letter}: ${text}`);
(async () => {
  const legacyMath = { id: 'legacy-math', title: '复习高等数学', subject: 'advanced_math', minutes: 25,
    completed: false, source: 'manual' };
  const s1 = apply('我想复习高等数学', { ...base, tasks: [legacyMath] });
  assert.equal(decide(s1).recommendedAction.taskId, legacyMath.id);
  const s2 = apply('我想复习高数', { ...base, tasks: [legacyMath] });
  assert.equal(decide(s2).recommendedAction.taskId, legacyMath.id);
  assert.equal(overrides.subjectName('高数'), overrides.subjectName('高等数学'));
  assert.equal(overrides.subjectName('高等数学'), overrides.subjectName('AdvancedMath'));
  assert.equal(overrides.subjectName('AdvancedMath'), overrides.subjectName('advanced_math'));
  assert.equal(overrides.subjectName('线代'), overrides.subjectName('LinearAlgebra'));
  assert.notEqual(overrides.subjectName('高数'), overrides.subjectName('线代'));
  console.log('PASS S1-S5: one canonical subject normalization path');
  const a = apply('我想复习高等数学');
  assert.equal(sameSubject(a,'高等数学').recommendedAction.taskId, math.id); assert.equal(a.tasks.length,2);
  pass('A','reuse existing identity');
  const onlyLinear={...base,tasks:[linear]};
  const b=apply('我想复习高等数学', onlyLinear);
  const newId=sameSubject(b,'高等数学').recommendedAction.taskId;
  assert.equal(b.tasks.length,2); assert.notEqual(newId,linear.id); assert.equal(b.tasks[1].source,'today-temporary');
  pass('B','controlled same-subject creation');
  const completedSameTitle = { id: 'math-history', title: '复习高等数学', subject: '高等数学', minutes: 25,
    completed: true, source: 'today-temporary', createdAt: now - 60000, completedAt: now - 30000 };
  const bHistory = apply('我想复习高等数学', { ...onlyLinear, tasks: [linear, completedSameTitle] });
  assert.equal(bHistory.tasks.length, 3);
  assert.notEqual(sameSubject(bHistory, '高等数学').recommendedAction.taskId, completedSameTitle.id);
  assert.equal(bHistory.tasks[2].source, 'today-temporary');
  pass('B-history','completed same-title history cannot intercept a new explicit learning intent');
  const bId = b.tasks[1].id;
  assert.ok(overrides.activeTaskIndices(b.tasks, b.todayStudyOverride, '2026-09-28')
    .some(index => b.tasks[index].id === bId));
  const bCompleted = { ...b, tasks: b.tasks.map(task => task.id === bId ? { ...task, completed: true } : task) };
  assert.ok(!overrides.activeTaskIndices(bCompleted.tasks, bCompleted.todayStudyOverride, '2026-09-28')
    .some(index => bCompleted.tasks[index].id === bId));
  const bDeleted = deletion.remove(bId, b.tasks, b.todayStudyOverride, b.actionDeferrals ?? [], b.deletedTaskIds ?? []);
  assert.ok(!bDeleted.tasks.some(task => task.id === bId));
  const bTomorrow = { ...b, todayStudyOverride: { ...b.todayStudyOverride, date: '2026-09-29' } };
  assert.ok(!overrides.activeTaskIndices(bTomorrow.tasks, bTomorrow.todayStudyOverride, '2026-09-29')
    .some(index => bTomorrow.tasks[index].id === bId));
  assert.equal(overrides.activeTaskIndices([linear, math], base.todayStudyOverride, '2026-09-28').length, 2);
  const taskStore = new Map();
  const taskRepository = new Repository({ get: async (key, value) => taskStore.get(key) ?? value,
    put: async (key, value) => taskStore.set(key, value), flush: async () => {} });
  await taskRepository.saveChecked(b);
  const restoredB = await taskRepository.load();
  assert.ok(overrides.activeTaskIndices(restoredB.tasks, restoredB.todayStudyOverride, '2026-09-28')
    .some(index => restoredB.tasks[index].id === bId));
  assert.equal(decide(restoredB).recommendedAction.taskId, bId);
  assert.match(fs.readFileSync(path.join(ets, 'pages/HomePage.ets'), 'utf8'),
    /TodayStudyOverrideService\.activeTaskIndices\(this\.tasks/);
  console.log('PASS T1-T7: Home, Adjust Today and restore share one active task universe and taskId');
  const c=apply('今晚40分钟复习高数',onlyLinear);
  assert.equal(c.todayStudyOverride.availableMinutes,40); assert.equal(c.tasks[1].minutes,40);
  assert.ok(sameSubject(c,'高等数学').dailyPlan.reduce((n,p)=>n+p.suggestedMinutes,0)<=40);
  const taskTime=apply('高数学40分钟',{...base,todayStudyOverride:{date:'2026-09-28',availableMinutes:60}});
  assert.equal(taskTime.todayStudyOverride.intent.minutesKind,'task'); assert.equal(taskTime.todayStudyOverride.availableMinutes,60);
  pass('C','budget versus single-action time');
  sameSubject(apply('不想学线代，今天学高数'),'高等数学'); pass('D','negation');
  sameSubject(apply('还是学线代吧',a),'线性代数'); pass('E','latest positive instruction');
  const strategy=intents.resolve('我不知道高数怎么复习',onlyLinear,now);
  assert.equal(strategy.kind,'strategy'); assert.match(strategy.message,/尚未加入今天/);
  assert.equal(strategy.createdTasks,undefined);
  const f=apply('我不知道高数怎么复习',onlyLinear,true); sameSubject(f,'高等数学');
  assert.equal(f.tasks.length,4);
  const strategist=harness(onlyLinear);
  await strategist.handleTodayConversation('我不知道高数怎么复习'); assert.equal(strategist.tasks.length,1);
  await strategist.handleTodayConversation('就按这个安排'); assert.equal(strategist.tasks.length,1);
  assert.equal(strategist.cloudRequests,0);
  pass('F','complex strategy is read-only without a validated semantic proposal');
  for(const text of ['你好','我好累','高数好难啊','考试怎么办','最近状态不好','陪我聊聊','高数是什么','今天不想学英语','不要线代']) {
    const r=intents.resolve(text,onlyLinear,now); assert.equal(r.createdTasks,undefined); assert.equal(r.override,undefined);
  }
  pass('G','ordinary chat and negative-only requests do not create');
  let h=apply('还是复习高数',b); h=apply('高数吧',h); assert.equal(h.tasks.length,b.tasks.length);
  assert.equal(sameSubject(h,'高等数学').recommendedAction.taskId,newId); pass('H','dedup');
  assert.equal(JSON.stringify(decide(a)),JSON.stringify(decide({...a,academicGoals:[{...base.academicGoals[0],deadline:'2026-10-28'}]})));
  pass('I','deadline isolation');
  const j=apply('今天学高数',{...base,setupScheduleReady:true,scheduleItems:[{id:'confirmed',weekday:1,startTime:'15:00',endTime:'16:00',course:'大学英语',location:''}]});
  sameSubject(j,'高等数学'); pass('J','schedule constrains time, not subject');
  const focus={...a,currentTaskIndex:1,isRunning:true,remainingSeconds:1200,focusSegmentStartedAt:now};
  const k=apply('接下来学线代',focus); assert.equal(decide(k).recommendedAction.taskId,math.id);
  assert.equal(k.todayStudyOverride.intent.subject,'线性代数'); pass('K','focus protection');
  const l=apply('接下来学线代',{...a,tasks:[linear,{...math,outcome:'focused'}]});
  assert.equal(decide(l).recommendedAction.stage,'verify'); assert.equal(decide(l).recommendedAction.taskId,math.id);
  const completed=outcomes.submit(l.tasks[1],true,'',now,'struggling');
  const after={...l,tasks:[linear,completed]}; sameSubject(after,'线性代数'); pass('L','pending feedback protects original then new intent');
  const listing=intents.resolve('后续学习规划列出来我看看',f,now);
  for(const p of decide(f).dailyPlan) assert.ok(listing.message.includes(`${p.title} · ${overrides.subjectName(p.subject)} · ${p.suggestedMinutes}分钟`));
  pass('M','list is actual dailyPlan');
  const persisted=harness(onlyLinear); await persisted.handleTodayConversation('今天高数40分钟');
  const restored=await persisted.repository.load();
  assert.equal(restored.todayStudyOverride.availableMinutes,40); sameSubject(restored,'高等数学');
  assert.equal(restored.todayStudyOverride.preferredTaskId,decide(restored).recommendedAction.taskId); pass('N','real Repository round trip');
  const day=now; now+=86400000;
  assert.equal(overrides.active(c,now),undefined); assert.ok(decide(c).dailyPlan.every(p=>p.taskId!==c.tasks[1].id));
  now=day; pass('O','cross-day temporary exclusion');
  const removed=deletion.remove(newId,b.tasks,b.todayStudyOverride,[],[]);
  const p={...b,...removed}; assert.equal(p.todayStudyOverride.preferredTaskId,'');
  assert.equal(p.todayStudyOverride.intent.taskId,undefined); assert.ok(decide(p).dailyPlan.every(i=>i.taskId!==newId)); pass('P','delete clears live references');
  const inconsistent={...math,id:'bad',subject:'线性代数'};
  assert.equal(overrides.consistentSubject(inconsistent),false);
  assert.equal(actions.candidates({...base,tasks:[inconsistent]},now).length,0);
  for(const task of f.tasks.slice(1)) assert.ok(overrides.consistentSubject(task)); pass('Q','title/subject integrity');
  const safe={id:'safe-fallback-task',title:'回顾高数',subject:'高等数学',minutes:25,source:'recovery',completed:false};
  assert.equal(decide({...base,tasks:[safe]}).dailyPlan.length,0);
  assert.equal(decide({...base,tasks:[]}).dailyPlan.length,0);
  assert.match(index.slice(index.indexOf('  private startTimer()'), index.indexOf('  private startTimerInterval()')), /realTask/);
  assert.throws(()=>validator.validateTodayCreation(base,{subject:'高等数学',action:'execute'},[safe],base.todayStudyOverride,now)); pass('R','safe fallback cannot execute or commit');
  const req=request(a);
  modelPlan={tasks:[{taskId:linear.id,title:linear.title,subject:linear.subject,minutes:25,priority:1,type:'review'}],
    summary:'wrong',detectedSubject:'线性代数',recommendationReasons:[],usage:{},totalMinutes:25,model:'test-double'};
  assert.throws(()=>validator.validateExisting(modelPlan,req));
  const fallback=await orchestrator.decide(req,[]); assert.equal(fallback.plan.source,'local-fallback');
  assert.equal(fallback.plan.tasks[0].taskId,math.id); modelPlan=undefined; pass('S','cross-subject model rejection + local fallback');
  const failed=harness(onlyLinear); await failed.repository.saveChecked(failed.snapshot()); failed.fail=true;
  await failed.handleTodayConversation('我想复习高数');
  assert.equal(failed.tasks.length,1); assert.equal(failed.todayStudyOverride.intent,undefined);
  assert.match(failed.floatingAgentError,/没有保存成功/); assert.equal(failed.messages.length,0);
  assert.equal((await failed.repository.load()).tasks.length,1); pass('T','repository failure rolls back added tasks and override, no success reply');
  const undo=harness(base); await undo.handleTodayConversation('今天学高数'); await undo.handleTodayConversation('还是学线代吧');
  undo.tasks[0]=outcomes.submit({...linear,outcome:'focused'},true,'',now,'normal');
  await undo.handleTodayConversation('返回上一步'); sameSubject(undo.snapshot(),'高等数学');
  assert.equal(undo.tasks[0].completed,true); pass('U','undo only arrangement, preserves task outcome');
  const v=harness(onlyLinear); await v.handleTodayConversation('我想复习高等数学');
  const vd=decide(v.snapshot()); assert.ok(v.messages.at(-1).includes(vd.recommendedAction.headline));
  assert.equal(vd.recommendedAction.taskId,vd.dailyPlan[0].taskId);
  assert.equal((index.match(/decision: this\.agentDecision\(\)/g)||[]).length,2);
  assert.doesNotMatch(index,/RecommendationService|this\.recommendation\(\)/); pass('V','chat and both pages share saved AgentDecision');
  const profile=load('StudyModels').createDemoTasks('高等数学',300);
  assert.ok(profile.every(t=>t.subject==='高等数学'&&overrides.consistentSubject(t)&&t.source==='profile'));
  pass('W','all four initial tasks use profile subject');
  const before=JSON.stringify(decide(a)); const reminder=intents.resolve('我的高数考试什么时候？',a,now);
  assert.equal(reminder.kind,'reminder'); assert.match(reminder.message,/2026-09-29/);
  assert.equal(JSON.stringify(decide(a)),before); pass('X','reminder is read-only');
  // Requested topic survives a complex sentence; this is not a fabricated knowledge gap.
  const complex=apply('我今天脑子有点乱，不想碰英语了，要不先把高数极限重新过一遍，大概半小时',onlyLinear);
  assert.equal(complex.todayStudyOverride.intent.subject,'高等数学');
  assert.equal(complex.todayStudyOverride.availableMinutes,30); assert.ok(complex.tasks.at(-1).title.includes('极限'));
  const skipped={...a,todayStudyOverride:{...a.todayStudyOverride,skippedTaskIds:[math.id]}};
  assert.equal(intents.resolve('复习高数',skipped,now).kind,'clarify');
  console.log('PASS additional: explicit topic and no duplication to bypass skip');

  // Execute the production Index path with only OS timer/Live View boundaries stubbed.
  const method=(start,end)=>index.slice(index.indexOf(start),index.indexOf(end));
  let liveStarts=0, liveStops=0;
  const focusBox={exports:{},Date:Clock,console,Harness:harnessBox.exports.Harness,
    TodayStudyOverrideService:overrides,LearningActionService:actions,AgentDecisionService:decisions,
    TaskOutcomeService:outcomes,StudyDataCenter:load('StudyDataCenter').StudyDataCenter,
    FocusClock:load('FocusClock').FocusClock,StudyDecisionDebug:load('StudyDecisionDebug').StudyDecisionDebug,
    StudyLiveViewService:{startOrResume:()=>liveStarts++,stop:()=>liveStops++}};
  vm.runInNewContext(ts.transpileModule(`class Flow extends Harness {
    currentTaskIndex=0; isRunning=false; remainingSeconds=0; focusElapsedSeconds=0; focusSegmentStartedAt=0;
    focusMinutes=25; focusSessionCredited=true; todayMinutes=0; studyDayKey='2026-09-28'; focusRecords=[];
    actionDeferrals=[]; actionMessage=''; currentTab=0; resultNote=''; resultChecked=false; resultExperience='';
    snapshot(){return {...super.snapshot(),currentTaskIndex:this.currentTaskIndex,isRunning:this.isRunning,
      remainingSeconds:this.remainingSeconds,focusElapsedSeconds:this.focusElapsedSeconds,
      focusSegmentStartedAt:this.focusSegmentStartedAt,focusMinutes:this.focusMinutes,
      focusSessionCredited:this.focusSessionCredited,todayMinutes:this.todayMinutes,focusRecords:this.focusRecords};}
    dailyAction(){return AgentDecisionService.decide(this.snapshot(),Date.now()).recommendedAction;}
    archiveInterruptedFocus(){if(this.isRunning) throw Error('unexpected active interruption');}
    hostAbilityContext(){return {};}
    startTimerInterval(){this.timerActive=true;} clearTimerInterval(){this.timerActive=false;}
    persistSilently(){} openFloatingPlanning(){throw Error('expected executable real task');}
    ${method('  private currentTask()', '  private currentQuizQuestion(')}
    ${method('  private runDailyAction()', '  private clearTimerInterval(')}
    ${method('  private beginFocus(', '  private startTimerInterval(')}
    ${method('  private finishFocus()', '  private setTaskCompleted(')}
    ${method('  private recordTaskResult(', '  private activeGoal(')}
  } exports.Flow=Flow;`,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,focusBox);
  const flow=new focusBox.exports.Flow(); const persistedFlow=harness(f);
  flow.state=clone(f); flow.tasks=clone(f.tasks); flow.todayStudyOverride=clone(f.todayStudyOverride);
  flow.repository=persistedFlow.repository;
  const startedId=decide(flow.snapshot()).recommendedAction.taskId;
  flow.runDailyAction(); assert.equal(flow.currentTask().id,startedId); assert.equal(flow.isRunning,true);
  assert.equal(liveStarts,1); now+=60000;
  flow.finishFocus(); assert.equal(flow.isRunning,false); assert.equal(flow.timerActive,false);
  assert.equal(liveStops,1); assert.equal(flow.focusRecords.length,1); assert.equal(flow.focusRecords[0].taskId,startedId);
  assert.equal(decide(flow.snapshot()).recommendedAction.stage,'verify');
  flow.resultExperience='struggling'; flow.resultChecked=true; flow.resultNote=''; flow.submitSelfResult();
  assert.equal(flow.tasks.find(t=>t.id===startedId).completed,true);
  const flowNext=sameSubject(flow.snapshot(),'高等数学');
  assert.notEqual(flowNext.recommendedAction.taskId,startedId);
  assert.equal(flowNext.recommendedAction.minutes,12);
  assert.equal(flow.tasks.length,f.tasks.length); now=day;
  const empty=new focusBox.exports.Flow(); empty.state=clone(base); empty.tasks=[];
  empty.todayStudyOverride=clone(base.todayStudyOverride); empty.remainingSeconds=1500;
  empty.startTimer(); assert.equal(empty.isRunning,false); assert.equal(liveStarts,1);
  console.log('PASS production Index chain: runDailyAction -> beginFocus -> finishFocus -> empty feedback -> same-subject replan, stable IDs and struggling duration; empty timer rejected');
})().catch(error=>{console.error(error);process.exitCode=1;});
