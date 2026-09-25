import { AcademicGoal, StudyStateSnapshot, StudyTask, ScheduleItem, TodayStudyOverride } from '../models/StudyModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { DailyAction } from './DailyActionService';
import { GoalPlanningService } from './GoalPlanningService';
import { StudyDataCenter } from './StudyDataCenter';
import { TaskOutcomeService } from './TaskOutcomeService';
import { TodayStudyOverrideService } from './TodayStudyOverrideService';

export interface DailyCandidate {
  taskIndex: number;
  task: StudyTask;
  deadlineDays?: number;
  deadlineSource?: string;
}

interface LinkedDeadline {
  days?: number;
  source?: string;
}

// 首页、学习入口和桌面卡片只从这里获得下一步，不各自猜测。
export class LearningActionService {
  // 只把当天最近一次同科学习体验作为节奏证据；它不代表知识掌握度，也不改变候选排序。
  static recentStudyExperience(snapshot: StudyStateSnapshot, subject: string,
    now: number = Date.now()): string | undefined {
    const day: string = TodayStudyOverrideService.date(now);
    const results: StudyTask[] = (snapshot.tasks ?? []).filter((task: StudyTask) =>
      task.completed && task.subject === subject && (task.submittedAt ?? 0) > 0 &&
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

  static budget(snapshot: StudyStateSnapshot, now: number = Date.now()): number {
    const day: string = TodayStudyOverrideService.date(now);
    const metrics = StudyDataCenter.calculateMetrics(snapshot.tasks ?? [], snapshot.focusRecords ?? [],
      snapshot.quizAttempts ?? [], day, snapshot.studyDayKey === day ? snapshot.todayMinutes ?? 0 : 0);
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    // 建档目标不是实际空闲；只有今日明确填写的分钟数才覆盖它。
    const daily: number = override?.availableMinutes !== undefined && Number.isFinite(override.availableMinutes) ?
      Math.min(240, Math.max(0, override.availableMinutes)) :
      Math.min(240, Math.max(15, snapshot.profileDailyMinutes ?? 60));
    const activeSeconds: number = snapshot.isRunning && snapshot.focusSegmentStartedAt > 0 ?
      Math.max(0, Math.floor((now - snapshot.focusSegmentStartedAt) / 1000)) : 0;
    const uncredited: number = snapshot.focusSessionCredited ? 0 :
      Math.floor(Math.min((snapshot.focusMinutes ?? 25) * 60, (snapshot.focusElapsedSeconds ?? 0) + activeSeconds) / 60);
    const remaining: number = Math.max(0, daily - metrics.todayFocusMinutes - uncredited);
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

  private static linkedDeadline(task: StudyTask, goals: AcademicGoal[], now: number): LinkedDeadline {
    const goal: AcademicGoal | undefined = goals.find((item: AcademicGoal) =>
      !item.completed && item.id === task.goalId);
    if (goal === undefined) { return {}; }
    // 阶段 dueDate 是规则拆解出的推算值；排序只引用用户保存的目标截止日期。
    const days: number = GoalPlanningService.daysUntil(goal.deadline, now);
    return days === 999 ? {} : { days: days, source: '已保存的学习目标' };
  }

  // 全部真实未完成任务形成候选池；目标只提供关联任务的真实日期，不缩小候选范围。
  static candidates(snapshot: StudyStateSnapshot, now: number = Date.now()): DailyCandidate[] {
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const goals: AcademicGoal[] = snapshot.academicGoals ?? [];
    const deferred = (task: StudyTask): boolean => (snapshot.actionDeferrals ?? [])
      .some(item => item.key === `task:${task.id}` && item.until > now);
    const candidates: DailyCandidate[] = [];
    (snapshot.tasks ?? []).forEach((task: StudyTask, taskIndex: number) => {
      if (!TodayStudyOverrideService.eligibleTask(task, override) || deferred(task) ||
        task.outcome === 'focused' || task.outcome === 'submitted' ||
        !Number.isFinite(task.minutes) || task.minutes < 5) { return; }
      const deadline: LinkedDeadline = LearningActionService.linkedDeadline(task, goals, now);
      candidates.push({ taskIndex: taskIndex, task: task, deadlineDays: deadline.days,
        deadlineSource: deadline.source });
    });
    const preferredId: string = override?.preferredTaskId ?? '';
    const preferredSubject: string = override?.preferredSubject?.trim() ?? '';
    candidates.sort((left: DailyCandidate, right: DailyCandidate): number => {
      const preferredTaskDifference: number = Number(right.task.id === preferredId && preferredId.length > 0) -
        Number(left.task.id === preferredId && preferredId.length > 0);
      if (preferredTaskDifference !== 0) { return preferredTaskDifference; }
      const urgent = (item: DailyCandidate): number => item.deadlineDays !== undefined && item.deadlineDays <= 1 ? 1 : 0;
      const urgentDifference: number = urgent(right) - urgent(left);
      if (urgentDifference !== 0) { return urgentDifference; }
      const subjectDifference: number = Number(right.task.subject === preferredSubject && preferredSubject.length > 0) -
        Number(left.task.subject === preferredSubject && preferredSubject.length > 0);
      if (subjectDifference !== 0) { return subjectDifference; }
      const leftDays: number = left.deadlineDays ?? 999;
      const rightDays: number = right.deadlineDays ?? 999;
      if (leftDays !== rightDays) { return leftDays - rightDays; }
      // 需求相同时保留原有待办顺序，不为多学科视觉强行轮换。
      return left.taskIndex - right.taskIndex;
    });
    return candidates;
  }

  private static waiting(subject: string, headline: string, reason: string): DailyAction {
    return { stage: 'wait', key: 'wait', headline: headline, reason: reason, actionTitle: '查看学习安排',
      completionStandard: '', nextStep: '', subject: subject, minutes: 0, taskIndex: -1, topicId: '' };
  }

  static decide(snapshot: StudyStateSnapshot, evidence: BankLearningEvidence[], now: number = Date.now()): DailyAction {
    const tasks: StudyTask[] = snapshot.tasks ?? [];
    const subject: string = snapshot.profileSubject;
    const current: StudyTask | undefined = tasks[snapshot.currentTaskIndex];
    if (current !== undefined && !current.completed && (snapshot.isRunning ||
      (((snapshot.focusElapsedSeconds ?? 0) > 0 || current.outcome === 'studying') && snapshot.remainingSeconds > 0))) {
      return { stage: 'resume', key: `task:${current.id}`, taskId: current.id,
        headline: current.title, actionTitle: '回到专注',
        reason: snapshot.isRunning ? '星球陪你完成这一件' : '从刚才停下的地方继续',
        completionStandard: '计时只记录投入，结束后提交结果', nextStep: '', subject: current.subject,
        minutes: Math.ceil(snapshot.remainingSeconds / 60), taskIndex: snapshot.currentTaskIndex, topicId: '' };
    }
    // 已投入的学习必须先反馈，即使今天选择了另一项或跳过了本任务。
    const pendingResult: number = tasks.findIndex((task: StudyTask) => !task.completed &&
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
    if (budget < 5) { return LearningActionService.waiting(subject, '今天先到这里', '今日学习目标已用完，任务仍保留'); }
    if (free !== undefined && free < 5) { return LearningActionService.waiting(subject, '先安心上课', '课后再继续，任务不会丢'); }
    const first: DailyCandidate | undefined = LearningActionService.candidates(snapshot, now)[0];
    if (first === undefined) {
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
      first.deadlineDays !== undefined ? `${first.deadlineSource ?? '已保存的目标'}：${first.deadlineDays <= 0 ?
        '今天或此前到期' : `还有${first.deadlineDays}天`}` : '先推进已保存的未完成任务';
    const baseMinutes: number = Math.min(first.task.minutes, budget, free ?? first.task.minutes);
    const minutes: number = LearningActionService.experienceAdjustedMinutes(
      snapshot, first.task.subject, baseMinutes, now);
    return { stage: 'execute', key: `task:${first.task.id}`, taskId: first.task.id,
      headline: first.task.title, actionTitle: '开始这一项',
      reason: reason,
      completionStandard: '结束后用一句话记录收获或仍不明白的地方', nextStep: '',
      subject: first.task.subject, minutes: minutes, taskIndex: first.taskIndex, topicId: '' };
  }
}
