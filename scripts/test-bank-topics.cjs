const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]),root=path.resolve(__dirname,'..'),cache=new Map();
function load(name){
  if(cache.has(name))return cache.get(name);
  const box={exports:{},Error,require:spec=>load(path.basename(spec))};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText,box);cache.set(name,box.exports);return box.exports;
}
const {QuestionBank:bank}=load('QuestionBank');
const {BankLearningBridge:bridge}=load('BankLearningBridge');
const {PlanValidator:validator}=load('PlanValidator');
const {PlanCommitService:commit}=load('PlanCommitService');
const all=bank.topics().flatMap(t=>bank.all(t.id));
// Verify the shared result route, including plans named by skill alone.
const indexSource=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/Index.ets'),'utf8');
assert.ok(indexSource.includes('this.bankTopicId = TaskOutcomeService.topic(task)'));
const {TaskOutcomeService:outcome}=load('TaskOutcomeService');
for(const [title,expected] of [['秩的计算巩固','rank'],['矩阵秩复测','rank'],['可逆条件复习','rank'],
  ['矩阵乘法运算顺序','matrix'],['链式法则复测','derivative']]){
  assert.equal(outcome.topic({title,subject:'线性代数'}),expected);
}
assert.equal(all.length,30);assert.equal(new Set(all.map(q=>q.id)).size,30);
for(const topic of bank.topics()){
  assert.equal(bank.all(topic.id).length,10);
  for(const skill of topic.skills)assert.ok(bank.all(topic.id).filter(q=>q.skill===skill).length>=3);
}
for(const q of all){assert.equal(q.options.length,4);assert.equal(new Set(q.options).size,4);assert.equal(q.hints.length,4);
  assert.ok(q.explanation.length>15);q.hints.forEach((hint,i)=>{if(i!==q.answer)assert.ok(hint.length>0);});}
const chosen=id=>{const q=bank.question(id);return q.options[q.answer];};
const rank=input=>{
  const a=input.map(row=>row.slice());let row=0;
  for(let c=0;c<a[0].length&&row<a.length;c++){
    let pivot=row;while(pivot<a.length&&Math.abs(a[pivot][c])<1e-9)pivot++;
    if(pivot===a.length)continue;
    [a[row],a[pivot]]=[a[pivot],a[row]];const d=a[row][c];
    for(let j=c;j<a[0].length;j++)a[row][j]/=d;
    for(let i=0;i<a.length;i++)if(i!==row){const factor=a[i][c];for(let j=c;j<a[0].length;j++)a[i][j]-=factor*a[row][j];}
    row++;
  }return row;
};
const det=a=>a[0][0]*a[1][1]-a[0][1]*a[1][0];
const mul=(a,b)=>a.map(r=>b[0].map((_,j)=>r.reduce((s,v,k)=>s+v*b[k][j],0)));
assert.equal(chosen('rk-d1'),'rank(A)=n');
for(const a of [[[1,2],[2,4]],[[1,2],[3,4]],[[0,0],[0,0]],[[1,1],[1,1]],[[1,0],[0,1]]])assert.equal(rank(a)===2,det(a)!==0);
assert.equal(det([[1,2],[2,4]]),0);assert.equal(chosen('rk-d2'),'不可逆，因为 det(A)=0');
assert.equal(chosen('rk-d3'),'k≠6');for(let k=-10;k<10;k++)assert.equal(det([[1,2],[3,k]])!==0,k!==6);
for(const [id,a] of [['rk-c1',[[1,2,3],[2,4,6]]],['rk-c2',[[1,0,2],[0,1,3],[0,0,0]]],
 ['rk-c3',Array.from({length:3},()=>[0,0,0,0])],['rk-c4',[[1,2],[2,5]]]])assert.equal(Number(chosen(id)),rank(a));
assert.equal(chosen('rk-o1'),'只有零解');assert.equal(chosen('rk-o2'),String(3-2));
const inverse=JSON.parse(chosen('rk-o3').replaceAll('−','-'));
assert.deepEqual(mul([[1,2],[0,1]],inverse),[[1,0],[0,1]]);assert.deepEqual(mul(inverse,[[1,2],[0,1]]),[[1,0],[0,1]]);
const derivative=(f,x)=>(f(x+1e-5)-f(x-1e-5))/2e-5;
const near=(a,b)=>Math.abs(a-b)<1e-5;
for(const [id,f,x] of [['dv-d1',x=>x**3,2],['dv-d2',x=>5*x*x-3*x+7,1],['dv-c1',x=>(2*x+1)**3,0],
 ['dv-c3',x=>Math.exp(3*x),0],['dv-c4',x=>Math.log(1+x*x),1],['dv-o1',x=>x*Math.exp(x),0],['dv-o3',x=>(x*x+1)**2,1]]){
  assert.ok(near(Number(chosen(id)),derivative(f,x)),id);
  assert.equal(bank.question(id).options.filter(v=>near(Number(v),derivative(f,x))).length,1,id+' unique answer');
}
assert.equal(chosen('dv-d3'),'1/x');for(const x of [.4,1,2,3])assert.ok(near(1/x,derivative(Math.log,x)));
assert.equal(chosen('dv-c2'),'2x·cos(x²)');for(const x of [-1,.3,1,2])assert.ok(near(2*x*Math.cos(x*x),derivative(y=>Math.sin(y*y),x)));
assert.equal(chosen('dv-o2'),'y=2x−1');assert.ok(near(derivative(x=>x*x,1),2));assert.equal(2*1-1,1);
console.log('PASS: 30 question structure; 20 new answers checked with rank elimination, inverse products and numerical derivatives');

let state=bank.start(bank.empty(),1);state=bank.answer(state,1);
const legacy=JSON.stringify(state);state=bank.decode(legacy);assert.equal(JSON.stringify(state),legacy,'legacy records unchanged');
state=bank.start(state,2,'rank');state=bank.answer(state,0,'rank');state=bank.start(state,3,'derivative');
assert.equal(bank.current(state).answers.length,1);assert.equal(bank.current(state,'rank').answers.length,1);
state=bank.decode(JSON.stringify(state));assert.equal(bridge.summarize(state).length,0);
for(const topic of bank.topics()){
  while(bank.current(state,topic.id).answers.length<3){const s=bank.current(state,topic.id),q=bank.question(s.questionIds[s.answers.length]);state=bank.answer(state,(q.answer+1)%4,topic.id);}
}
assert.equal(bridge.summarize(state).length,9);assert.equal(new Set(bridge.summarize(state).map(e=>e.knowledgePointId)).size,9);
for(const topic of bank.topics()){
  const original=[...bank.current(state,topic.id).questionIds];state=bank.start(state,10,topic.id);
  assert.ok(bank.current(state,topic.id).questionIds.every(id=>!original.includes(id)));
  for(let round=0;round<5;round++){
    while(bank.current(state,topic.id).answers.length<3){const s=bank.current(state,topic.id),q=bank.question(s.questionIds[s.answers.length]);state=bank.answer(state,q.answer,topic.id);}
    if(round<4)state=bank.start(state,20+round,topic.id);
  }
  assert.equal(bank.evidence(state,topic.id).reduce((s,e)=>s+e.total,0),10);
}
assert.equal(bank.decode(JSON.stringify(state)).sessions.length,state.sessions.length);
const corrupt=JSON.parse(legacy);corrupt.sessions[0].questionIds[1]='rk-c1';assert.throws(()=>bank.decode(JSON.stringify(corrupt)));
assert.throws(()=>bank.question('unknown'));assert.throws(()=>bank.start(bank.empty(),1,'unknown'));
let wrong=bank.empty();for(const t of bank.topics()){wrong=bank.start(wrong,1,t.id);for(let i=0;i<3;i++){const q=bank.question(bank.current(wrong,t.id).questionIds[i]);wrong=bank.answer(wrong,(q.answer+1)%4,t.id);}}
for(const topic of bank.topics()){
  const request={requestText:`请安排${topic.title}补学`,profile:{subject:'英语四六级'},context:{bankEvidence:bridge.summarize(wrong),availableMinutesToday:20}};
  const relevant=bridge.relevant(request);assert.equal(relevant.length,3);assert.ok(relevant.every(e=>e.topicId===topic.id));
  const raw={summary:'测试',detectedSubject:topic.subject,tasks:[],recommendationReasons:[],usage:{},source:'test',model:'test'};
  const p=validator.validate(bridge.prioritize(raw,request),20);
  assert.ok(p.tasks[0].title.includes(topic.title));assert.ok(p.tasks.some(t=>t.type==='quiz'));assert.ok(p.totalMinutes<=20);
  assert.equal(commit.appendBankPlan([],p,20).tasks[0].source,'question-bank');
}
console.log('PASS: legacy compatibility, interleaved resume, topic isolation, retest dedup, 9 evidence IDs and topic-specific planning');
