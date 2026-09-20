const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]),root=path.resolve(__dirname,'..'),cache=new Map();
function load(name){
  if(cache.has(name))return cache.get(name);
  const box={exports:{},Error,require:spec=>load(path.basename(spec))};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText,box);cache.set(name,box.exports);return box.exports;
}
const {QuestionBank:b}=load('QuestionBank'),{WrongQuestionBook:w}=load('WrongQuestionBook');
for(const t of b.topics()){
  let s=b.start(b.empty(),1,t.id);
  const id=b.current(s,t.id).questionIds[0],q=b.question(id);
  s=b.answer(s,(q.answer+1)%4,t.id);
  assert.equal(w.entries(s,t.id).length,1); // partial submitted answers are durable too
  const before=JSON.stringify(s);
  assert.equal(w.correction(s,t.id,id,2),s);
  assert.equal(JSON.stringify(s),before);
  while(b.current(s,t.id).answers.length<3){const c=b.current(s,t.id);s=b.answer(s,b.question(c.questionIds[c.answers.length]).answer,t.id);}
  s=b.decode(JSON.stringify(s)); // legacy schema unchanged
  const original=JSON.stringify(s);
  let corrected=w.correction(s,t.id,id,3);
  assert.equal(JSON.stringify(s),original);
  assert.equal(b.current(corrected,t.id).questionIds[0],id);
  for(let i=0;i<3;i++)corrected=b.answer(corrected,b.question(b.current(corrected,t.id).questionIds[i]).answer,t.id);
  let e=w.entries(corrected,t.id)[0];assert.equal(e.corrected,true);assert.equal(e.transferCorrect,false);
  let next=b.start(corrected,4,t.id);
  for(let i=0;i<3;i++)next=b.answer(next,b.question(b.current(next,t.id).questionIds[i]).answer,t.id);
  e=w.entries(next,t.id)[0];assert.equal(e.transferCorrect,true);assert.equal(e.wrongCount,1);
  assert.equal(w.entries(next,t.id).length,1); // history retained after both checks
  let again=w.correction(next,t.id,id,5);
  again=b.answer(again,(q.answer+1)%4,t.id);
  e=w.entries(again,t.id)[0];assert.equal(e.corrected,false);assert.equal(e.transferCorrect,false);assert.equal(e.wrongCount,2);
  for(const other of b.topics().filter(x=>x.id!==t.id))assert.equal(w.entries(again,other.id).length,0);
}
assert.equal(w.entries(b.empty(),'matrix').length,0);
console.log('Wrong book: partial/legacy/history/correction/new-question/reopened/topic isolation PASS');
