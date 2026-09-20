import { AcademicGoal, FocusRecord, KnowledgeMastery, QuizAttempt, StudyStateSnapshot, StudyTask } from '../models/StudyModels';
import { DailyAction } from './DailyActionService';
import { GoalPlanningService } from './GoalPlanningService';
import { KnowledgeMasteryService } from './KnowledgeMasteryService';
import { LearningActionService } from './LearningActionService';
import { StudyDataCenter } from './StudyDataCenter';

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

export interface AgentDecisionResult {
  recommendedAction: DailyAction;
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
    return days === 999 ? undefined : days;
  }

  private static decisionGoals(snapshot: StudyStateSnapshot, confirmedExam: boolean): AcademicGoal[] {
    const goals: AcademicGoal[] = snapshot.academicGoals ?? [];
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

  static decide(snapshot: StudyStateSnapshot, now: number = Date.now()): AgentDecisionResult {
    const hasSchedule: boolean = AgentDecisionService.realSchedule(snapshot);
    const examDays: number | undefined = AgentDecisionService.confirmedExamDays(snapshot, now);
    const usableSnapshot: StudyStateSnapshot = JSON.parse(JSON.stringify(snapshot)) as StudyStateSnapshot;
    usableSnapshot.setupScheduleReady = hasSchedule;
    usableSnapshot.academicGoals = AgentDecisionService.decisionGoals(snapshot, examDays !== undefined);
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
      selected.id === snapshot.preferredTaskId;
    const evidence: AgentDecisionEvidence[] = [];
    const reasons: AgentDecisionReason[] = [];
    if (selected !== undefined) {
      evidence.push({ label: '当前任务', value: `${selected.subject} · ${selected.title}`,
        source: selected.source === 'profile' ? '建档生成的初始建议' : preferred ? '你手动设定' : '已保存的待办' });
      const data: string = action.stage === 'resume' ? '这项专注已经开始' :
        action.stage === 'verify' ? '这项任务已记录投入，尚待提交收获' :
        preferred ? '你把这项任务设为了当前安排' :
        selected.source === 'profile' ? '建档时生成的初始任务尚未完成' : '待办中有这项未完成任务';
      const judgment: string = action.stage === 'resume' ? '先完成正在进行的学习' :
        action.stage === 'verify' ? '先确认这次学习的结果' :
        preferred ? '优先执行你主动选择的任务' : '当前可以推进这项任务';
      reasons.push({ data: data, judgment: judgment, recommendation: action.headline });
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
      const free: number = LearningActionService.freeMinutes(usableSnapshot, now);
      if (free < 240) {
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
    const pending: number = tasks.filter((task: StudyTask) => !task.completed).length;
    evidence.push({ label: '未完成安排', value: `${pending}项`, source: '已保存的任务列表' });
    if (reasons.length === 0) {
      const budget: number = LearningActionService.budget(usableSnapshot, now);
      const free: number = hasSchedule ? LearningActionService.freeMinutes(usableSnapshot, now) : 240;
      const deferred: boolean = (snapshot.actionDeferrals ?? []).some(item => item.until > now);
      const fallbackData: string = action.stage === 'wait' ? budget < 5 ? '当前可用于专注的时长不足5分钟' :
        free < 5 ? '课表显示当前没有足够空档' : deferred ? '当前建议已被暂缓' : '暂时没有可执行的安排' :
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
    return {
      recommendedAction: action,
      reasonChain: reasons.slice(0, 3),
      priority: priority,
      confidenceLevel: selected !== undefined && confirmedSources >= 2 ? '依据较充分' : '依据有限',
      evidence: evidence,
      status: { remainingGoalMinutes: remainingGoalMinutes, pendingTaskCount: pending,
        weakPointCount: weakCount, recentTrend: AgentDecisionService.recentTrend(snapshot.focusRecords ?? [], now) }
    };
  }
}
