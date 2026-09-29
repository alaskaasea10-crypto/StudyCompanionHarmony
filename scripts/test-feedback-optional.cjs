const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const now = new Date('2026-09-27T14:00:00+08:00').getTime();
class FeedbackClock extends Date { static now() { return now; } }
const cache = new Map();
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (cache.has(name)) return cache.get(name);
  const filename = name === 'SubjectDisplayName' ? 'utils/SubjectDisplayName.ets' : name === 'StudyModels' ? 'models/StudyModels.ets' :
    name === 'QuestionBankModels' ? 'models/QuestionBankModels.ets' : `services/${name}.ets`;
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets', filename), 'utf8');
  const box = { exports: {}, Date, console, require: input => load(path.basename(input)) };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const outcomes = load('TaskOutcomeService').TaskOutcomeService;
const center = load('StudyDataCenter').StudyDataCenter;
const decisions = load('AgentDecisionService').AgentDecisionService;
const indexSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const feedbackMethods = indexSource.slice(indexSource.indexOf('  private recordTaskResult('),
  indexSource.indexOf('  private openTaskResult('));
const harnessBox = { exports: {}, Date: FeedbackClock, console, TaskOutcomeService: outcomes };
vm.runInNewContext(ts.transpileModule(`class FeedbackHarness {
  tasks = []; currentTaskIndex = 0; resultChecked = true; resultExperience = 'normal'; resultNote = '';
  todayStudyOverride = { date: '2026-09-27' }; preferredTaskId = ''; actionDeferrals = [];
  actionMessage = 'pending'; currentTab = 3; persistCount = 0;
  currentTask() { return this.tasks[this.currentTaskIndex]; }
  advanceGoalMilestone() {}
  persistSilently() { this.persistCount++; }
  ${feedbackMethods}
} exports.FeedbackHarness = FeedbackHarness;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, harnessBox);
const FeedbackHarness = harnessBox.exports.FeedbackHarness;

const pendingTask = (id) => ({ id, title: '复习矩阵', subject: 'LinearAlgebra', minutes: 30,
  completed: false, source: 'manual', outcome: 'focused', focusedAt: 100 });

function submit(note, experience = 'normal') {
  const harness = new FeedbackHarness();
  harness.tasks = [pendingTask(`task-${note.length}-${experience}`)];
  harness.resultNote = note;
  harness.resultExperience = experience;
  harness.submitSelfResult();
  return harness;
}

// A-E: empty, one, four and five-plus characters all submit; whitespace is stored as the real empty value.
for (const [note, expected] of [['', ''], ['会', '会'], ['基本会了', '基本会了'],
  ['我理解了矩阵', '我理解了矩阵'], ['   ', '']]) {
  const harness = submit(note);
  assert.equal(harness.tasks[0].completed, true);
  assert.equal(harness.tasks[0].outcome, 'submitted');
  assert.equal(harness.tasks[0].resultNote, expected);
  assert.equal(harness.currentTab, 0);
  assert.equal(harness.persistCount, 1);
  assert.equal(harness.resultNote, '');
}

// Existing required feedback conditions remain unchanged.
const unchecked = new FeedbackHarness();
unchecked.tasks = [pendingTask('unchecked')]; unchecked.resultChecked = false; unchecked.submitSelfResult();
assert.equal(unchecked.tasks[0].completed, false);
const noExperience = new FeedbackHarness();
noExperience.tasks = [pendingTask('no-experience')]; noExperience.resultExperience = ''; noExperience.submitSelfResult();
assert.equal(noExperience.tasks[0].completed, false);

// F: real text survives the same JSON persistence/normalization path used during restore.
const withText = submit('会了');
const restored = center.normalizeTasks(JSON.parse(JSON.stringify(withText.tasks)));
assert.equal(restored[0].resultNote, '会了');

// G: an empty note still completes the original task and allows the next real task to be selected.
const emptyCompleted = submit('').tasks[0];
const nextTask = { id: 'next-real', title: '整理矩阵笔记', subject: 'LinearAlgebra', minutes: 30,
  completed: false, source: 'manual' };
const snapshot = { profileCompleted: true, profileSubject: 'LinearAlgebra', profileDailyMinutes: 60,
  profileExamDate: '', profileExamDateConfirmed: false, energyState: '一般', studyDayKey: '2026-09-27',
  todayMinutes: 0, tasks: [emptyCompleted, nextTask], currentTaskIndex: 1, scheduleItems: [],
  setupScheduleReady: false, academicGoals: [], focusRecords: [], quizAttempts: [], knowledgeMastery: [],
  remainingSeconds: 0, focusElapsedSeconds: 0, focusSegmentStartedAt: 0, focusSessionCredited: true,
  isRunning: false, todayStudyOverride: { date: '2026-09-27', availableMinutes: 60 } };
const replanned = decisions.decide(snapshot, now);
assert.equal(replanned.dailyPlan.some(item => item.taskId === emptyCompleted.id), false);
assert.equal(replanned.recommendedAction.taskId, nextTask.id);

// H: studyExperience remains independent of optional note and still shortens the next same-subject action.
const strugglingCompleted = submit('', 'struggling').tasks[0];
const strugglingDecision = decisions.decide({ ...snapshot, tasks: [strugglingCompleted, nextTask] }, now);
assert.equal(strugglingCompleted.studyExperience, 'struggling');
assert.equal(strugglingDecision.recommendedAction.taskId, nextTask.id);
assert.equal(strugglingDecision.recommendedAction.minutes, 18);

const focusSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/FocusPage.ets'), 'utf8');
assert.ok(focusSource.includes("Text('这次学到了什么？')"));
assert.equal(focusSource.includes('这次学到了什么？（可选）'), false);
assert.ok(focusSource.includes("Button('跳过')"));
assert.match(focusSource, /private skipResultNote\(\): void \{\s*this\.onResultNote\(''\);\s*\}/);
assert.ok(focusSource.includes('完成反馈，继续下一步'));
assert.ok(focusSource.includes('.enabled(this.resultChecked && this.resultExperience.length > 0)'));
assert.equal(focusSource.includes('this.resultNote.trim().length >='), false);
assert.equal(feedbackMethods.includes('this.resultNote.trim().length <'), false);

console.log('PASS optional feedback: empty/short notes, trim, persistence, replan and studyExperience');
