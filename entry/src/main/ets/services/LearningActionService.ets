import { StudyStateSnapshot, StudyTask, ScheduleItem } from '../models/StudyModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { DailyAction } from './DailyActionService';
import { GoalPlanningService } from './GoalPlanningService';
import { StudyDataCenter } from './StudyDataCenter';
import { TaskOutcomeService } from './TaskOutcomeService';

// 首页、学习入口和桌面卡片只从这里获得下一步，不各自猜测。
export class LearningActionService {
  static budget(snapshot: StudyStateSnapshot, now: number = Date.now()): number {
    const day: string = new Date(now + 8 * 3600000).toISOString().substring(0, 10);
    const metrics = StudyDataCenter.calculateMetrics(snapshot.tasks ?? [], snapshot.focusRecords ?? [],
      snapshot.quizAttempts ?? [], day, snapshot.studyDayKey === day ? snapshot.todayMinutes ?? 0 : 0);
    const daily: number = Math.min(240, Math.max(15, snapshot.profileDailyMinutes ?? 60));
    const activeSeconds: number = snapshot.isRunning && snapshot.focusSegmentStartedAt > 0 ?
      Math.max(0, Math.floor((now - snapshot.focusSegmentStartedAt) / 1000)) : 0;
    const uncredited: number = snapshot.focusSessionCredited ? 0 :
      Math.floor(Math.min((snapshot.focusMinutes ?? 25) * 60, (snapshot.focusElapsedSeconds ?? 0) + activeSeconds) / 60);
    const remaining: number = Math.max(0, daily - metrics.todayFocusMinutes - uncredited);
    return snapshot.energyState === '有点累' ? Math.min(remaining, Math.max(15, Math.round(daily * 0.6))) : remaining;
  }

  static freeMinutes(snapshot: StudyStateSnapshot, now: number = Date.now()): number {
    if (!snapshot.setupScheduleReady) { return 240; }
    const date: Date = new Date(now + 8 * 3600000);
    const minute: number = date.getUTCHours() * 60 + date.getUTCMinutes();
    let free: number = 240;
    (snapshot.scheduleItems ?? []).filter((item: ScheduleItem) => item.weekday === (date.getUTCDay() || 7))
      .forEach((item: ScheduleItem) => {
        const start: number = LearningActionService.clock(item.startTime);
        const end: number = LearningActionService.clock(item.endTime);
        if (start < 0 || end <= start) { return; }
        if (minute >= start && minute < end) { free = 0; }
        else if (start > minute) { free = Math.min(free, Math.max(0, start - minute - 5)); }
      });
    return free;
  }

  private static clock(value: string): number {
    if (!/^\d{1,2}:\d{2}$/.test(value)) { return -1; }
    const parts: string[] = value.split(':');
    const hour: number = Number(parts[0]);
    const minute: number = Number(parts[1]);
    return hour < 24 && minute < 60 ? hour * 60 + minute : -1;
  }

  private static waiting(subject: string, headline: string, reason: string): DailyAction {
    return { stage: 'wait', key: 'wait', headline: headline, reason: reason, actionTitle: '查看学习安排',
      completionStandard: '', nextStep: '', subject: subject, minutes: 0, taskIndex: -1, topicId: '' };
  }

  static decide(snapshot: StudyStateSnapshot, evidence: BankLearningEvidence[], now: number = Date.now()): DailyAction {
    const tasks: StudyTask[] = snapshot.tasks ?? [];
    const goal = GoalPlanningService.prioritize(snapshot.academicGoals ?? [], tasks, now)?.goal;
    const subject: string = goal?.subject ?? snapshot.profileSubject;
    const deferred = (key: string): boolean => (snapshot.actionDeferrals ?? []).some(item => item.key === key && item.until > now);
    const current: StudyTask | undefined = tasks[snapshot.currentTaskIndex];
    if (current !== undefined && !current.completed && (snapshot.isRunning ||
      (((snapshot.focusElapsedSeconds ?? 0) > 0 || current.outcome === 'studying') && snapshot.remainingSeconds > 0))) {
      return { stage: 'resume', key: `task:${current.id}`, headline: current.title, actionTitle: '回到专注',
        reason: snapshot.isRunning ? '星球陪你完成这一件' : '从刚才停下的地方继续',
        completionStandard: '计时只记录投入，结束后提交结果', nextStep: '', subject: current.subject,
        minutes: Math.ceil(snapshot.remainingSeconds / 60), taskIndex: snapshot.currentTaskIndex, topicId: '' };
    }
    const budget: number = LearningActionService.budget(snapshot, now);
    const free: number = LearningActionService.freeMinutes(snapshot, now);
    const preferredId: string = snapshot.preferredTaskId?.trim() ?? '';
    const preferredIndex: number = preferredId.length > 0 ? tasks.findIndex((task: StudyTask) =>
      task.id === preferredId && !task.completed && !deferred(`task:${task.id}`)) : -1;
    if (preferredIndex >= 0) {
      const preferred: StudyTask = tasks[preferredIndex];
      if (preferred.outcome === 'focused' || preferred.outcome === 'submitted') {
        return { stage: 'verify', key: `task:${preferred.id}`, headline: preferred.title,
          actionTitle: '记录学习收获', reason: '这是你刚刚选定的当前任务',
          completionStandard: '写下一项收获，并按任务要求自查', nextStep: '', subject: preferred.subject,
          minutes: 0, taskIndex: preferredIndex, topicId: TaskOutcomeService.topic(preferred) };
      }
      if (budget < 5) { return LearningActionService.waiting(subject, '今天先到这里', '学习预算已用完，已保留未完成任务'); }
      if (free < 5) { return LearningActionService.waiting(subject, '先安心上课', '课后再继续，任务不会丢'); }
      return { stage: 'execute', key: `task:${preferred.id}`, headline: preferred.title,
        actionTitle: '开始这一项', reason: '这是你亲自调整的当前安排',
        completionStandard: '结束后用一句话记录收获或仍不明白的地方', nextStep: '',
        subject: preferred.subject, minutes: Math.min(preferred.minutes, budget, free),
        taskIndex: preferredIndex, topicId: '' };
    }
    const pendingResult: number = tasks.findIndex((task: StudyTask) => !task.completed &&
      (task.outcome === 'focused' || task.outcome === 'submitted') && !deferred(`task:${task.id}`));
    if (pendingResult >= 0) {
      const task: StudyTask = tasks[pendingResult];
      return { stage: 'verify', key: `task:${task.id}`, headline: task.title,
        actionTitle: '记录学习收获',
        reason: task.outcome === 'submitted' ? '结果已记录，再巩固一次' : '已记录投入，还差结果确认',
        completionStandard: '写下一项收获，并按任务要求自查',
        nextStep: '', subject: task.subject, minutes: 0, taskIndex: pendingResult, topicId: TaskOutcomeService.topic(task) };
    }
    // 提交本轮收获不占用专注预算，也不要求有课表空档。
    if (budget < 5) { return LearningActionService.waiting(subject, '今天先到这里', '学习预算已用完，已保留未完成任务'); }
    if (free < 5) { return LearningActionService.waiting(subject, '先安心上课', '课后再继续，任务不会丢'); }
    const eligible: StudyTask[] = tasks.filter((task: StudyTask) => !task.completed && !deferred(`task:${task.id}`) &&
      (goal === undefined || task.goalId === undefined || task.goalId === goal.id));
    // 有明确阶段任务时，优先于同学科的旧演示待办。
    eligible.sort((left: StudyTask, right: StudyTask) =>
      Number(right.goalId === goal?.id && goal !== undefined) - Number(left.goalId === goal?.id && goal !== undefined));
    const task: StudyTask | undefined = eligible[0];
    if (task === undefined) {
      if (deferred('plan')) { return LearningActionService.waiting(subject, '星球晚点再陪你', '想好后再和 Agent 聊聊'); }
      if (tasks.some((item: StudyTask) => !item.completed)) {
        return LearningActionService.waiting(subject, '今天的建议已暂缓', '原目标和任务都保留');
      }
      return { stage: 'plan', key: 'plan', headline: '下一步，想补上哪里？', actionTitle: '和 Agent 聊聊',
        reason: '说说你的薄弱点，一起安排下一步', completionStandard: '', nextStep: '',
        subject: subject, minutes: 0, taskIndex: -1, topicId: '' };
    }
    const minutes: number = Math.min(task.minutes, budget, free);
    return { stage: 'execute', key: `task:${task.id}`, headline: task.title, actionTitle: '开始补学',
      reason: goal !== undefined ? `推进「${goal.title}」` : '先完成这一项，再安排下一步',
      completionStandard: '结束后用一句话记录收获或仍不明白的地方', nextStep: '',
      subject: task.subject, minutes: minutes, taskIndex: tasks.indexOf(task), topicId: '' };
  }
}
