const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const filename = path.resolve(__dirname, '../entry/src/main/ets/services/StudyDecisionDebug.ets');
const source = fs.readFileSync(filename, 'utf8');

function load(debugEnabled) {
  const messages = [];
  const box = {
    exports: {},
    console: { debug: value => messages.push(value) },
    require: name => name === 'BuildProfile' ? { DEBUG: debugEnabled } : {}
  };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  return { StudyDecisionDebug: box.exports.StudyDecisionDebug, messages };
}

const action = { taskId: 'private-task-id', subject: '大学英语', headline: '真实任务标题',
  minutes: 25, stage: 'execute' };
const plan = [{ order: 1, taskId: 'private-task-id', subject: '大学英语',
  title: '真实任务标题', suggestedMinutes: 25 }];

const release = load(false);
release.StudyDecisionDebug.decision(action, plan);
release.StudyDecisionDebug.event('focus-started', action.taskId, action.subject, action.headline, 'minutes=25');
assert.equal(release.messages.length, 0, 'release must not log task ids, titles, subjects or decision details');

const debug = load(true);
debug.StudyDecisionDebug.decision(action, plan);
debug.StudyDecisionDebug.event('focus-started', action.taskId, action.subject, action.headline, 'minutes=25');
assert.equal(debug.messages.length, 2, 'debug builds keep the existing structured diagnostics');
assert.ok(debug.messages.every(message => message.startsWith('[StudyDecisionDebug]')));

assert.ok(source.includes("import { DEBUG } from 'BuildProfile';"));
assert.ok(source.includes('if (!DEBUG) { return; }'));
console.log('PASS StudyDecisionDebug: release emits no learning details; debug diagnostics remain available');
