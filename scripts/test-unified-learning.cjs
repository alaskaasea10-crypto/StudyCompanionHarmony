const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict'), ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..'), cache = new Map();
const now = new Date('2026-09-11T10:00:00+08:00').getTime();
class Clock extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
let owner = '', cancelled = 0, published = [];
const stores = new Map();
const prefs = { getPreferences: async (_, name) => {
  if (!stores.has(name)) stores.set(name, new Map());
  const m = stores.get(name);
  return { get: async (k,d) => m.has(k) ? m.get(k) : d, put: async (k,v) => m.set(k,v), flush: async () => {} };
}};
const kits = {
  '@kit.ArkData': { preferences: prefs },
  '@kit.NotificationKit': { notificationManager: { cancel: async () => { cancelled++; },
    isNotificationEnabled: async () => true, publish: async r => { published.push(r); },
    SlotType: {SERVICE_INFORMATION: 1}, ContentType: {NOTIFICATION_CONTENT_BASIC_TEXT: 0} } },
  '@kit.AbilityKit': { wantAgent: { getWantAgent: async () => ({}), OperationType:{START_ABILITY: 0},
    WantAgentFlags: {UPDATE_PRESENT_FLAG: 0} } }
};
function evaluate(source, extra = {}) {
  const box = {exports: {}, Date: Clock, console, ...extra};
  vm.runInNewContext(ts.transpileModule(source, {compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  }}).outputText, box); return box.exports;
}
function load(name) {
  if (name === 'AccountSession') return {AccountSession: {owner: () => owner, generation: () => 1}};
  if (cache.has(name)) return cache.get(name);
  const exports = evaluate(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),
    {require: s => s.startsWith('@kit.') ? kits[s] ?? {} : load(path.basename(s))});
  cache.set(name, exports); return exports;
}
const {LearningActionService: action} = load('LearningActionService');
const {TaskOutcomeService: outcome} = load('TaskOutcomeService');
const {StudyWidgetService: widget} = load('StudyWidgetService');
const {PlanCommitService: plans} = load('PlanCommitService');
const {GoalPlanningService: goals} = load('GoalPlanningService');
const {StudyDataCenter: center} = load('StudyDataCenter');
const base = {profileCompleted:true,profileSubject:'数据结构',profileDailyMinutes:60,studyDayKey:'2026-09-11',
  todayMinutes:0,tasks:[],academicGoals:[],scheduleItems:[],setupScheduleReady:false,focusRecords:[],quizAttempts:[],
  currentTaskIndex:0,isRunning:false,remainingSeconds:0,focusElapsedSeconds:0,energyState:'一般'};
const task = {id:'t1',title:'整理栈的概念',subject:'数据结构',minutes:25,completed:false,goalId:'g',milestoneId:'m1'};
let s = {...base,tasks:[task]};
assert.equal(action.decide(s,[],now).stage,'execute');
assert.equal(widget.fromSnapshot(s).taskTitle,action.decide(s,[],now).headline);
assert.equal(action.decide({...s,todayMinutes:60},[],now).stage,'wait');
assert.equal(action.budget({...s,studyDayKey:'2026-09-10',todayMinutes:60},now),60);
assert.equal(action.budget({...s,isRunning:true,focusSegmentStartedAt:now-600000,focusMinutes:25},now),50);
assert.equal(action.decide({...s,todayMinutes:50},[],now).minutes,10);
const course = {id:'c',weekday:5,startTime:'10:20',endTime:'11:00',course:'上课',location:''};
assert.equal(action.decide({...s,setupScheduleReady:true,scheduleItems:[course]},[],now).minutes,15);
assert.equal(action.decide({...s,setupScheduleReady:true,scheduleItems:[{...course,startTime:'09:30'}]},[],now).stage,'wait');
assert.equal(action.decide({...s,isRunning:true,remainingSeconds:300},[],now).stage,'resume');
assert.equal(action.decide({...s,tasks:[{...task,outcome:'studying'}],remainingSeconds:300},[],now).stage,'resume');
const deferred = {...s,actionDeferrals:[{key:'task:t1',until:now+1800000,kind:'later'}]};
assert.equal(action.decide(deferred,[],now).stage,'wait');
assert.equal(action.decide(JSON.parse(JSON.stringify(deferred)),[],now+1800001).stage,'execute');
assert.equal(widget.fromSnapshot(deferred).target,'home');
const focused = outcome.focused(task,now);
assert.equal(focused.completed,false); assert.equal(focused.outcome,'focused');
assert.equal(action.decide({...s,tasks:[focused],todayMinutes:60},[],now).stage,'verify');
const self = outcome.submit(focused,true,'已整理三项概念',now+1);
assert.equal(self.completed,true); assert.equal(self.outcome,'submitted'); assert.equal(self.verifiedAt,0);
const bankTask = {...task,title:'攻克矩阵运算',subject:'线性代数'};
const bankFocused = outcome.focused(bankTask,now);
assert.equal(outcome.kind(bankTask),'self');
const evidence = ['a','b','c'].map(k => ({topicId:'matrix',subject:'线性代数',knowledgePoint:k,
  status:'初步掌握',distinctQuestions:2,latestCorrect:2,sessionStartedAt:now+1}));
assert.equal(outcome.bankPassed(bankFocused,evidence),true);
assert.equal(outcome.bankPassed(bankFocused,evidence.map(e=>({...e,sessionStartedAt:now-1}))),false);
assert.equal(outcome.bankPassed(bankFocused,evidence.slice(0,1)),false);
assert.equal(outcome.bankPassed(bankFocused,evidence.map(e=>({...e,status:'正在巩固'}))),false);
const failed = outcome.submit(bankFocused,false,'需巩固',now+1);
assert.equal(failed.completed,false); assert.equal(failed.outcome,'submitted');
const passed = outcome.submit(bankFocused,true,'换题验证通过',now+2);
assert.equal(passed.outcome,'submitted'); assert.equal(center.normalizeTasks([passed])[0].verifiedAt,0);
const goal = {id:'g',subject:'数据结构',title:'课程项目',deadline:'2026-09-20',createdAt:now,
  completed:false,estimatedMinutes:120,milestones:[{id:'m1',title:'整理概念',minutes:30,completed:false},{id:'m2',title:'实现代码',minutes:30,completed:false}]};
const other = {...task,id:'other',goalId:'g2',subject:'操作系统'}, manual={...task,id:'manual',source:'manual',goalId:undefined};
const plan = {detectedSubject:'数据结构',source:'openpangu',tasks:[{title:'整理接口',subject:'数据结构',minutes:15},{title:'完成接口草稿',subject:'数据结构',minutes:15}]};
const committed = plans.reconcile([task,other,manual,focused],plan,goal);
assert.ok(committed.tasks.includes(other)); assert.ok(committed.tasks.includes(manual)); assert.ok(committed.tasks.includes(focused));
assert.ok(committed.tasks.slice(-2).every(t=>t.goalId==='g'&&t.milestoneId==='m1'));
const legacyRunning={...task,goalId:undefined,milestoneId:undefined,source:'legacy'};
assert.ok(plans.reconcile([legacyRunning],plan,goal,'t1').tasks.includes(legacyRunning));
// 执行真实 Index 方法：计时结束不推进目标；同阶段所有任务提交后才解锁。
const index = fs.readFileSync(path.join(root,'entry/src/main/ets/pages/Index.ets'),'utf8');
function method(start,end) { return index.slice(index.indexOf(start),index.indexOf(end)); }
const H = evaluate(`class H {
  tasks=[]; academicGoals=[]; currentTaskIndex=0; focusElapsedSeconds=60; focusMinutes=25;
  isRunning=false; focusSessionCredited=false; todayMinutes=0; focusRecords=[]; studyDayKey='2026-09-11';
  currentTask(){return this.tasks[this.currentTaskIndex];} clearTimerInterval(){} persistSilently(){}
  openTaskResult(index){this.opened=index;} setTaskCompleted(){throw Error('timer must not complete task');}
  ${method('  private finishFocus()', '  private setTaskCompleted(')}
  ${method('  private advanceGoalMilestone(', '  private runDailyAction()')}
} exports.H=H;`,{TaskOutcomeService:outcome,StudyDataCenter:center,GoalPlanningService:goals,FocusClock:load('FocusClock').FocusClock}).H;
const h = new H();h.tasks=[task];h.finishFocus();
assert.equal(h.tasks[0].completed,false);assert.equal(h.tasks[0].outcome,'focused');assert.equal(h.opened,0);
const before=h.focusRecords.length;h.finishFocus();assert.equal(h.focusRecords.length,before);
h.academicGoals=[goal];h.tasks=[{...task,completed:true},{...task,id:'t2',completed:false}];
h.advanceGoalMilestone(h.tasks[0],true);assert.equal(h.academicGoals[0].milestones[0].completed,false);
h.tasks[1].completed=true;h.advanceGoalMilestone(h.tasks[1],true);
assert.equal(h.academicGoals[0].milestones[0].completed,true);assert.ok(h.tasks.some(t=>t.milestoneId==='m2'));
console.log('PASS unified decision: budget/day rollover/course gap/resume/deferral persistence/widget parity');
console.log('PASS results: timer is not completion; self-report is not mastery; fresh bank evidence; grouped milestones; plan preserves context');
// 新主线：旧题库证据不能抢占行动，开始补学直接进入共学光场。
const mathState={...base,profileSubject:'线性代数',tasks:[bankTask]};
const next=action.decide(mathState,evidence.map(e=>({...e,status:'建议复习'})),now);
assert.equal(next.stage,'execute'); assert.equal(next.actionTitle,'开始补学');
assert.equal(action.decide({...base,profileSubject:'线性代数'},[],now).stage,'plan');
const Router=evaluate(`class Router {
 actionMessage=''; actionClock=0; currentTab=0;
 dailyAction(){return this.action;}
 beginFocus(i,m){this.started=[i,m];this.currentTab=3;}
 openTaskResult(i){this.result=i;this.currentTab=3;}
 ${method('  private runDailyAction()', '  private clearTimerInterval()')}
} exports.Router=Router;`).Router;
const router=new Router();router.action=next;router.runDailyAction();
assert.equal(router.currentTab,3);assert.equal(router.started[0],0);
router.action={stage:'plan'};router.runDailyAction();assert.equal(router.currentTab,2);
const hub=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/LearningHubPage.ets'),'utf8');
assert.ok(!hub.includes('练习与错题'));assert.ok(hub.includes("'和 Agent 聊聊'"));
assert.ok(hub.includes("item.id === 'matrix'"));
const {VideoCatalog}=load('VideoCatalog');
for(const id of ['career','housing','insurance','contract']) assert.ok(VideoCatalog.modules().some(m=>m.id===id));
assert.ok(!fs.existsSync(path.join(root,'entry/src/main/ets/pages/QuestionBankPage.ets')));
assert.ok(!index.includes('currentTab = 7'));
const focusUI=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/FocusPage.ets'),'utf8');
assert.ok(!focusUI.includes("Text('即时小测')"));assert.ok(focusUI.includes('还有不明白的，问 Agent'));
console.log('PASS simplified flow: Agent -> focus; no bank routes; academic resources separate from squad resources');
const CourseHints=evaluate(`class CourseHints {
 setupScheduleReady=false; actionClock=${now}; scheduleItems=[];
 ${method('  private todayCourseHint()', '  private requestTodayPlan(')}
} exports.CourseHints=CourseHints;`).CourseHints;
const hints=new CourseHints();
assert.ok(hints.todayCourseHint().includes('未导入'));
hints.setupScheduleReady=true;assert.equal(hints.todayCourseHint(),'今天没有课程');
hints.scheduleItems=[{weekday:5,startTime:'14:00',endTime:'15:00',course:'英语'},
 {weekday:5,startTime:'11:00',endTime:'12:00',course:'线性代数'}];
assert.equal(hints.todayCourseHint(),'2 节 · 下一节 11:00 线性代数');
hints.actionClock=now+3600000;assert.ok(hints.todayCourseHint().startsWith('正在上课 · 线性代数'));
hints.actionClock=now+5*3600000;assert.equal(hints.todayCourseHint(),'今日 2 节课已结束');
hints.actionClock=now+24*3600000;assert.equal(hints.todayCourseHint(),'今天没有课程');
assert.ok(hub.indexOf('TextArea(')>hub.indexOf('Button(this.actionTitle)'));
assert.ok(!hub.includes("this.Module('和 Agent 聊聊'"));
assert.ok(!hub.includes("this.Module('课表与时间'"));
assert.ok(hub.includes('!this.agentBusy && this.agentInput.trim().length > 0'));
assert.ok(index.includes('courseHint: this.todayCourseHint()'));
console.log('PASS learning layout and course hints: direct input; empty/busy guard; upcoming/current/finished/day rollover');
(async()=>{
 const {ActiveReminderService: reminders}=load('ActiveReminderService');
 const study=await prefs.getPreferences({},'learner_profile');
 const notify={...base,profileSubject:'线性代数',notificationEnabled:true,notificationTaskEnabled:true};
 await study.put('study_state_v1',JSON.stringify(notify));
 await reminders.publishFromStoredState({});
 assert.equal(published.length,1); assert.ok(published[0].content.normal.text.includes('想补上哪里'));
 const decision=action.decide(notify,[],now);
 await study.put('study_state_v1',JSON.stringify({...notify,actionDeferrals:[{key:decision.key,until:now+1800000,kind:'later'}]}));
 await reminders.publishFromStoredState({});assert.equal(published.length,1);assert.ok(cancelled>0);
 owner='private';await reminders.publishFromStoredState({});assert.equal(published.length,1);
 console.log('PASS reminders: same next action, deferred advice cancelled, private account protected (mocked system APIs)');
})().catch(e=>{console.error(e);process.exitCode=1;});
