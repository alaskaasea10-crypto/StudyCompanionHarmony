import { StudyStateSnapshot, StudyTask, ScheduleItem, TodayStudyOverride } from '../models/StudyModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { DailyAction } from './DailyActionService';
import { StudyDataCenter } from './StudyDataCenter';
import { TaskOutcomeService } from './TaskOutcomeService';
import { TodayStudyOverrideService } from './TodayStudyOverrideService';

export interface DailyCandidate {
  taskIndex: number;
  task: StudyTask;
}

// 首页、学习入口和桌面卡片只从这里获得下一步，不各自猜测。
export class LearningActionService {
  // 只把当天最近一次同科学习体验作为节奏证据；它不代表知识掌握度，也不改变候选排序。
  static recentStudyExperience(snapshot: StudyStateSnapshot, subject: string,
    now: number = Date.now()): string | undefined {
    const day: string = TodayStudyOverrideService.date(now);
    const results: StudyTask[] = (snapshot.tasks ?? []).filter((task: StudyTask) =>
      task.completed && TodayStudyOverrideService.subjectName(task.subject) ===
      TodayStudyOverrideService.subjectName(subject) && (task.submittedAt ?? 0) > 0 &&
      TodayStudyOverrideService.date(task.submittedAt ?? 0) === day &&
      (task.studyExperience === 'smooth' || task.studyExperience === 'normal' ||
        task.studyExperience === 'struggling'))
      .sort((left: StudyTask, right: StudyTask) => (right.submittedAt ?? 0) - (left.submittedAt ?? 0));
    return results[0]?.studyExperience;
  }

  private static experienceAdjustedMinutes(snapshot: StudyStateSnapshot, subject: string,
    minutes: number, now: number): number {
    if (minutes <= 10 || LearningActionService.recentStudyExperience(snapshot, subject, now) !== 'struggling') {
      return minutes;
    }
    return Math.min(minutes, Math.max(10, Math.round(minutes * 0.6)));
  }

  // 已归档记录与尚未入账的当前专注只在这里汇总，避免 UI、调度和云端上下文各算一套。
  static focusedMinutes(snapshot: StudyStateSnapshot, now: number = Date.now()): number {
    const day: string = TodayStudyOverrideService.date(now);
    const metrics = StudyDataCenter.calculateMetrics(snapshot.tasks ?? [], snapshot.focusRecords ?? [],
      snapshot.quizAttempts ?? [], day, snapshot.studyDayKey === day ? snapshot.todayMinutes ?? 0 : 0);
    const activeSeconds: number = snapshot.isRunning && snapshot.focusSegmentStartedAt > 0 ?
      Math.max(0, Math.floor((now - snapshot.focusSegmentStartedAt) / 1000)) : 0;
    const uncredited: number = snapshot.focusSessionCredited ? 0 :
      Math.floor(Math.min((snapshot.focusMinutes ?? 25) * 60, (snapshot.focusElapsedSeconds ?? 0) + activeSeconds) / 60);
    return Math.max(0, metrics.todayFocusMinutes + uncredited);
  }

  // UI 询问“从现在起还想学多久”；持久层仍兼容原来的“当天总预算”字段。
  static totalBudgetForAdditional(snapshot: StudyStateSnapshot, additionalMinutes: number,
    now: number = Date.now()): number {
    const additional: number = Math.min(240, Math.max(0, Math.floor(additionalMinutes)));
    return LearningActionService.focusedMinutes(snapshot, now) + additional;
  }

  static budget(snapshot: StudyStateSnapshot, now: number = Date.now()): number {
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    // 建档目标不是实际空闲；availableMinutes 保持历史兼容，内部表示当天总预算。
    const daily: number = override?.availableMinutes !== undefined && Number.isFinite(override.availableMinutes) ?
      Math.max(0, override.availableMinutes) :
      Math.min(300, Math.max(15, snapshot.profileDailyMinutes ?? 60));
    const remaining: number = Math.min(300,
      Math.max(0, daily - LearningActionService.focusedMinutes(snapshot, now)));
    return snapshot.energyState === '有点累' ? Math.min(remaining, Math.max(15, Math.round(daily * 0.6))) : remaining;
  }

  // undefined 表示课表无法证明当前空档长度，不能当作全天可用 240 分钟。
  static freeMinutes(snapshot: StudyStateSnapshot, now: number = Date.now()): number | undefined {
    const items: ScheduleItem[] = snapshot.scheduleItems ?? [];
    if (!snapshot.setupScheduleReady || items.length === 0 || items.some(item => item.id.startsWith('demo-'))) {
      return undefined;
    }
    const date: Date = new Date(now + 8 * 3600000);
    const minute: number = date.getUTCHours() * 60 + date.getUTCMinutes();
    let free: number | undefined = undefined;
    items.filter((item: ScheduleItem) => item.weekday === (date.getUTCDay() || 7))
      .forEach((item: ScheduleItem) => {
        const start: number = LearningActionService.clock(item.startTime);
        const end: number = LearningActionService.clock(item.endTime);
        if (start < 0 || end <= start) { return; }
        if (minute >= start && minute < end) { free = 0; }
        else if (start > minute) {
          const gap: number = Math.max(0, start - minute - 5);
          free = free === undefined ? gap : Math.min(free, gap);
        }
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

  // 今日候选仅来自真实任务与今日意图；长期日期提醒不参与调度。
  static candidates(snapshot: StudyStateSnapshot, now: number = Date.now()): DailyCandidate[] {
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const deferred = (task: StudyTask): boolean => (snapshot.actionDeferrals ?? [])
      .some(item => item.key === `task:${task.id}` && item.until > now);
    const candidates: DailyCandidate[] = [];
    (snapshot.tasks ?? []).forEach((task: StudyTask, taskIndex: number) => {
      if (!TodayStudyOverrideService.eligibleTask(task, override) || deferred(task) ||
        task.outcome === 'focused' || task.outcome === 'submitted' ||
        !Number.isFinite(task.minutes) || task.minutes < 5) { return; }
      if (!TodayStudyOverrideService.matchesIntent(task, override)) { return; }
      candidates.push({ taskIndex: taskIndex, task: task });
    });
    const preferredId: string = override?.preferredTaskId ?? '';
    const preferredSubject: string = override?.preferredSubject?.trim() ?? '';
    candidates.sort((left: DailyCandidate, right: DailyCandidate): number => {
      const preferredTaskDifference: number = Number(right.task.id === preferredId && preferredId.length > 0) -
        Number(left.task.id === preferredId && preferredId.length > 0);
      if (preferredTaskDifference !== 0) { return preferredTaskDifference; }
      const subjectDifference: number = Number(TodayStudyOverrideService.subjectName(right.task.subject) ===
        TodayStudyOverrideService.subjectName(preferredSubject) && preferredSubject.length > 0) -
        Number(TodayStudyOverrideService.subjectName(left.task.subject) ===
          TodayStudyOverrideService.subjectName(preferredSubject) && preferredSubject.length > 0);
      if (subjectDifference !== 0) { return subjectDifference; }
      const suggestions: string[] = override?.suggestedTaskIds ?? [];
      const leftRank: number = suggestions.indexOf(left.task.id ?? '');
      const rightRank: number = suggestions.indexOf(right.task.id ?? '');
      if (leftRank !== rightRank) {
        return (leftRank < 0 ? suggestions.length : leftRank) - (rightRank < 0 ? suggestions.length : rightRank);
      }
      // 需求相同时保留原有待办顺序，不为多学科视觉强行轮换。
      return left.taskIndex - right.taskIndex;
    });
    return candidates;
  }

  private static waiting(subject: string, headline: string, reason: string): DailyAction {
    return { stage: 'wait', key: 'wait', headline: headline, reason: reason, actionTitle: '查看学习安排',
      completionStandard: '', nextStep: '', subject: subject, minutes: 0, taskIndex: -1, topicId: '' };
  }

  static suggestedMinutes(task: StudyTask, override?: TodayStudyOverride): number {
    const index: number = (override?.suggestedTaskIds ?? []).indexOf(task.id ?? '');
    const value: number | undefined = index >= 0 ? override?.suggestedTaskMinutes?.[index] : undefined;
    return value !== undefined && Number.isFinite(value) && value >= 5 ? Math.min(task.minutes, value) : task.minutes;
  }

  static decide(snapshot: StudyStateSnapshot, evidence: BankLearningEvidence[], now: number = Date.now()): DailyAction {
    const tasks: StudyTask[] = snapshot.tasks ?? [];
    const subject: string = TodayStudyOverrideService.active(snapshot, now)?.intent?.subject ?? '';
    const current: StudyTask | undefined = tasks[snapshot.currentTaskIndex];
    if (current !== undefined && TodayStudyOverrideService.realTask(current) && !current.completed && (snapshot.isRunning ||
      (((snapshot.focusElapsedSeconds ?? 0) > 0 || current.outcome === 'studying') && snapshot.remainingSeconds > 0))) {
      return { stage: 'resume', key: `task:${current.id}`, taskId: current.id,
        headline: current.title, actionTitle: '回到专注',
        reason: snapshot.isRunning ? '星球陪你完成这一件' : '从刚才停下的地方继续',
        completionStandard: '计时只记录投入，结束后提交结果', nextStep: '', subject: current.subject,
        minutes: Math.ceil(snapshot.remainingSeconds / 60), taskIndex: snapshot.currentTaskIndex, topicId: '' };
    }
    // 已投入的学习必须先反馈，即使今天选择了另一项或跳过了本任务。
    const pendingResult: number = tasks.findIndex((task: StudyTask) => TodayStudyOverrideService.realTask(task) && !task.completed &&
      (task.outcome === 'focused' || task.outcome === 'submitted'));
    if (pendingResult >= 0) {
      const task: StudyTask = tasks[pendingResult];
      return { stage: 'verify', key: `task:${task.id}`, taskId: task.id, headline: task.title,
        actionTitle: '记录学习收获',
        reason: task.outcome === 'submitted' ? '结果已记录，再巩固一次' : '已记录投入，还差结果确认',
        completionStandard: '写下一项收获，并按任务要求自查',
        nextStep: '', subject: task.subject, minutes: 0, taskIndex: pendingResult, topicId: TaskOutcomeService.topic(task) };
    }
    // 提交本轮收获不占用学习预算，也不要求课表空档。
    const budget: number = LearningActionService.budget(snapshot, now);
    const free: number | undefined = LearningActionService.freeMinutes(snapshot, now);
    if (budget < 5) {
      return LearningActionService.waiting(subject, '今天原定安排已经完成', '还想继续？可以调整今天安排，任务仍会保留');
    }
    if (free !== undefined && free < 5) { return LearningActionService.waiting(subject, '先安心上课', '课后再继续，任务不会丢'); }
    const first: DailyCandidate | undefined = LearningActionService.candidates(snapshot, now)[0];
    if (first === undefined) {
      const intentSubject: string = TodayStudyOverrideService.active(snapshot, now)?.intent?.subject ?? '';
      if (intentSubject.length > 0) {
        return LearningActionService.waiting(intentSubject, `暂无可执行的${intentSubject}任务`,
          '先添加该科任务，或调整今天安排；不会替你切换科目');
      }
      if (tasks.some((item: StudyTask) => TodayStudyOverrideService.eligibleTask(item,
        TodayStudyOverrideService.active(snapshot, now)))) {
        return LearningActionService.waiting(subject, '今天的建议已暂缓', '原目标和任务都保留');
      }
      return { stage: 'plan', key: 'plan', headline: '下一步，想补上哪里？', actionTitle: '和 Agent 聊聊',
        reason: '说说你的薄弱点，一起安排下一步', completionStandard: '', nextStep: '',
        subject: subject, minutes: 0, taskIndex: -1, topicId: '' };
    }
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const reason: string = first.task.id === override?.preferredTaskId ? '这是你今天选定的当前安排' :
      override?.intent?.subject ? '按你今天明确选择的科目继续' : '先推进已保存的未完成任务';
    const requested: number = override?.intent?.minutesKind === 'task' ?
      override.intent.requestedMinutes ?? first.task.minutes : first.task.minutes;
    const baseMinutes: number = Math.min(LearningActionService.suggestedMinutes(first.task, override), requested,
      budget, free ?? first.task.minutes);
    const minutes: number = LearningActionService.experienceAdjustedMinutes(
      snapshot, first.task.subject, baseMinutes, now);
    return { stage: 'execute', key: `task:${first.task.id}`, taskId: first.task.id,
      headline: first.task.title, actionTitle: '开始这一项',
      reason: reason,
      completionStandard: '结束后用一句话记录收获或仍不明白的地方', nextStep: '',
      subject: first.task.subject, minutes: minutes, taskIndex: first.taskIndex, topicId: '' };
  }
}
