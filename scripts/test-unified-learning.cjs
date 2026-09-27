const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict'), ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..'), cache = new Map();
const now = new Date('2026-09-11T10:00:00+08:00').getTime();
class Clock extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
let owner = '', cancelled = 0, published = [], wantRequests = [];
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
  '@kit.AbilityKit': { wantAgent: { getWantAgent: async options => { wantRequests.push(options); return {}; }, OperationType:{START_ABILITY: 0},
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
  if (name === 'BuildProfile') return {DEBUG: false};
  if (cache.has(name)) return cache.get(name);
  const serviceFile = path.join(root,`entry/src/main/ets/services/${name}.ets`);
  const filename = fs.existsSync(serviceFile) ? serviceFile :
    path.join(root,`entry/src/main/ets/utils/${name}.ets`);
  const exports = evaluate(fs.readFileSync(filename,'utf8'),
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
const internalSubjectTask={...task,id:'internal-subject',title:'复习CollegeEnglish听力',subject:'CollegeEnglish'};
assert.equal(widget.fromSnapshot({...s,tasks:[internalSubjectTask]}).subject,'大学英语');
assert.equal(widget.fromSnapshot({...s,tasks:[internalSubjectTask]}).taskTitle,'复习大学英语听力');
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
assert.ok(committed.tasks.slice(-2).every(t=>t.goalId===undefined&&t.milestoneId===undefined),
  'an explicit plan task must not be attached to legacy goal milestones');
const legacyRunning={...task,goalId:undefined,milestoneId:undefined,source:'legacy'};
assert.ok(plans.reconcile([legacyRunning],plan,goal,'t1').tasks.includes(legacyRunning));
// 执行真实 Index 方法：计时结束进入反馈，但长期目标不推进或生成任务。
const index = fs.readFileSync(path.join(root,'entry/src/main/ets/pages/Index.ets'),'utf8');
function method(start,end) { return index.slice(index.indexOf(start),index.indexOf(end)); }
let liveViewStops=0;
const H = evaluate(`class H {
  tasks=[]; academicGoals=[]; currentTaskIndex=0; focusElapsedSeconds=60; focusMinutes=25;
  isRunning=false; focusSegmentStartedAt=0; remainingSeconds=60; focusSessionCredited=false;
  todayMinutes=0; focusRecords=[]; studyDayKey='2026-09-11'; timerStops=0; persists=0;
  currentTask(){return this.tasks[this.currentTaskIndex];} clearTimerInterval(){this.timerStops++;}
  persistSilently(){this.persists++;}
  openTaskResult(index){this.opened=index;} setTaskCompleted(){throw Error('timer must not complete task');}
  ${method('  private finishFocus()', '  private setTaskCompleted(')}
} exports.H=H;`,{TaskOutcomeService:outcome,StudyDataCenter:center,GoalPlanningService:goals,
  FocusClock:load('FocusClock').FocusClock,StudyLiveViewService:{stop:()=>{liveViewStops++;}}}).H;
// Case A: normal running focus closes once and enters the existing feedback flow.
const h = new H();h.tasks=[task];h.isRunning=true;h.finishFocus();
assert.equal(h.isRunning,false);assert.equal(h.remainingSeconds,0);assert.equal(h.focusSegmentStartedAt,0);
assert.equal(h.timerStops,1);assert.equal(liveViewStops,1);assert.equal(h.focusRecords.length,1);
assert.equal(h.tasks[0].completed,false);assert.equal(h.tasks[0].outcome,'focused');assert.equal(h.opened,0);
// Case C: a repeated finish remains idempotent for records, feedback and completion.
const before=h.focusRecords.length,opened=h.opened;h.finishFocus();
assert.equal(h.focusRecords.length,before);assert.equal(h.opened,opened);assert.equal(h.tasks[0].completed,false);
// Case B: a completed task with a stale running session is cleaned up without new outcome/record.
const stale = new H();stale.tasks=[{...task,completed:true,completedAt:now,outcome:'submitted'}];
const beforeStaleLiveStops=liveViewStops;
stale.isRunning=true;stale.focusSegmentStartedAt=now-60000;stale.finishFocus();
assert.equal(stale.isRunning,false);assert.equal(stale.remainingSeconds,0);assert.equal(stale.focusSegmentStartedAt,0);
assert.equal(stale.timerStops,1);assert.equal(stale.focusRecords.length,0);assert.equal(stale.focusSessionCredited,true);
assert.equal(liveViewStops,beforeStaleLiveStops+1);
assert.equal(stale.tasks[0].completed,true);assert.equal(stale.tasks[0].outcome,'submitted');assert.equal(stale.opened,undefined);
console.log('PASS unified decision: budget/day rollover/course gap/resume/deferral persistence/widget parity');
console.log('PASS results: timer is not completion; self-report is not mastery; fresh bank evidence; goals do not generate tasks');
// 新主线：旧题库证据不能抢占行动，开始补学直接进入共学光场。
const mathState={...base,profileSubject:'线性代数',tasks:[bankTask]};
const next=action.decide(mathState,evidence.map(e=>({...e,status:'建议复习'})),now);
assert.equal(next.stage,'execute'); assert.equal(next.actionTitle,'开始这一项');
assert.equal(action.decide({...base,profileSubject:'线性代数'},[],now).stage,'plan');
const Router=evaluate(`class Router {
 actionMessage=''; actionClock=0; currentTab=0;
 dailyAction(){return this.action;}
 beginFocus(i,m){this.started=[i,m];this.currentTab=3;}
 openTaskResult(i){this.result=i;this.currentTab=3;}
 openFloatingPlanning(text){this.planningPrompt=text;}
 ${method('  private runDailyAction()', '  private clearTimerInterval()')}
} exports.Router=Router;`).Router;
const router=new Router();router.action=next;router.runDailyAction();
assert.equal(router.currentTab,3);assert.equal(router.started[0],0);
router.action={stage:'plan'};router.runDailyAction();assert.ok(router.planningPrompt.includes('今天剩余的时间'));
const hub=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/LearningHubPage.ets'),'utf8');
assert.ok(!hub.includes('练习与错题'));assert.ok(hub.includes("Text('星球学习空间')"));
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
hints.scheduleItems=[{id:'english-course',weekday:5,startTime:'14:00',endTime:'15:00',course:'英语'},
 {id:'linear-course',weekday:5,startTime:'11:00',endTime:'12:00',course:'线性代数'}];
assert.equal(hints.todayCourseHint(),'2 节 · 下一节 11:00 线性代数');
hints.actionClock=now+3600000;assert.ok(hints.todayCourseHint().startsWith('正在上课 · 线性代数'));
hints.actionClock=now+5*3600000;assert.equal(hints.todayCourseHint(),'今日 2 节课已结束');
hints.actionClock=now+24*3600000;assert.equal(hints.todayCourseHint(),'今天没有课程');
assert.ok(hub.includes("Text('今天的学习节奏')"));
assert.ok(hub.includes('ScheduleImportCard({'));
assert.ok(hub.includes('Button(this.primaryActionLabel())'));
assert.ok(index.includes('courseHint: this.todayCourseHint()'));
console.log('PASS learning layout and course hints: direct input; empty/busy guard; upcoming/current/finished/day rollover');
(async()=>{
 const {ActiveReminderService: reminders,ActiveReminderPolicy: reminderPolicy}=load('ActiveReminderService');
 const study=await prefs.getPreferences({},'learner_profile');
 const notify={...base,profileSubject:'线性代数',tasks:[task],notificationEnabled:true,
  notificationTaskEnabled:true,notificationClassEnabled:false,notificationReviewEnabled:false};
 const candidate=reminderPolicy.choose(notify);
 assert.equal(candidate.taskId,task.id);assert.equal(candidate.target,'next');
 assert.ok(candidate.text.includes(task.title));assert.ok(candidate.text.includes('25分钟'));
 const internalCandidate=reminderPolicy.choose({...notify,tasks:[internalSubjectTask]});
 assert.ok(internalCandidate.text.includes('大学英语'));assert.ok(!internalCandidate.text.includes('CollegeEnglish'));
 const scheduleAwareCandidate=reminderPolicy.choose({...notify,setupScheduleReady:true,
  scheduleItems:[{id:'confirmed-class',weekday:5,startTime:'10:20',endTime:'11:00',course:'专业课',location:''}]});
 assert.equal(scheduleAwareCandidate.taskId,task.id);
 assert.ok(scheduleAwareCandidate.text.includes('15分钟'));
 const scheduleOnly={...notify,tasks:[],notificationTaskEnabled:false,notificationClassEnabled:true,
  notificationReviewEnabled:false,
  scheduleItems:[{id:'confirmed-class',weekday:5,startTime:'10:20',endTime:'11:00',course:'专业课',location:''}]};
 // A: only a confirmed, real schedule may produce a class reminder.
 assert.equal(reminderPolicy.choose({...scheduleOnly,setupScheduleReady:true}).kind,'class');
 // B/C: unconfirmed and demo schedules are never production reminder evidence.
 assert.equal(reminderPolicy.choose({...scheduleOnly,setupScheduleReady:false}),undefined);
 assert.equal(reminderPolicy.choose({...scheduleOnly,setupScheduleReady:true,
  scheduleItems:[{...scheduleOnly.scheduleItems[0],id:'demo-class'}]}),undefined);
 // D: the same real recommendedAction remains available without a confirmed schedule.
 const withoutConfirmedSchedule=reminderPolicy.choose({...notify,setupScheduleReady:false,
  scheduleItems:[{...scheduleOnly.scheduleItems[0],id:'demo-class'}]});
 assert.equal(withoutConfirmedSchedule.taskId,task.id);
 // E/F: ongoing focus blocks conflicts; pending feedback retains the same real task.
 assert.equal(reminderPolicy.choose({...notify,isRunning:true,focusSegmentStartedAt:now-1000}),undefined);
 const pendingPolicyCandidate=reminderPolicy.choose({...notify,tasks:[{...task,outcome:'focused'}]});
 assert.equal(pendingPolicyCandidate.taskId,task.id);
 assert.ok(pendingPolicyCandidate.text.includes('学习收获'));
 await study.put('study_state_v1',JSON.stringify(notify));
 await reminders.publishFromStoredState({});
 assert.equal(published.length,1);assert.ok(published[0].content.normal.text.includes(task.title));
 assert.equal(wantRequests[0].wants[0].parameters.taskId,task.id);
 assert.equal(wantRequests[0].wants[0].parameters.target,'next');
 await reminders.publishFromStoredState({});assert.equal(published.length,1);
 await study.put('study_state_v1',JSON.stringify({...notify,tasks:[{...task,completed:true}]}));
 await reminders.publishFromStoredState({});assert.equal(published.length,1);
 await study.put('study_state_v1',JSON.stringify({...notify,
  todayStudyOverride:{date:'2026-09-11',skippedTaskIds:[task.id]}}));
 await reminders.publishFromStoredState({});assert.equal(published.length,1);
 await study.put('study_state_v1',JSON.stringify({...notify,isRunning:true,focusSegmentStartedAt:now-1000}));
 await reminders.publishFromStoredState({});assert.equal(published.length,1);
 const pendingTask={...task,outcome:'focused'};
 await study.put('study_state_v1',JSON.stringify({...notify,tasks:[pendingTask]}));
 await reminders.publishFromStoredState({});assert.equal(published.length,2);
 assert.ok(published[1].content.normal.text.includes('学习收获'));
 assert.equal(wantRequests[1].wants[0].parameters.taskId,task.id);
 await reminders.publishFromStoredState({});assert.equal(published.length,2);
 const decision=action.decide(notify,[],now);
 await study.put('study_state_v1',JSON.stringify({...notify,actionDeferrals:[{key:decision.key,until:now+1800000,kind:'later'}]}));
 await reminders.publishFromStoredState({});assert.equal(published.length,2);
 const reminderRouteMethod=method('  private handleWidgetRoute(', '  private handlePendingWidgetRoute(');
 const ReminderRouteHarness=evaluate(`class ReminderRouteHarness {
  profileLoaded=true;currentTab=9;isRunning=false;actionMessage='';runs=0;action={taskId:'t1'};
  dailyAction(){return this.action;}runDailyAction(){this.runs++;}
  ${reminderRouteMethod}
 } exports.ReminderRouteHarness=ReminderRouteHarness;`,
 {StudyActionRouter:load('StudyActionRouter').StudyActionRouter}).ReminderRouteHarness;
 const matchingRoute=new ReminderRouteHarness();
 matchingRoute.handleWidgetRoute(JSON.stringify({source:'studyNotification',target:'next',taskId:'t1',requestedAt:now}));
 assert.equal(matchingRoute.runs,1);
 const staleRoute=new ReminderRouteHarness();
 staleRoute.handleWidgetRoute(JSON.stringify({source:'studyNotification',target:'next',taskId:'old',requestedAt:now}));
 assert.equal(staleRoute.runs,0);assert.equal(staleRoute.currentTab,0);assert.ok(staleRoute.actionMessage.includes('已经更新'));
 console.log('PASS reminders: decision-sourced task, state guards, deduplication and taskId-safe routing');
})().catch(e=>{console.error(e);process.exitCode=1;});
