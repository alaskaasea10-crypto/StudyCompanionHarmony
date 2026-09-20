// Captures two issues found by live acceptance on 2026-09-09. No network or user data.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]);
const root=path.resolve(__dirname,'..'),cache=new Map();
function load(name){
  if(cache.has(name))return cache.get(name);
  const box={exports:{},require:spec=>load(path.basename(spec))};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText,box);cache.set(name,box.exports);return box.exports;
}
const {BankLearningBridge:bridge}=load('BankLearningBridge');
const {PlanValidator:validator}=load('PlanValidator');
const {PlanCommitService:commit}=load('PlanCommitService');
const {BankPlanBudget:budget}=load('BankPlanBudget');
const {LearningDecisionPolicy:policy}=load('LearningDecisionPolicy');
const existing=[{id:'pending',title:'完成英语阅读',subject:'英语四六级',minutes:10,completed:false}];
const request={requestText:'针对矩阵乘法运算顺序补学和复测',profile:{subject:'线性代数'},context:{
  availableMinutesToday:30,unfinishedTasks:existing,bankEvidence:[{subject:'线性代数',knowledgePoint:'矩阵乘法 · 运算顺序',
    status:'建议复习',distinctQuestions:1,latestCorrect:0}]
}};
const raw={summary:'复习后复测',detectedSubject:'线性代数',recommendationReasons:[],source:'openpangu',model:'recorded-fixture',
  usage:{promptTokens:0,completionTokens:0,totalTokens:0},totalMinutes:30,tasks:[
    {title:'复盘矩阵乘法运算顺序规则并做1道顺序判断题',subject:'线性代数',type:'review',minutes:15,priority:1,reason:'薄弱点'},
    {title:'完成矩阵乘法运算顺序专项复测题并核对解析',subject:'线性代数',type:'quiz',minutes:15,priority:2,reason:'验证'}
  ]};
request.context.availableMinutesToday=budget.available(30,existing);
assert.equal(request.context.availableMinutesToday,20);
const final=validator.validate(bridge.prioritize(raw,request),request.context.availableMinutesToday);
const accepted=commit.appendBankPlan(existing,final,30);
const checks=[
  ['combined pending work fits remaining 30 minutes',()=>assert.ok(accepted.tasks.filter(t=>!t.completed).reduce((s,t)=>s+t.minutes,0)<=30)],
  ['retest survives review prioritization',()=>assert.ok(final.tasks.some(t=>/复测/.test(t.title)))]
];
for(const [name,check] of checks){try{check();console.log('PASS:',name);}catch{console.error('FAIL:',name);process.exitCode=1;}}
assert.equal(final.tasks.length,2);
assert.equal(final.tasks[0].title,raw.tasks[0].title,'reuse model review without a duplicate insertion');
assert.equal(final.tasks[0].minutes,15);assert.equal(final.tasks[1].minutes,5);
assert.throws(()=>commit.appendBankPlan(existing,final,25),/重新生成/,'confirmation rechecks time');
assert.equal(existing.length,1);
assert.equal(commit.appendBankPlan(accepted.tasks,final,30).tasks.length,accepted.tasks.length,'duplicate confirmation is a no-op');
assert.equal(budget.available(30,[...existing,{minutes:100,completed:true}]),20);
assert.equal(budget.available(5,existing),0);
assert.throws(()=>budget.available(NaN,existing));
assert.throws(()=>budget.available(30,[{minutes:NaN,completed:false}]));
for(const minutes of [5,9,10,20,30]){
  request.context.availableMinutesToday=minutes;
  const p=validator.validate(bridge.prioritize(raw,request),minutes);
  assert.ok(p.totalMinutes<=minutes);
  assert.equal(p.tasks.some(t=>t.type==='quiz'),minutes>=10);
  if(minutes<10)assert.ok(p.summary.includes('复测暂缓'));
}
const input={requestText:'矩阵补学',profile:{subject:'线性代数',dailyMinutes:60},energyState:'一般',tasks:existing,
  metrics:{todayFocusMinutes:30},quizAttempts:[],knowledgeMastery:[],bankAppendMode:true};
assert.equal(policy.buildRequest(input).context.availableMinutesToday,20);
input.bankAppendMode=false;
assert.equal(policy.buildRequest(input).context.availableMinutesToday,30,'ordinary replacement mode is unchanged');
console.log('PASS: budget reservation, confirm-time changes, dedup, review reuse and short-budget retest policy');
