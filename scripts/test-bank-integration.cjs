const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const cache = new Map();
let modelResult;
const agent = { AgentClient: { generateTodayPlan: async () => {
  if (!modelResult) throw Error('offline test');
  return modelResult;
} } };
function evaluate(text, extra = {}) {
  const box = { exports: {}, console, Error, ...extra };
  vm.runInNewContext(ts.transpileModule(text, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText, box);
  return box.exports;
}
function load(name) {
  if (name === 'AgentClient') return agent;
  if (cache.has(name)) return cache.get(name);
  const file = path.join(root, `entry/src/main/ets/services/${name}.ets`);
  const result = evaluate(fs.readFileSync(file, 'utf8'), { require: spec => load(path.basename(spec)) });
  cache.set(name,result); return result;
}
const { QuestionBank: bank } = load('QuestionBank');
const { BankLearningBridge: bridge } = load('BankLearningBridge');
const { LearningDecisionPolicy: policy } = load('LearningDecisionPolicy');
const { LearningPlanningOrchestrator: orchestrator } = load('LearningPlanningOrchestrator');
const { PlanCommitService: commit } = load('PlanCommitService');
const { StudyRepository: Repository } = load('StudyRepository');
const completedRound = (s, now, wrong) => {
  s = bank.start(s,now);
  for (const id of bank.current(s).questionIds) {
    const q = bank.question(id); s = bank.answer(s,wrong && q.skill === '运算顺序' ? (q.answer+1)%4 : q.answer);
  } return s;
};
const makeInput = evidence => ({
  requestText:'请帮我补习矩阵乘法', profile: { name:'测试',grade:'大二',major:'计算机',subject:'线性代数',
    goal:'巩固',examDate:'2026-10-01',dailyMinutes:60,preferredTime:'晚间',learningStyle:'练习',supportStyle:'温和' },
  date:'2026-09-08',examDays:23,energyState:'一般',scheduleReady:false,scheduleItems:[],tasks:[],
  metrics:{todayFocusMinutes:45,todayFocusSessionCount:1,quizAttemptCount:0,quizCorrectCount:0},
  quizAttempts:[],knowledgeMastery:[],bankEvidence:evidence
});
const plan = { summary:'原始计划',detectedSubject:'线性代数',recommendationReasons:['模型理由'],
  tasks:[{title:'一般练习',subject:'线性代数',type:'practice',minutes:20,priority:1,reason:'复习'}],
  totalMinutes:20,source:'openpangu',model:'test',usage:{promptTokens:0,completionTokens:0,totalTokens:0} };
async function main() {
  let s = bank.start(bank.empty(),100);
  assert.equal(bridge.summarize(s).length,0);
  s = bank.answer(s,1);
  assert.equal(bridge.summarize(s).length,0,'partial round never influences planning');
  s = completedRound(bank.empty(),100,true);
  const evidence = bridge.summarize(s);
  assert.equal(evidence.length,3);
  assert.equal(bridge.weakest(evidence).knowledgePoint,'矩阵乘法 · 运算顺序');
  assert.equal(evidence[0].status,'正在巩固');
  const input = makeInput(evidence);
  const request = policy.buildRequest(input);
  const payload = JSON.stringify(request.context.bankEvidence);
  for(const key of ['questionIds','answers','options','prompt','score']) assert.ok(!payload.includes(`"${key}"`));
  assert.ok(policy.priorityEvidence(input)[0].includes('1道不同题最近0道答对'));
  modelResult = undefined;
  let decision = await orchestrator.decide(request,policy.priorityEvidence(input));
  assert.equal(decision.plan.source,'local-fallback');
  assert.ok(!decision.plan.tasks[0].title.includes('运算顺序'), 'legacy bank evidence no longer rewrites Agent tasks');
  assert.ok(decision.plan.totalMinutes <= 15);
  modelResult = plan;
  decision = await orchestrator.decide(request,policy.priorityEvidence(input));
  assert.equal(decision.plan.tasks[0].title,'一般练习');
  assert.equal(decision.notice,'');
  for(const budget of [5,10,15,30,60]) {
    request.context.availableMinutesToday=budget;
    const d=await orchestrator.decide(request,[]);
    assert.ok(d.plan.totalMinutes<=budget);
    assert.ok(d.plan.tasks.every(t=>t.minutes>=5));
  }
  input.requestText='今天只学习英语四六级';
  const english=policy.buildRequest(input);
  assert.equal(bridge.relevant(english).length,0);
  assert.equal(bridge.prioritize(plan,english),plan,'do not force matrix on English');
  input.knowledgeMastery=[{subject:'线性代数',knowledgePoint:'矩阵',score:10}];
  assert.ok(policy.priorityEvidence(input).every(r=>!r.includes('矩阵')));
  modelResult=undefined;
  const englishFallback=await orchestrator.decide(policy.buildRequest(input),[]);
  assert.ok(englishFallback.plan.tasks.every(t=>!t.title.includes('矩阵')));
  s=completedRound(s,200,false);
  assert.equal(bridge.weakest(bridge.summarize(s)).status,'建议复习','unresolved prior different question remains evidence');
  // Revisit the initially wrong question; its latest answer replaces the old one without adding evidence.
  for(let i=0;i<3;i++) s=completedRound(s,300+i,false);
  assert.equal(bridge.weakest(bridge.summarize(s)),undefined);
  const allCorrect=makeInput(bridge.summarize(s));
  assert.equal(bridge.prioritize(plan,policy.buildRequest(allCorrect)),plan);
  console.log('PASS: legacy evidence remains decodable but no longer overrides Agent plans');

  let raw='{"tasks":["old"]}',failures=1;
  const store={get:async()=>raw,put:async(k,v)=>{raw=v;},flush:async()=>{if(failures-->0)throw Error('disk');}};
  const repository=new Repository(store);
  await assert.rejects(repository.saveChecked({tasks:['new']}));assert.equal(raw,'{"tasks":["old"]}');
  await repository.saveChecked({tasks:['new']});assert.equal(raw,'{"tasks":["new"]}');
  const unreadable=new Repository({get:async()=>{throw Error('read');},put:async()=>{throw Error('must not write');}});
  await assert.rejects(unreadable.saveChecked({tasks:[]}),/无法读取/);
  console.log('PASS: legacy records remain readable and repository saves remain transactional');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
