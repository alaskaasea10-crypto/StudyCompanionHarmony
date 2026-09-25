const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '../entry/src/main/ets');
const cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  const filename = name === 'SubjectDisplayName' ? 'utils/SubjectDisplayName.ets' :
    'services/LearningResourceSearchService.ets';
  const source = fs.readFileSync(path.join(root, filename), 'utf8');
  const box = { exports: {}, encodeURIComponent, require: input => load(path.basename(input)) };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const { LearningResourceSearchService: resources } = load('LearningResourceSearchService');
const englishInput = Object.freeze({ subject: 'CollegeEnglish', taskTitle: '完成英语阅读作业', resourceType: 'video' });
const english = resources.searchLearningResources(englishInput);
assert.ok(english);
assert.ok(english.displayQuery.startsWith('大学英语 '));
assert.ok(!english.displayQuery.includes('CollegeEnglish'));
assert.ok(english.externalUri.startsWith('https://search.bilibili.com/all?keyword='));
assert.ok(english.externalUri.includes(encodeURIComponent('大学英语')));
assert.equal(englishInput.taskTitle, '完成英语阅读作业');

const linearVideo = resources.searchLearningResources({
  subject: 'LinearAlgebra', taskTitle: '复习矩阵乘法与逆矩阵', resourceType: 'video'
});
const linearExercise = resources.searchLearningResources({
  subject: 'LinearAlgebra', taskTitle: '复习矩阵乘法与逆矩阵', resourceType: 'exercise'
});
assert.ok(linearVideo.displayQuery.includes('线性代数'));
assert.ok(linearVideo.displayQuery.includes('矩阵乘法与逆矩阵'));
assert.ok(linearVideo.displayQuery.includes('讲解 教程'));
assert.ok(linearExercise.displayQuery.includes('例题 解题'));
assert.notEqual(linearVideo.displayQuery, linearExercise.displayQuery);
assert.notEqual(linearVideo.externalUri, linearExercise.externalUri);
assert.equal(decodeURIComponent(linearExercise.externalUri.split('keyword=')[1]), linearExercise.displayQuery);

assert.equal(resources.searchLearningResources({ subject: '', taskTitle: '链式法则', resourceType: 'video' }), undefined);
assert.equal(resources.searchLearningResources({ subject: 'AdvancedMath', taskTitle: '', resourceType: 'video' }), undefined);
assert.equal(resources.searchLearningResources({ subject: 'AdvancedMath', taskTitle: '学习', resourceType: 'video' }), undefined);
assert.equal(Object.prototype.hasOwnProperty.call(linearVideo, 'taskId'), false);
console.log('PASS learning resource search: real task intent, Chinese subject, type distinction, URL encoding, empty guard');
