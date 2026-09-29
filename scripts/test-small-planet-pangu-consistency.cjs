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
  const file = ['services','models','utils'].map(dir=>path.join(ets,dir,name+'.ets')).find(fs.existsSync);
  const box={exports:{},Date:Clock,console,require:id=>load(path.basename(id))};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,
    module:ts.ModuleKind.CommonJS}}).outputText,box); cache.set(name,box.exports); return box.exports;
}
const overrides=load('TodayStudyOverrideService').TodayStudyOverrideService;
const intents=load('TodayIntentService').TodayIntentService;
const decisions=load('AgentDecisionService').AgentDecisionService;
const semanticValidator=load('SmallPlanetSemanticValidator').SmallPlanetSemanticValidator;
const clone=value=>JSON.parse(JSON.stringify(value));
const math={id:'math-1',title:'复习高等数学',subject:'AdvancedMath',minutes:25,completed:false,source:'manual'};
const linear={id:'linear-1',title:'整理线性代数矩阵笔记',subject:'LinearAlgebra',minutes:25,completed:false,source:'manual'};
const base={profileCompleted:true,profileDailyMinutes:180,tasks:[math,linear],todayStudyOverride:{date:'2026-09-28'},
  currentTaskIndex:0,isRunning:false,remainingSeconds:0,focusRecords:[],todayMinutes:0,studyDayKey:'2026-09-28',
  actionDeferrals:[],deletedTaskIds:[],setupScheduleReady:false,scheduleItems:[],quizAttempts:[],knowledgeMastery:[]};
function apply(state,text) {
  const result=intents.resolve(text,state,now);
  assert.equal(result.kind,'commit',`${text} -> ${result.kind}`);
  return {...clone(state),tasks:clone(state.tasks).concat(result.createdTasks||[]),todayStudyOverride:clone(result.override)};
}
let state=apply(base,'我想复习高等数学');
const mathId=decisions.decide(state,now).recommendedAction.taskId;
state=apply(state,'我今天有2小时');
assert.equal(state.todayStudyOverride.availableMinutes,120);
assert.equal(state.todayStudyOverride.intent.subject,'高等数学');
assert.equal(decisions.decide(state,now).recommendedAction.taskId,mathId);
assert.equal(state.tasks.length,2);
assert.equal(intents.resolve('那我先学什么？',state,now).kind,'show');
state=apply(state,'还是学线代吧'); assert.equal(overrides.subjectName(decisions.decide(state,now).recommendedAction.subject),'线性代数');
state=apply(state,'算了，还是高数'); assert.equal(overrides.subjectName(decisions.decide(state,now).recommendedAction.subject),'高等数学');
assert.equal(state.tasks.length,2);
const strategy=intents.resolve('高数我完全不知道从哪开始',state,now);
assert.equal(strategy.kind,'strategy'); assert.equal(strategy.intent.subject,'高等数学'); assert.equal(strategy.createdTasks,undefined);
const tired=intents.resolve('我有点累，今天不想学太久',state,now);
assert.equal(tired.kind,'clarify'); assert.equal(tired.createdTasks,undefined); assert.match(tired.message,/多少分钟/);
console.log('PASS Conversation 1-4: context continuity, subject switches, strategy and vague-time clarification');

const index=fs.readFileSync(path.join(ets,'pages/Index.ets'),'utf8');
assert.match(index,/EmotionalSupportClient\.reply\(text, supportHistory\)/);
assert.match(index,/SmallPlanetClient\.reply\(request\)/);
assert.match(index,/conversationContext: this\.smallPlanetHistory\(text\)/);
assert.match(index,/replySource: 'pangu'/);
assert.match(index,/replySource: 'deterministic-fallback'/);
console.log('PASS Conversation 5 + route audit: support uses Pangu and planning verbalization carries bounded history');

const methods=index.slice(index.indexOf('  private smallPlanetHistory('),index.indexOf('  private async commitTodayConversation('));
let mode='success'; const traces=[];
const box={exports:{},Date:Clock,console,AgentDecisionService:decisions,TodayStudyOverrideService:overrides,
  SmallPlanetSemanticValidator:semanticValidator,
  SmallPlanetClient:{reply:async request=>{assert.ok(request.conversationContext.length<=8);
    if(mode==='timeout') throw Error('timeout');
    if(mode==='invalid') return {ok:true,reply:'',source:'openpangu'};
    return {ok:true,reply:'好，我们就从当前这项高数复习开始。',source:'openpangu'};}},
  StudyDecisionDebug:{smallPlanet:value=>traces.push(value)}};
vm.runInNewContext(ts.transpileModule(`class Harness {
  floatingAgentMessages=[]; tasks=[]; academicGoals=[]; todayStudyOverride={date:'2026-09-28'}; actionClock=Date.now();
  currentTaskIndex=0; isRunning=false; setupScheduleReady=false; scheduleItems=[]; messages=[];
  pendingSmallPlanetProposal=undefined;
  snapshot(){return {...this.state,tasks:this.tasks,todayStudyOverride:this.todayStudyOverride};}
  availableMinutesToday(){return 120;} todayCourseHint(){return '今天没有课程';}
  addFloatingMessage(role,text,mode){this.messages.push({role,text,mode});}
  ${methods}
} exports.Harness=Harness;`,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,box);
const h=new box.exports.Harness(); h.state=clone(base); h.tasks=clone(base.tasks); h.todayStudyOverride=clone(state.todayStudyOverride);
h.floatingAgentMessages=[{role:'user',text:'我想复习高数',mode:'planning'},
  {role:'assistant',text:'可以。',mode:'planning'},{role:'user',text:'2小时',mode:'planning'}];
(async()=>{
  await h.addSmallPlanetReply('2小时','commit','本地可靠回复','persisted',true);
  assert.match(h.messages.at(-1).text,/当前这项高数/); assert.equal(traces.at(-1).replySource,'pangu');
  mode='timeout'; await h.addSmallPlanetReply('那我先学什么','show','先做复习高等数学。','read-only',false);
  assert.equal(h.messages.at(-1).text,'先做复习高等数学。');
  assert.equal(traces.at(-1).replySource,'deterministic-fallback');
  mode='invalid'; await h.addSmallPlanetReply('继续','show','继续当前高数复习。','read-only',false);
  assert.equal(h.messages.at(-1).text,'继续当前高数复习。');
  assert.equal(traces.at(-1).panguResponseValidated,false);
  console.log('PASS Pangu success/timeout/invalid: validated reply and deterministic fallback with trace source');
})().catch(error=>{console.error(error);process.exitCode=1;});
