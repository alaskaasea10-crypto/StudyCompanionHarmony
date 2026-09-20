const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/QuestionBank.ets'), 'utf8');
const extended = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,'entry/src/main/ets/services/ExtendedBankQuestions.ets'),'utf8'),
  {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,extended);
const sandbox = { exports: {}, require: () => extended.exports };
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText, sandbox);
const bank = sandbox.exports.QuestionBank;
assert.equal(bank.all().length, 10);
assert.equal(new Set(bank.all().map(q => q.id)).size, 10);
for (const q of bank.all()) {
  assert.equal(q.options.length, 4);
  assert.equal(new Set(q.options).size, 4);
  assert.equal(q.hints.length, 4);
  assert.ok(q.explanation.length > 15);
  q.hints.forEach((hint, i) => { if (i !== q.answer) assert.ok(hint.length > 0); });
}
const multiply = (a,b) => {
  assert.equal(a[0].length,b.length);
  return a.map(row => b[0].map((_,j) => row.reduce((sum,v,k) => sum+v*b[k][j],0)));
};
const selected = id => { const q=bank.question(id); return q.options[q.answer]; };
const shape = (a,b) => a[1] === b[0] ? `${a[0]}×${b[1]}` : null;
assert.equal(selected('mm-d1'), shape([2,3],[3,4]));
assert.equal(selected('mm-d2'), `AB 为 ${shape([3,2],[2,1])}，BA 不存在`);
assert.equal(shape([2,1],[3,2]),null);
assert.equal(selected('mm-d3'), '2×3');
assert.equal(shape([4,2],[2,3]), '4×3');
assert.equal(Number(selected('mm-c1')),multiply([[1,2],[0,1]],[[2,0],[3,1]])[0][0]);
assert.equal(Number(selected('mm-c2')),multiply([[2,-1],[1,3]],[[1,4],[2,0]])[1][0]);
assert.equal(Number(selected('mm-c3').replace('−','-')),multiply([[1,-2,3]],[[4],[1],[-1]])[0][0]);
assert.deepEqual(JSON.parse(selected('mm-c4')),multiply([[1,2],[3,4]],[[0,1],[1,0]]));
const a=[[1,1],[0,1]], b=[[1,0],[1,1]], x=[[2],[3]];
assert.deepEqual(multiply(b,multiply(a,x)),multiply(multiply(b,a),x));
assert.notDeepEqual(multiply(a,multiply(b,x)),multiply(b,multiply(a,x)));
assert.equal(selected('mm-o1'),'BAx');
assert.notDeepEqual(multiply(a,b),multiply(b,a));
assert.equal(selected('mm-o2'),'AB ≠ BA');
assert.equal(selected('mm-o3'),'(AB)C = A(BC)');
// Independently check associativity on 20 rectangular numeric examples.
for(let seed=0;seed<20;seed++) {
  const matrix=(rows,cols)=>Array.from({length:rows},(_,i)=>Array.from({length:cols},(_,j)=>(seed+i*3+j)%7-3));
  const aa=matrix(2,3),bb=matrix(3,4),cc=matrix(4,1);
  assert.deepEqual(multiply(multiply(aa,bb),cc),multiply(aa,multiply(bb,cc)));
}
console.log('PASS: all 10 answers independently checked; dimensions, products, order and associativity');
let state=bank.empty();
assert.equal(bank.evidence(state)[0].status,'待诊断');
state=bank.start(state,100);
assert.equal(bank.start(state,101),state,'do not replace unfinished session');
assert.equal(bank.answer(state,-1),state);
assert.equal(bank.answer(state,4),state);
const firstIds=[...bank.current(state).questionIds];
state=bank.answer(state,bank.question(firstIds[0]).answer);
state=bank.decode(JSON.stringify(state));
assert.equal(bank.current(state).answers.length,1,'resume committed answer');
for(let i=1;i<3;i++) state=bank.answer(state,bank.question(firstIds[i]).answer);
assert.equal(bank.answer(state,0),state,'completed session locked');
assert.equal(bank.correctCount(bank.current(state)),3);
assert.ok(bank.evidence(state).every(e=>e.status==='正在巩固'),'one correct does not imply mastery');
state=bank.start(state,200);
assert.ok(bank.current(state).questionIds.every(id=>!firstIds.includes(id)));
for(const id of bank.current(state).questionIds) state=bank.answer(state,bank.question(id).answer);
assert.ok(bank.evidence(state).every(e=>e.status==='初步掌握'));
for(let round=2;round<7;round++) {
  state=bank.start(state,300+round);
  for(const id of bank.current(state).questionIds) state=bank.answer(state,bank.question(id).answer);
}
assert.equal(bank.evidence(state).reduce((sum,e)=>sum+e.total,0),10,'repeat questions cannot inflate evidence');
state=bank.start(state,999);
assert.ok(bank.repeated(state,bank.current(state).questionIds[0]));
const q=bank.question(bank.current(state).questionIds[0]);
state=bank.answer(state,(q.answer+1)%4);
assert.equal(bank.evidence(state)[0].status,'建议复习','new mistake downgrades evidence');
assert.equal(bank.evidence(state)[0].total,3);
for(const raw of ['null','{}','{"version":2,"sessions":[]}','{broken',
  '{"version":1,"sessions":[{"id":"x","startedAt":1,"questionIds":["bad","bad","bad"],"answers":[]}]}']) {
  assert.throws(()=>bank.decode(raw));
}
const corrupt=JSON.parse(JSON.stringify(state));
corrupt.sessions[0].answers[0]=5;
assert.throws(()=>bank.decode(JSON.stringify(corrupt)));
console.log('PASS: balanced selection, resume, locking, fresh retest, evidence dedup, regression and invalid records');

const index=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/Index.ets'),'utf8');
const method=index.slice(index.indexOf('  private async addBankReview('),index.indexOf('  private bottomTabIndex('));
const taskSandbox={exports:{},QuestionBank:bank};
vm.runInNewContext(ts.transpileModule(`class Harness {
  tasks=[]; fail=false;
  async persistState(){if(this.fail)throw Error('storage');}
  ${method}
} exports.Harness=Harness;`,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,taskSandbox);
(async()=>{
  const h=new taskSandbox.exports.Harness();
  h.tasks=[{id:'user-task',title:'保留原任务'}];
  await h.addBankReview('one','乘法条件'); await h.addBankReview('one','乘法条件');
  assert.equal(h.tasks.length,2);assert.equal(h.tasks[0].id,'user-task');
  assert.equal(h.tasks[1].minutes,15);assert.equal(h.tasks[1].source,'question-bank');
  h.fail=true;await assert.rejects(h.addBankReview('two','逐项计算'));assert.equal(h.tasks.length,2);
  console.log('PASS: review plan preserves existing tasks, deduplicates and rolls back on save failure');
})().catch(error=>{console.error(error);process.exitCode=1;});
