const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..', 'entry/src/main/ets');
const cache = new Map();
let modelResponse;
let modelCalls = 0;
function load(name) {
  if (name === 'BuildProfile') return { DEBUG: false };
  if (name === 'AgentClient') {
    return { AgentClient: { generateTodayPlan: async () => { modelCalls++; return modelResponse; } } };
  }
  if (cache.has(name)) return cache.get(name);
  const folder = name === 'SubjectDisplayName' ? 'utils' : name.endsWith('Models') ? 'models' : 'services';
  const source = fs.readFileSync(path.join(root, folder, `${name}.ets`), 'utf8');
  const box = { exports: {}, Date, console, require: input => load(path.basename(input)) };
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  cache.set(name, box.exports);
  return box.exports;
}

const { AgentDecisionService } = load('AgentDecisionService');
const { LearningActionService } = load('LearningActionService');
const { PlanValidator } = load('PlanValidator');
const { LearningPlanningOrchestrator } = load('LearningPlanningOrchestrator');
const now = new Date('2026-09-20T10:00:00+08:00').getTime();
const tasks = [
  { id: 'math-1', title: '高数复习', subject: '高等数学', minutes: 25, completed: false, goalId: 'math' },
  { id: 'english-1', title: '英语作业', subject: '大学英语', minutes: 20, completed: false, goalId: 'english' },
  { id: 'linear-1', title: '线代整理', subject: '线性代数', minutes: 15, completed: false, goalId: 'linear' }
];
const academicGoals = [
  { id: 'math', title: '高数考试', subject: '高等数学', deadline: '2026-09-21', completed: false },
  { id: 'english', title: '英语作业', subject: '大学英语', deadline: '2026-09-24', completed: false },
  { id: 'linear', title: '线代复习', subject: '线性代数', deadline: '2026-09-28', completed: false }
];
const snapshot = { profileCompleted: true, profileSubject: '高等数学', profileDailyMinutes: 60,
  profileExamDateConfirmed: false, energyState: '一般', studyDayKey: '2026-09-20', todayMinutes: 0,
  tasks, academicGoals, todayStudyOverride: { date: '2026-09-20', availableMinutes: 60 },
  currentTaskIndex: 0, scheduleItems: [], setupScheduleReady: false, focusRecords: [], quizAttempts: [],
  knowledgeMastery: [], remainingSeconds: 0, focusElapsedSeconds: 0, isRunning: false };
const decision = AgentDecisionService.decide(snapshot, now);
const ids = Array.from(decision.dailyPlan, item => item.taskId);
assert.deepEqual(ids, ['math-1', 'english-1', 'linear-1']);
assert.equal(decision.recommendedAction.taskId, ids[0]);
assert.equal(decision.dailyPlan.reduce((sum, item) => sum + item.suggestedMinutes, 0), 60);
const originals = JSON.stringify(tasks);
const context = { date: '2026-09-20', academicGoals, unfinishedTasks: tasks,
  todayStudyOverride: snapshot.todayStudyOverride, availableMinutesToday: 60,
  localDailyPlanTaskIds: ids, eligibleTaskIds: LearningActionService.candidates(snapshot, now)
    .map(item => item.task.id), protectedStage: 'execute' };
const request = { requestText: '帮我安排今天', profile: { subject: '高等数学', dailyMinutes: 60 }, context };
function plan(list) {
  return { summary: '今天按真实任务推进', detectedSubject: '高等数学', recommendationReasons: [],
    tasks: list.map((task, index) => ({ taskId: task.id, title: task.title, subject: task.subject,
      minutes: task.minutes, type: 'review', priority: index + 1, reason: '已有任务' })),
    totalMinutes: list.reduce((sum, task) => sum + task.minutes, 0),
    source: 'openpangu', model: 'test', usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 } };
}

(async () => {
  modelResponse = plan(tasks);
  const accepted = await LearningPlanningOrchestrator.decide(request, []);
  assert.equal(accepted.plan.source, 'openpangu');
  assert.deepEqual(Array.from(accepted.plan.tasks, item => item.taskId), ids);
  assert.equal(accepted.plan.totalMinutes, 60);
  assert.equal(JSON.stringify(tasks), originals, 'model advice must not create or edit StudyTask');
  modelResponse = plan([{ ...tasks[0], id: 'invented-task' }]);
  const fallback = await LearningPlanningOrchestrator.decide(request, []);
  assert.equal(fallback.plan.source, 'local-fallback');
  assert.deepEqual(Array.from(fallback.plan.tasks, item => item.taskId), ids);
  const completed = { ...snapshot, tasks: [{ ...tasks[0], completed: true }, tasks[1], tasks[2]] };
  const next = AgentDecisionService.decide(completed, now);
  assert.equal(next.recommendedAction.taskId, 'english-1');
  assert.equal(next.dailyPlan.some(item => item.taskId === 'math-1'), false);
  assert.throws(() => PlanValidator.validateExisting(plan(tasks), {
    ...request, context: { ...context, unfinishedTasks: completed.tasks.filter(item => !item.completed) }
  }), /不存在、已完成/);
  const protectedRequest = { ...request, context: { ...context, protectedStage: 'verify',
    protectedTaskId: 'math-1', localDailyPlanTaskIds: ['math-1'] } };
  const before = modelCalls;
  const protectedPlan = await LearningPlanningOrchestrator.decide(protectedRequest, []);
  assert.equal(modelCalls, before, 'pending feedback bypasses model');
  assert.equal(protectedPlan.plan.tasks[0].taskId, 'math-1');
  assert.equal(protectedPlan.plan.tasks[0].minutes, 0);
  const unknown = { ...request, context: { ...context, availableMinutesToday: undefined,
    localDailyPlanTaskIds: ids } };
  modelResponse = plan(tasks);
  const unknownFallback = await LearningPlanningOrchestrator.decide(unknown, []);
  assert.equal(unknownFallback.plan.source, 'local-fallback');
  assert.equal(unknownFallback.plan.tasks.length, 1);
  assert.equal(JSON.stringify(tasks), originals);
  console.log('agent plan guard: passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
