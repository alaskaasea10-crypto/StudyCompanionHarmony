const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require(process.argv[2]),root=path.resolve(__dirname,'..'),cache=new Map();
function load(name){if(cache.has(name))return cache.get(name);const box={exports:{},require:s=>load(path.basename(s))};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,box);cache.set(name,box.exports);return box.exports;}
const {DailyActionService:d}=load('DailyActionService');
const tasks=[{title:'完成矩阵练习',subject:'线性代数',minutes:25,completed:false,source:'manual'}];
assert.equal(d.decide('线性代数',tasks,[]).stage,'diagnose');
const weak={topicId:'matrix',knowledgePointId:'m.c',subject:'线性代数',knowledgePoint:'矩阵乘法 · 逐项计算',status:'建议复习',distinctQuestions:2,latestCorrect:1,sessionStartedAt:1};
assert.equal(d.decide('线性代数',tasks,[weak]).stage,'remediate');
assert.equal(d.decide('线性代数',tasks,[{...weak,status:'正在巩固',latestCorrect:1,distinctQuestions:1}]).stage,'retest');
assert.equal(d.decide('线性代数',tasks,[{...weak,status:'初步掌握',latestCorrect:2}]).stage,'execute');
assert.equal(d.decide('操作系统',tasks.map(t=>({...t,subject:'操作系统'})),[]).stage,'execute');
assert.equal(d.decide('线性代数',tasks.map(t=>({...t,completed:true})),[{...weak,status:'初步掌握',latestCorrect:2}]).stage,'done');
console.log('PASS: daily action chain diagnose -> remediate/retest -> execute -> done; unsupported subjects are not misdiagnosed');
