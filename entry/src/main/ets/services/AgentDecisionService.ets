import { AcademicGoal, FocusRecord, KnowledgeMastery, QuizAttempt, StudyStateSnapshot, StudyTask, TodayStudyOverride } from '../models/StudyModels';
import { DailyAction } from './DailyActionService';
import { GoalPlanningService } from './GoalPlanningService';
import { KnowledgeMasteryService } from './KnowledgeMasteryService';
import { DailyCandidate, LearningActionService } from './LearningActionService';
import { StudyDataCenter } from './StudyDataCenter';
import { TodayStudyOverrideService } from './TodayStudyOverrideService';
import { StudyDecisionDebug, StudyDecisionDebugAction, StudyDecisionDebugPlanItem } from './StudyDecisionDebug';

export interface AgentDecisionEvidence {
  label: string;
  value: string;
  source: string;
}

export interface AgentDecisionReason {
  data: string;
  judgment: string;
  recommendation: string;
}

export interface AgentDecisionStatus {
  remainingGoalMinutes?: number;
  pendingTaskCount: number;
  weakPointCount?: number;
  recentTrend: string;
}

// 今日建议只引用已有任务，不写入任务列表，也不代表已确认的课表时段。
export interface AgentDailyPlanItem {
  taskId: string;
  title: string;
  subject: string;
  suggestedMinutes: number;
  order: number;
  evidence: AgentDecisionEvidence[];
}

export interface AgentDecisionResult {
  recommendedAction: DailyAction;
  dailyPlan: AgentDailyPlanItem[];
  reasonChain: AgentDecisionReason[];
  priority: string;
  confidenceLevel: string;
  evidence: AgentDecisionEvidence[];
  status: AgentDecisionStatus;
}

// 只解释当前真实可执行的下一步；不从模型文本推测分数、考试日期或学习效率。
export class AgentDecisionService {
  private static dayKey(now: number): string {
    return new Date(now + 8 * 3600000).toISOString().substring(0, 10);
  }

  private static realSchedule(snapshot: StudyStateSnapshot): boolean {
    const items = snapshot.scheduleItems ?? [];
    return snapshot.setupScheduleReady === true && items.length > 0 &&
      items.every(item => !item.id.startsWith('demo-'));
  }

  private static confirmedExamDays(snapshot: StudyStateSnapshot, now: number): number | undefined {
    if (snapshot.profileExamDateConfirmed !== true) { return undefined; }
    const date: string = snapshot.profileExamDate ?? '';
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) { return undefined; }
    const parsed: Date = new Date(`${date}T00:00:00+08:00`);
    if (!Number.isFinite(parsed.getTime()) || AgentDecisionService.dayKey(parsed.getTime()) !== date) {
      return undefined;
    }
    const days: number = GoalPlanningService.daysUntil(date, now);
    return days === 999 || days < 0 ? undefined : days;
  }

  private static decisionGoals(snapshot: StudyStateSnapshot, confirmedExam: boolean,
    now: number): AcademicGoal[] {
    const goals: AcademicGoal[] = GoalPlanningService.activeGoals(snapshot.academicGoals ?? [], now);
    if (confirmedExam) { return goals; }
    // 旧档案可能自动生成“某科考试”目标；未确认日期不能参与排序。
    return goals.filter((goal: AcademicGoal) => !(goal.title === `${snapshot.profileSubject}考试` &&
      goal.subject === snapshot.profileSubject && goal.deadline === snapshot.profileExamDate));
  }

  private static weakPointCount(snapshot: StudyStateSnapshot): number | undefined {
    const attempts: QuizAttempt[] = snapshot.quizAttempts ?? [];
    const mastery: KnowledgeMastery[] = snapshot.knowledgeMastery ?? [];
    if (attempts.length === 0 || mastery.length === 0) { return undefined; }
    return mastery.filter((point: KnowledgeMastery) => point.attemptCount > 0 &&
      KnowledgeMasteryService.statusFor(point.score) === '需要复习' &&
      attempts.some((attempt: QuizAttempt) => attempt.subject === point.subject &&
        attempt.knowledgePoint === point.knowledgePoint)).length;
  }

  private static recentTrend(records: FocusRecord[], now: number): string {
    let previous: number = 0;
    let recent: number = 0;
    let previousDays: number = 0;
    let recentDays: number = 0;
    for (let offset: number = 0; offset < 6; offset++) {
      const day: string = AgentDecisionService.dayKey(now - offset * 86400000);
      const minutes: number = records.filter((record: FocusRecord) => record.dayKey === day)
        .reduce((sum: number, record: FocusRecord) => sum + Math.floor(Math.max(0, record.elapsedSeconds) / 60), 0);
      if (offset < 3) { recent += minutes; if (minutes > 0) { recentDays++; } }
      else { previous += minutes; if (minutes > 0) { previousDays++; } }
    }
    if (recentDays < 2 || previousDays < 2) { return '记录不足，暂不判断趋势'; }
    if (recent === previous) { return '近3天专注时长与前3天持平'; }
    return `近3天专注时长较前3天${recent > previous ? '增加' : '减少'}${Math.abs(recent - previous)}分钟`;
  }

  private static dailyPlan(snapshot: StudyStateSnapshot, action: DailyAction, now: number): AgentDailyPlanItem[] {
    // “先安排 / 先上课”不是学习时段；反馈和专注则保留同一 taskId 作为当前阶段。
    if (action.stage !== 'execute' && action.stage !== 'resume' && action.stage !== 'verify') { return []; }
    const tasks: StudyTask[] = snapshot.tasks ?? [];
    const result: AgentDailyPlanItem[] = [];
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const free: number | undefined = LearningActionService.freeMinutes(snapshot, now);
    let remaining: number = Math.min(LearningActionService.budget(snapshot, now),
      free === undefined ? LearningActionService.budget(snapshot, now) : free);
    const selected: StudyTask | undefined = tasks[action.taskIndex];
    const add = (task: StudyTask, minutes: number, current: boolean, candidate?: DailyCandidate): void => {
      if (task.id === undefined || !Number.isFinite(minutes) || minutes < 0) { return; }
      const evidence: AgentDecisionEvidence[] = [{ label: '待办', value: `「${task.title}」尚未完成`,
        source: task.source === 'profile' ? '建档时保存的初始建议' : '已保存的学习任务' }];
      if (minutes > 0) {
        evidence.push({ label: '建议时长', value: `${minutes}分钟`, source: current ? '当前行动时长' :
          minutes < task.minutes ? '任务原定时长与今日可安排时间' : '任务原定时长' });
      }
      if (candidate?.deadlineDays !== undefined) {
        evidence.push({ label: '目标日期', value: candidate.deadlineDays <= 0 ? '今天或此前到期' :
          `还有${candidate.deadlineDays}天`, source: candidate.deadlineSource ?? '已保存的学习目标' });
      }
      if (current && task.id === override?.preferredTaskId) {
        evidence.push({ label: '当前安排', value: '你选择了先做这项', source: '手动调整' });
      }
      result.push({ taskId: task.id, title: task.title, subject: task.subject,
        suggestedMinutes: minutes, order: result.length + 1, evidence: evidence });
      remaining = Math.max(0, remaining - minutes);
    };
    if (selected !== undefined) {
      const selectedCandidate: DailyCandidate | undefined = LearningActionService.candidates(snapshot, now)
        .find((item: DailyCandidate) => item.task.id === selected.id);
      add(selected, action.minutes, true, selectedCandidate);
    }
    // 未确认今日实际可用时间时，只建议眼前这一项，不伪造后续阶段的分钟数。
    if (override?.availableMinutes === undefined) { return result; }
    if (remaining < 5) { return result; }
    const candidates: DailyCandidate[] = LearningActionService.candidates(snapshot, now);
    for (const candidate of candidates) {
      if (remaining < 5) { break; }
      if (candidate.taskIndex === action.taskIndex) { continue; }
      const minutes: number = Math.min(candidate.task.minutes, remaining);
      if (minutes < 5) { break; }
      add(candidate.task, minutes, false, candidate);
    }
    return result;
  }

  static decide(snapshot: StudyStateSnapshot, now: number = Date.now()): AgentDecisionResult {
    const hasSchedule: boolean = AgentDecisionService.realSchedule(snapshot);
    const examDays: number | undefined = AgentDecisionService.confirmedExamDays(snapshot, now);
    const usableSnapshot: StudyStateSnapshot = JSON.parse(JSON.stringify(snapshot)) as StudyStateSnapshot;
    usableSnapshot.setupScheduleReady = hasSchedule;
    usableSnapshot.academicGoals = AgentDecisionService.decisionGoals(snapshot, examDays !== undefined, now);
    const action: DailyAction = LearningActionService.decide(usableSnapshot, [], now);
    const day: string = AgentDecisionService.dayKey(now);
    const todayMinutes: number = StudyDataCenter.calculateMetrics(snapshot.tasks ?? [], snapshot.focusRecords ?? [],
      snapshot.quizAttempts ?? [], day, snapshot.studyDayKey === day ? snapshot.todayMinutes ?? 0 : 0).todayFocusMinutes;
    const goalSnapshot: StudyStateSnapshot = JSON.parse(JSON.stringify(usableSnapshot)) as StudyStateSnapshot;
    goalSnapshot.energyState = '一般';
    const remainingGoalMinutes: number | undefined = snapshot.profileCompleted &&
      Number.isFinite(snapshot.profileDailyMinutes) && snapshot.profileDailyMinutes > 0 ?
      LearningActionService.budget(goalSnapshot, now) : undefined;
    const tasks: StudyTask[] = snapshot.tasks ?? [];
    const selected: StudyTask | undefined = action.taskIndex >= 0 ? tasks[action.taskIndex] : undefined;
    const preferred: boolean = selected !== undefined && selected.id !== undefined &&
      selected.id === TodayStudyOverrideService.active(snapshot, now)?.preferredTaskId;
    const evidence: AgentDecisionEvidence[] = [];
    const reasons: AgentDecisionReason[] = [];
    if (selected !== undefined) {
      evidence.push({ label: '当前任务', value: `${selected.subject} · ${selected.title}`,
        source: selected.source === 'profile' ? '建档生成的初始建议' : preferred ? '你手动设定' : '已保存的待办' });
      const selectedCandidate: DailyCandidate | undefined = LearningActionService.candidates(usableSnapshot, now)
        .find((candidate: DailyCandidate) => candidate.task.id === selected.id);
      if (selectedCandidate?.deadlineDays !== undefined) {
        evidence.push({ label: '目标截止', value: selectedCandidate.deadlineDays <= 0 ? '今天或此前到期' :
          `还有${selectedCandidate.deadlineDays}天`, source: selectedCandidate.deadlineSource ?? '已保存的学习目标' });
      }
      const data: string = action.stage === 'resume' ? '这项专注已经开始' :
        action.stage === 'verify' ? '这项任务已记录投入，尚待提交收获' :
        preferred ? '你把这项任务设为了当前安排' :
        selected.source === 'profile' ? '建档时生成的初始任务尚未完成' : '待办中有这项未完成任务';
      const judgment: string = action.stage === 'resume' ? '先完成正在进行的学习' :
        action.stage === 'verify' ? '先确认这次学习的结果' :
        preferred ? '优先执行你主动选择的任务' : action.stage === 'execute' ? action.reason :
          '当前可以推进这项任务';
      reasons.push({ data: data, judgment: judgment, recommendation: action.headline });
      const recentExperience: string | undefined = LearningActionService.recentStudyExperience(
        usableSnapshot, selected.subject, now);
      const baseMinutes: number = Math.min(selected.minutes, LearningActionService.budget(usableSnapshot, now),
        LearningActionService.freeMinutes(usableSnapshot, now) ?? selected.minutes);
      if (action.stage === 'execute' && recentExperience === 'struggling' && action.minutes < baseMinutes) {
        evidence.push({ label: '最近学习体验', value: '上一项同科学习反馈：有点吃力',
          source: '你提交的学习结果' });
        reasons.push({ data: '你刚才学习这个科目时觉得有点吃力', judgment: '下一步不安排得太满',
          recommendation: `先用${action.minutes}分钟继续推进` });
      }
    }
    if (remainingGoalMinutes !== undefined) {
      evidence.push({ label: '今日目标剩余', value: `${remainingGoalMinutes}分钟（今日已专注${todayMinutes}分钟）`,
        source: '个人设置与本机专注记录' });
      if (action.stage === 'execute' && action.minutes > 0) {
        reasons.push({ data: `今日目标剩余${remainingGoalMinutes}分钟`, judgment: '本轮时长已按目标与当前空档限制',
          recommendation: `先投入${action.minutes}分钟` });
      }
    }
    if (hasSchedule) {
      const free: number | undefined = LearningActionService.freeMinutes(usableSnapshot, now);
      if (free !== undefined) {
        evidence.push({ label: '课表空档', value: free < 5 ? '当前无可用空档' : `接下来最多约${free}分钟`,
          source: '已确认的本机课表' });
        if (action.stage === 'wait' && free < 5) {
          reasons.push({ data: '当前课表没有足够的学习空档', judgment: '先保留待办', recommendation: action.headline });
        }
      }
    } else if (snapshot.setupScheduleReady && (snapshot.scheduleItems ?? []).some(item =>
      item.id.startsWith('demo-'))) {
      evidence.push({ label: '课表来源', value: '演示课表未参与决策', source: '课表记录' });
    }
    if (examDays !== undefined && selected !== undefined && selected.subject === snapshot.profileSubject) {
      evidence.push({ label: '已确认考试日期', value: examDays < 0 ? `已过期${Math.abs(examDays)}天` :
        examDays === 0 ? '今天' : `还有${examDays}天`, source: '你确认的个人目标' });
      if (!preferred && action.stage === 'execute' && examDays >= 0) {
        reasons.push({ data: examDays === 0 ? '考试日期为今天' : `距离考试${examDays}天`,
          judgment: '继续推进该科目待办', recommendation: action.headline });
      }
    } else if (examDays === undefined && (snapshot.profileExamDate ?? '').length > 0) {
      evidence.push({ label: '考试日期', value: '待确认，未参与决策', source: '个人档案' });
    }
    const weakCount: number | undefined = AgentDecisionService.weakPointCount(snapshot);
    if (weakCount !== undefined) {
      evidence.push({ label: '历史练习待巩固点', value: `${weakCount}个`, source: '旧测验记录，仅作状态参考' });
    }
    const activeOverride: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const pending: number = tasks.filter((task: StudyTask) => !task.completed &&
      TodayStudyOverrideService.currentTask(task, activeOverride)).length;
    evidence.push({ label: '未完成安排', value: `${pending}项`, source: '已保存的任务列表' });
    if (reasons.length === 0) {
      const budget: number = LearningActionService.budget(usableSnapshot, now);
      const free: number | undefined = hasSchedule ? LearningActionService.freeMinutes(usableSnapshot, now) : undefined;
      const deferred: boolean = (snapshot.actionDeferrals ?? []).some(item => item.until > now);
      const fallbackData: string = action.stage === 'wait' ? budget < 5 ? '当前可用于专注的时长不足5分钟' :
        free !== undefined && free < 5 ? '课表显示当前没有足够空档' : deferred ? '当前建议已被暂缓' : '暂时没有可执行的安排' :
        pending === 0 ? '当前没有未完成任务' : `${pending}项安排尚未完成`;
      reasons.push({ data: fallbackData,
        judgment: action.stage === 'plan' ? '需要先明确下一步任务' : '保留当前安排',
        recommendation: action.headline });
    }
    const confirmedSources: number = (selected !== undefined && selected.source !== 'profile' ? 1 : 0) +
      (todayMinutes > 0 ? 1 : 0) + (hasSchedule ? 1 : 0) + (examDays !== undefined ? 1 : 0);
    const priority: string = action.stage === 'resume' || action.stage === 'verify' || preferred ||
      (examDays !== undefined && examDays >= 0 && examDays <= 3 && selected?.subject === snapshot.profileSubject) ?
      '优先处理' : action.stage === 'execute' ? '按计划推进' : '待安排';
    const dailyPlan: AgentDailyPlanItem[] = AgentDecisionService.dailyPlan(usableSnapshot, action, now);
    const result: AgentDecisionResult = {
      recommendedAction: action,
      dailyPlan: dailyPlan,
      reasonChain: reasons.slice(0, 3),
      priority: priority,
      confidenceLevel: selected !== undefined && confirmedSources >= 2 ? '依据较充分' : '依据有限',
      evidence: evidence,
      status: { remainingGoalMinutes: remainingGoalMinutes, pendingTaskCount: pending,
        weakPointCount: weakCount, recentTrend: AgentDecisionService.recentTrend(snapshot.focusRecords ?? [], now) }
    };
    const debugAction: StudyDecisionDebugAction = {
      taskId: action.taskId, subject: action.subject, headline: action.headline,
      minutes: action.minutes, stage: action.stage
    };
    const debugPlan: StudyDecisionDebugPlanItem[] = dailyPlan.map((item: AgentDailyPlanItem): StudyDecisionDebugPlanItem => {
      return { order: item.order, taskId: item.taskId, subject: item.subject,
        title: item.title, suggestedMinutes: item.suggestedMinutes };
    });
    StudyDecisionDebug.decision(debugAction, debugPlan);
    return result;
  }
}
