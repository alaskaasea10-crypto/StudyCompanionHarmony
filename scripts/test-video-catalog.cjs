// Run with DevEco's Node and pass its typescript/lib/typescript.js as argv[2].
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/VideoCatalog.ets'), 'utf8');
const js = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const sandbox = { exports: {} };
vm.runInNewContext(js, sandbox);
const catalog = sandbox.exports.VideoCatalog;
const all = catalog.all();
assert.equal(new Set(all.map(v => v.id)).size, all.length);
assert.equal(new Set(all.map(v => v.url)).size, all.length, 'no repeated video links');
assert.equal(all.length, 23);
for (const module of catalog.modules()) {
  assert.ok(catalog.filter(module.id, '全部', '', '全部', [], []).length >= (module.id === 'matrix' ? 2 : 5));
  assert.ok(catalog.topics(module.id).length > 1);
}
for (const video of all) {
  assert.ok(catalog.allowedUrl(video.url), video.url);
  assert.ok(video.title && video.publisher && video.note);
  if (video.publishedAt) assert.ok(video.publishedAt <= '2026-09-08');
}
assert.equal(catalog.filter('career', '方向探索', '', '全部', [], []).length, 1);
assert.ok(catalog.filter('career', '全部', ' 简历 ', '全部', [], []).length >= 4);
assert.equal(catalog.filter('career', '全部', '', '收藏', ['career-course'], []).length, 1);
assert.equal(catalog.filter('career', '全部', '', '已看', [], ['career-course']).length, 1);
assert.equal(catalog.filter('career', '全部', '不存在的知识点', '全部', [], []).length, 0);
assert.equal(catalog.toggle([], 'unknown').length, 0);
assert.equal(catalog.toggle(catalog.toggle([], 'career-course'), 'career-course').length, 0);
const saved = catalog.decode('{"favoriteIds":["career-course","career-course","unknown"],"watchedIds":["contract-terms"]}');
assert.equal(saved.favoriteIds.length, 1);
assert.equal(saved.watchedIds[0], 'contract-terms');
assert.equal(catalog.decode('null').favoriteIds.length, 0);
assert.equal(catalog.decode('{"favoriteIds":"bad"}').favoriteIds.length, 0);
assert.throws(() => catalog.decode('{broken'));
for (const bad of ['http://www.bilibili.com/video/x', 'https://www.bilibili.com.evil.com/x',
  'https://www.bilibili.com@evil.com/x', 'javascript:alert(1)', 'file:///etc/passwd']) {
  assert.equal(catalog.allowedUrl(bad), false);
}
console.log(`PASS: ${all.length} resources; categories, filters, state round-trip and URL allowlist`);

// Exercise the actual Index task methods in an isolated harness, without changing device data.
const indexSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const taskMethods = indexSource.slice(indexSource.indexOf('  private async addVideoTask('), indexSource.indexOf('  private openCurrentVideo('));
const finishMethod = indexSource.slice(indexSource.indexOf('  private finishFocus()'), indexSource.indexOf('  private setTaskCompleted('));
assert.ok(taskMethods.includes('plannedVideoIds'));
assert.ok(finishMethod.includes('TaskOutcomeService.focused'));
const resultMethod = indexSource.slice(indexSource.indexOf('  private openTaskResult('), indexSource.indexOf('  private activeGoal('));
const resultBox = { exports: {} };
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,'entry/src/main/ets/services/TaskOutcomeService.ets'),'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, resultBox);
const harnessSource = `class TaskHarness {
  tasks = []; shouldFail = false; saves = 0;
  focusElapsedSeconds = 0; focusMinutes = 15; isRunning = false;
  focusSessionCredited = false; currentTaskIndex = 0; quizPending = false;
  async persistState() { if(this.shouldFail) throw Error('storage'); this.saves++; }
  persistSilently() {} clearTimerInterval() {}
  currentTask() { return this.tasks[0]; }
  setTaskCompleted(index, completed) { this.tasks[index].completed = completed; }
  ${taskMethods}
  ${finishMethod}
  ${resultMethod}
}
exports.TaskHarness = TaskHarness;`;
const harness = { exports: {}, VideoCatalog: catalog, TaskOutcomeService: resultBox.exports.TaskOutcomeService,
  QuizService: { questionFor: () => ({ id: 'test-quiz' }) } };
vm.runInNewContext(ts.transpileModule(harnessSource, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, harness);
(async () => {
  const task = new harness.exports.TaskHarness();
  const video = all[0];
  await task.addVideoTask(video);
  await task.addVideoTask(video);
  assert.equal(task.tasks.length, 1);
  assert.equal(task.saves, 1);
  assert.equal(task.tasks[0].minutes, 15);
  assert.equal(task.tasks[0].completed, false);
  assert.equal(task.plannedVideoIds()[0], video.id);
  task.finishFocus();
  assert.equal(task.tasks[0].completed, false, 'video timing is not result submission');
  assert.equal(task.tasks[0].outcome, 'focused');
  assert.equal(task.quizPending, false, 'video completion must not trigger an unrelated academic quiz');
  const failed = new harness.exports.TaskHarness();
  failed.shouldFail = true;
  await assert.rejects(failed.addVideoTask(video));
  assert.equal(failed.tasks.length, 0);
  const ordinary = new harness.exports.TaskHarness();
  ordinary.tasks = [{ id: 'normal', title: '矩阵乘法', subject: '线性代数', source: 'manual', completed: false }];
  ordinary.finishFocus();
  assert.equal(ordinary.quizPending, true, 'ordinary study quizzes must still work');
  console.log('PASS: video task creation, duplicate prevention, save failure rollback and quiz isolation');
})().catch(error => { console.error(error); process.exitCode = 1; });
