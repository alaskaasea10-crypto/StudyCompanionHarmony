const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const cache = new Map();
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (cache.has(name)) return cache.get(name);
  const filename = name === 'StudyModels' ? 'models/StudyModels.ets' :
    name === 'QuestionBankModels' ? 'models/QuestionBankModels.ets' :
    name === 'SubjectDisplayName' ? 'utils/SubjectDisplayName.ets' : `services/${name}.ets`;
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets', filename), 'utf8');
  const box = { exports: {}, Date, console, require: input => load(path.basename(input)) };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const now = new Date('2026-09-25T14:00:00+08:00').getTime();
const { TaskOutcomeService: outcomes } = load('TaskOutcomeService');
const { StudyDataCenter: center } = load('StudyDataCenter');
const { AgentDecisionService: decisions } = load('AgentDecisionService');
const completed = { id: 'english-done', title: '完成英语阅读', subject: 'CollegeEnglish', minutes: 30,
  completed: false, source: 'manual', focusedAt: now - 1800000, outcome: 'focused' };
const nextEnglish = { id: 'english-next', title: '整理英语写作提纲', subject: 'CollegeEnglish', minutes: 30,
  completed: false, source: 'manual' };
const linear = { id: 'linear-next', title: '整理矩阵章节', subject: 'LinearAlgebra', minutes: 20,
  completed: false, source: 'manual' };
const base = {
  profileCompleted: true, profileSubject: 'CollegeEnglish', profileDailyMinutes: 60,
  profileExamDate: '', profileExamDateConfirmed: false, energyState: '一般', studyDayKey: '2026-09-25',
  todayMinutes: 0, currentTaskIndex: 1, scheduleItems: [], setupScheduleReady: false,
  academicGoals: [], focusRecords: [], quizAttempts: [], knowledgeMastery: [], remainingSeconds: 0,
  focusElapsedSeconds: 0, focusSegmentStartedAt: 0, focusSessionCredited: true, isRunning: false,
  todayStudyOverride: { date: '2026-09-25', availableMinutes: 60 }
};

const struggling = outcomes.submit(completed, true, '阅读速度有点跟不上', now - 1000, 'struggling');
assert.equal(struggling.completed, true);
assert.equal(struggling.studyExperience, 'struggling');
assert.equal(center.normalizeTasks([struggling])[0].studyExperience, 'struggling');
const strugglingSnapshot = { ...base, tasks: [struggling, nextEnglish, linear] };
const strugglingDecision = decisions.decide(strugglingSnapshot, now);
assert.equal(strugglingDecision.recommendedAction.taskId, nextEnglish.id);
assert.equal(strugglingDecision.recommendedAction.minutes, 18);
assert.equal(strugglingDecision.reasonChain.some(item => item.data.includes('有点吃力') &&
  item.recommendation.includes('18分钟')), true);
assert.equal(strugglingDecision.dailyPlan[0].taskId, nextEnglish.id);
assert.equal(strugglingDecision.dailyPlan.some(item => item.taskId === completed.id), false);

const smooth = outcomes.submit(completed, true, '这次理解得很顺利', now - 1000, 'smooth');
const smoothDecision = decisions.decide({ ...base, tasks: [smooth, nextEnglish, linear] }, now);
assert.equal(smoothDecision.recommendedAction.taskId, nextEnglish.id);
assert.equal(smoothDecision.recommendedAction.minutes, 30);
assert.equal(smoothDecision.reasonChain.some(item => item.data.includes('有点吃力')), false);

const noExperience = outcomes.submit(completed, true, '保留旧版本反馈', now - 1000);
const unchangedDecision = decisions.decide({ ...base, tasks: [noExperience, nextEnglish, linear] }, now);
assert.equal(unchangedDecision.recommendedAction.minutes, 30);

const skippedDecision = decisions.decide({ ...strugglingSnapshot,
  todayStudyOverride: { date: '2026-09-25', availableMinutes: 60, skippedTaskIds: [nextEnglish.id] } }, now);
assert.equal(skippedDecision.dailyPlan.some(item => item.taskId === nextEnglish.id), false);
assert.equal(skippedDecision.recommendedAction.taskId, linear.id);

const ongoingDecision = decisions.decide({ ...strugglingSnapshot, currentTaskIndex: 1, isRunning: true,
  focusSegmentStartedAt: now - 1000, remainingSeconds: 1200 }, now);
assert.equal(ongoingDecision.recommendedAction.stage, 'resume');
assert.equal(ongoingDecision.recommendedAction.taskId, nextEnglish.id);
assert.equal(ongoingDecision.recommendedAction.minutes, 20);

const pendingEnglish = { ...nextEnglish, outcome: 'focused', focusedAt: now - 500 };
const pendingDecision = decisions.decide({ ...strugglingSnapshot,
  tasks: [struggling, pendingEnglish, linear] }, now);
assert.equal(pendingDecision.recommendedAction.stage, 'verify');
assert.equal(pendingDecision.recommendedAction.taskId, nextEnglish.id);

const restored = center.normalizeTasks(JSON.parse(JSON.stringify(strugglingSnapshot.tasks)));
assert.equal(decisions.decide({ ...base, tasks: restored }, now).recommendedAction.minutes, 18);
assert.deepEqual(Array.from(strugglingSnapshot.tasks, item => item.id),
  [completed.id, nextEnglish.id, linear.id]);

const { formatSubjectName } = load('SubjectDisplayName');
assert.equal(formatSubjectName('CollegeEnglish'), '大学英语');
const liveViewSource = fs.readFileSync(path.join(root,
  'entry/src/main/ets/services/StudyLiveViewService.ets'), 'utf8');
assert.ok(liveViewSource.includes("import { formatSubjectName } from '../utils/SubjectDisplayName'"));
assert.ok(liveViewSource.includes('formatSubjectName(subject)'));

console.log('PASS study experience: persisted evidence, eased next action, state guards, Chinese Live View subject');
