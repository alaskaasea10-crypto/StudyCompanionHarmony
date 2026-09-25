import {
  AgentContextPayload,
  AgentPlanRequest,
  AgentProfilePayload,
  QuizFeedbackPayload
} from '../models/AgentModels';
import { AcademicGoal, FocusRecord, KnowledgeMastery, QuizAttempt, ScheduleItem, StudyMetrics, StudyTask,
  TodayStudyOverride } from '../models/StudyModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { BankLearningBridge } from './BankLearningBridge';
import { TodayPlanService } from './TodayPlanService';
import { BankPlanBudget } from './BankPlanBudget';

export interface LearningContextInput {
  academicGoals?: AcademicGoal[];
  todayStudyOverride?: TodayStudyOverride;
  confirmedAvailableMinutes?: number;
  localDailyPlanTaskIds?: string[];
  localDailyPlanMinutes?: number[];
  eligibleTaskIds?: string[];
  protectedTaskId?: string;
  protectedStage?: string;
  recentFocusRecords?: FocusRecord[];
  remainingBudget?: number;
  dailyTargetRemainingMinutes?: number;
  appendMode?: boolean;
  bankTopicId?: string;
  bankAppendMode?: boolean;
  bankEvidence?: BankLearningEvidence[];
  requestText: string;
  profile: AgentProfilePayload;
  date: string;
  examDays: number;
  energyState: string;
  scheduleReady: boolean;
  scheduleItems: ScheduleItem[];
  tasks: StudyTask[];
  metrics: StudyMetrics;
  quizAttempts: QuizAttempt[];
  knowledgeMastery: KnowledgeMastery[];
}

export class LearningDecisionPolicy {
  private static numericBeforeUnit(text: string, unit: string): number {
    const unitIndex: number = text.indexOf(unit);
    if (unitIndex < 0) { return 0; }
    let digits: string = '';
    for (let index: number = unitIndex - 1; index >= 0 && unitIndex - index <= 6; index--) {
      const code: number = text.charCodeAt(index);
      if (code >= 48 && code <= 57) {
        digits = text.substring(index, index + 1) + digits;
      } else if (text.substring(index, index + 1).trim().length === 0 && digits.length === 0) {
        continue;
      } else if (digits.length > 0) {
        break;
      }
    }
    const value: number = Number(digits);
    return Number.isFinite(value) ? value : 0;
  }

  static requestedMinutes(text: string): number {
    const minuteValue: number = LearningDecisionPolicy.numericBeforeUnit(text, '分钟');
    if (minuteValue > 0) { return Math.min(240, minuteValue); }
    const shortMinuteValue: number = LearningDecisionPolicy.numericBeforeUnit(text, '分');
    if (shortMinuteValue > 0) { return Math.min(240, shortMinuteValue); }
    if (text.includes('半小时')) { return 30; }
    const hourValue: number = LearningDecisionPolicy.numericBeforeUnit(text, '小时');
    if (hourValue > 0) { return Math.min(240, hourValue * 60); }
    if (text.includes('一小时') || text.includes('一个小时')) { return 60; }
    if (text.includes('两小时') || text.includes('两个小时')) { return 120; }
    if (text.includes('一刻钟')) { return 15; }
    return 0;
  }

  // 每日目标是节奏参考，不是“达到后禁止继续规划”的硬上限。
  static planningBudget(requestText: string, dailyRemaining: number, dailyMinutes: number): number {
    const requested: number = LearningDecisionPolicy.requestedMinutes(requestText);
    if (requested >= 5) { return Math.min(240, requested); }
    if (dailyRemaining >= 5) { return Math.min(90, Math.max(25, Math.floor(dailyRemaining))); }
    const dailyTarget: number = Math.min(240, Math.max(15, dailyMinutes));
    return Math.min(60, Math.max(25, Math.round(dailyTarget * 0.75)));
  }

  static availableMinutes(dailyMinutes: number, studiedMinutes: number, energyState: string): number {
    const dailyBudget: number = Math.min(240, Math.max(15, dailyMinutes));
    const remaining: number = Math.max(0, dailyBudget - Math.max(0, studiedMinutes));
    if (energyState === '有点累') {
      return Math.min(remaining, Math.max(15, Math.round(dailyBudget * 0.6)));
    }
    return remaining;
  }

  static priorityEvidence(input: LearningContextInput): string[] {
    const evidence: string[] = [];
    const subject: string = TodayPlanService.generate(input.requestText, input.profile.subject, 5).subject;
    const bankWeak: BankLearningEvidence | undefined = BankLearningBridge.weakest(
      BankLearningBridge.relevant(LearningDecisionPolicy.buildRequest(input)));
    if (bankWeak !== undefined) { evidence.push(BankLearningBridge.reason(bankWeak)); }
    if (input.examDays >= 0 && input.examDays <= 3) {
      evidence.push(`考试仅剩${input.examDays}天，优先处理核心薄弱点`);
    } else if (input.examDays >= 0 && input.examDays < 999) {
      evidence.push(`距离考试${input.examDays}天，按节奏推进复习`);
    }
    const unfinishedCount: number = input.tasks.filter((task: StudyTask) => !task.completed).length;
    if (unfinishedCount > 0) {
      evidence.push(`仍有${unfinishedCount}项未完成任务，避免重复规划`);
    }
    if (input.metrics.quizAttemptCount > 0 && input.metrics.quizCorrectCount < input.metrics.quizAttemptCount) {
      const latestWrong: QuizAttempt | undefined = input.quizAttempts.slice().reverse()
        .find((attempt: QuizAttempt) => !attempt.correct && attempt.subject === subject);
      if (latestWrong !== undefined) { evidence.push(latestWrong.knowledgePoint !== undefined ?
        `小测暴露“${latestWrong.knowledgePoint}”薄弱点，下一轮优先针对复习` :
        '小测出现错误，下一轮优先安排针对复习'); }
    }
    const weakest: KnowledgeMastery | undefined = input.knowledgeMastery
      .filter((item: KnowledgeMastery) => item.subject === subject)
      .sort((left: KnowledgeMastery, right: KnowledgeMastery) => left.score - right.score)[0];
    if (weakest !== undefined && weakest.score < 60) {
      evidence.push(`“${weakest.knowledgePoint}”掌握度${weakest.score}%，优先安排巩固`);
    }
    if (input.energyState === '有点累') {
      evidence.push('当前精力偏低，已缩短单个专注块');
    }
    if (input.scheduleReady) {
      evidence.push('已读取今日课表，执行时避开上课时段');
    }
    return evidence;
  }

  static buildRequest(input: LearningContextInput): AgentPlanRequest {
    const dailyTargetRemaining: number = input.remainingBudget ?? LearningDecisionPolicy.availableMinutes(
      input.profile.dailyMinutes,
      input.metrics.todayFocusMinutes,
      input.energyState
    );
    const confirmed: number | undefined = input.confirmedAvailableMinutes;
    const availableMinutes: number | undefined = confirmed !== undefined && Number.isFinite(confirmed) ?
      Math.min(240, Math.max(0, Math.floor(confirmed))) : undefined;
    const recentQuizFeedback: QuizFeedbackPayload[] = input.quizAttempts.slice(-5)
      .map((attempt: QuizAttempt) => {
        const feedback: QuizFeedbackPayload = {
          questionId: attempt.questionId,
          subject: attempt.subject,
          knowledgePoint: attempt.knowledgePoint ?? '未标注知识点',
          correct: attempt.correct,
          attemptedAt: attempt.attemptedAt
        };
        return feedback;
      });
    const context: AgentContextPayload = {
      academicGoals: input.academicGoals ?? [],
      bankTopicId: input.bankTopicId,
      bankAppendMode: input.bankAppendMode === true,
      bankEvidence: input.bankEvidence ?? [],
      date: input.date,
      examDays: input.examDays,
      energyState: input.energyState,
      availableMinutesToday: availableMinutes,
      todayStudyOverride: input.todayStudyOverride,
      localDailyPlanTaskIds: input.localDailyPlanTaskIds,
      localDailyPlanMinutes: input.localDailyPlanMinutes,
      eligibleTaskIds: input.eligibleTaskIds,
      protectedTaskId: input.protectedTaskId,
      protectedStage: input.protectedStage,
      recentFocusRecords: input.recentFocusRecords,
      dailyTargetRemainingMinutes: Math.max(0, Math.floor(input.dailyTargetRemainingMinutes ?? dailyTargetRemaining)),
      appendMode: input.appendMode === true,
      scheduleReady: input.scheduleReady,
      scheduleItems: input.scheduleItems,
      unfinishedTasks: input.tasks.filter((task: StudyTask) => !task.completed),
      todayFocusMinutes: input.metrics.todayFocusMinutes,
      todayFocusSessionCount: input.metrics.todayFocusSessionCount,
      quizAttemptCount: input.metrics.quizAttemptCount,
      quizCorrectCount: input.metrics.quizCorrectCount,
      recentQuizFeedback: recentQuizFeedback,
      knowledgeMastery: input.knowledgeMastery
    };
    return {
      requestText: input.requestText,
      profile: input.profile,
      context: context
    };
  }
}
