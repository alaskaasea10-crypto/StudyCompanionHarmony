// Explicit opt-in: makes ONE real model request using the existing backend configuration.
// No device preferences or user task records are accessed. No credentials are printed.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const ts = require(process.argv[2]);
if (!process.argv.includes('--live')) throw Error('Pass --live to authorize one real model request');
const root = path.resolve(__dirname, '..');
const cache = new Map();
let origin = '', calls = 0, rawPlan, clientFailure = '';
async function jsonRequest(route, data) {
  const response = await fetch(origin + route, {
    method: data ? 'POST' : 'GET', headers: {'Content-Type':'application/json'},
    body: data ? JSON.stringify(data) : undefined, signal: AbortSignal.timeout(45000)
  });
  const body = await response.json();
  if (!response.ok || !body.ok) throw Error(body.error || `HTTP ${response.status}`);
  return body;
}
const client = { AgentClient: { generateTodayPlan: async request => {
  assert.equal(calls++,0,'only one paid call is permitted');
  try {
    rawPlan = (await jsonRequest('/api/agent/today-plan',request)).plan;
    return rawPlan;
  } catch (error) {
    clientFailure = error.message;
    throw error;
  }
} } };
function load(name) {
  if(name==='AgentClient') return client;
  if(cache.has(name)) return cache.get(name);
  const box={exports:{},console,require: spec => load(path.basename(spec))};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText,box);
  cache.set(name,box.exports);return box.exports;
}
async function run() {
  const server=spawn('python3',['-u','-c',
    'from http.server import ThreadingHTTPServer; from app import AgentRequestHandler; s=ThreadingHTTPServer(("127.0.0.1",0),AgentRequestHandler); print("ACCEPTANCE_PORT="+str(s.server_port),flush=True); s.serve_forever()'
  ],{cwd:path.join(root,'backend'),stdio:['ignore','pipe','pipe']});
  try {
    const port=await new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>reject(Error('Isolated server startup timed out')),10000);
      let text='';
      server.stdout.on('data',chunk=>{text+=chunk.toString();const m=text.match(/ACCEPTANCE_PORT=(\d+)/);if(m){clearTimeout(timeout);resolve(Number(m[1]));}});
      server.on('error',()=>{clearTimeout(timeout);reject(Error('Unable to launch isolated backend'));});
      server.on('exit',code=>{clearTimeout(timeout);reject(Error(`Isolated backend exited (${code})`));});
      // Backend logs are deliberately not echoed: only allowlisted acceptance results below are printed.
      server.stderr.on('data',()=>{});
    });
    origin=`http://127.0.0.1:${port}`;
    const health=await jsonRequest('/health');
    assert.equal(health.configured,true,'model credentials not configured');
    const {QuestionBank:bank}=load('QuestionBank');
    const {BankLearningBridge:bridge}=load('BankLearningBridge');
    const {LearningDecisionPolicy:policy}=load('LearningDecisionPolicy');
    const {LearningPlanningOrchestrator:orchestrator}=load('LearningPlanningOrchestrator');
    const {PlanCommitService:commit}=load('PlanCommitService');
    let state=bank.start(bank.empty(),Date.now());
    for(const id of bank.current(state).questionIds){const q=bank.question(id);state=bank.answer(state,q.skill==='运算顺序'?(q.answer+1)%4:q.answer);}
    const evidence=bridge.summarize(state);
    const existing=[{id:'acceptance-existing',title:'完成英语阅读',subject:'英语四六级',minutes:10,completed:false},
      {id:'acceptance-done',title:'已完成练习',subject:'线性代数',minutes:20,completed:true}];
    const original=JSON.stringify(existing);
    const input={requestText:'请针对矩阵乘法的运算顺序安排今天的补学和复测，优先解决诊断发现的问题。',
      profile:{name:'独立验收用户',grade:'大二',major:'计算机',goal:'查漏补缺',subject:'线性代数',examDate:'2026-10-01',
        dailyMinutes:60,preferredTime:'晚间',learningStyle:'练习驱动',supportStyle:'温和陪伴'},
      date:'2026-09-09',examDays:22,energyState:'一般',scheduleReady:false,scheduleItems:[],tasks:existing,
      metrics:{todayFocusMinutes:30,todayFocusSessionCount:1,quizAttemptCount:0,quizCorrectCount:0},
      quizAttempts:[],knowledgeMastery:[],bankEvidence:evidence,bankAppendMode:true};
    const request=policy.buildRequest(input);
    const started=Date.now();
    const decision=await orchestrator.decide(request,policy.priorityEvidence(input));
    assert.equal(decision.plan.source,'openpangu',`Real model failed; fallback is not a live acceptance pass: ${clientFailure || decision.notice}`);
    assert.equal(calls,1);
    assert.ok(decision.plan.tasks[0].title.includes('运算顺序'));
    assert.ok(decision.plan.totalMinutes<=request.context.availableMinutesToday);
    assert.equal(JSON.stringify(existing),original,'preview must not change tasks');
    const remainingMinutes=policy.availableMinutes(input.profile.dailyMinutes,input.metrics.todayFocusMinutes,input.energyState);
    const accepted=commit.appendBankPlan(existing,decision.plan,remainingMinutes);
    assert.equal(accepted.tasks[0],existing[0]);assert.equal(accepted.tasks[1],existing[1]);
    assert.equal(commit.appendBankPlan(accepted.tasks,decision.plan,remainingMinutes).tasks.length,accepted.tasks.length);
    const pendingMinutes=accepted.tasks.filter(t=>!t.completed).reduce((sum,t)=>sum+t.minutes,0);
    const firstIds=[...bank.current(state).questionIds];
    state=bank.start(state,Date.now()+1);
    assert.ok(bank.current(state).questionIds.every(id=>!firstIds.includes(id)));
    for(const id of bank.current(state).questionIds)state=bank.answer(state,bank.question(id).answer);
    const retest=bridge.summarize(state);
    assert.equal(retest[2].latestCorrect,1);assert.equal(retest[2].distinctQuestions,2);
    assert.equal(retest[2].status,'建议复习','old unresolved wrong question should remain visible');
    const lostRetest=rawPlan.tasks.some(t=>/复测|小测/.test(t.title)) && !decision.plan.tasks.some(t=>/复测|小测/.test(t.title));
    const issues=[];
    if(pendingMinutes>remainingMinutes)issues.push('combined pending budget exceeded');
    if(lostRetest)issues.push('retest removed by local review insertion');
    console.log(JSON.stringify({result:issues.length?'ACCEPTANCE_ISSUES_FOUND':'LIVE_FLOW_PASS',issues,realModelCalls:calls,model:rawPlan.model,usage:rawPlan.usage,
      elapsedMs:Date.now()-started,weakPoint:bridge.weakest(evidence).knowledgePoint,
      rawTasks:rawPlan.tasks.map(t=>({title:t.title,minutes:t.minutes})),
      finalTasks:decision.plan.tasks.map(t=>({title:t.title,minutes:t.minutes})),
      planMinutes:decision.plan.totalMinutes,appendBudget:request.context.availableMinutesToday,availableMinutes:remainingMinutes,
      pendingMinutesAfterAppend:pendingMinutes,
      combinedBudgetCheck:pendingMinutes<=remainingMinutes?'PASS':'FAIL: existing pending tasks plus appended plan exceed remaining budget',
      freshRetest:true,retestEvidence:retest[2],records:'isolated in-memory; user records untouched'},null,2));
    if(issues.length)process.exitCode=2;
  } finally {
    server.kill('SIGTERM');
    await new Promise(resolve=>{if(server.exitCode!==null)resolve();else server.once('exit',resolve);});
  }
}
run().catch(error=>{console.error('ACCEPTANCE FAILED:',error.message);process.exitCode=1;});
