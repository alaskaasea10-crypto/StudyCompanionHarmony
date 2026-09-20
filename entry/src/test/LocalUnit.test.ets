import { describe, expect, it } from '@ohos/hypium';
import {
  createDefaultSquadMembers,
  createDemoSchedule,
  createDemoTasks,
  FocusRecord,
  KnowledgeMastery,
  QuizAttempt,
  StudyMetrics,
  SquadMember,
  StudyTask
} from '../main/ets/models/StudyModels';
import { AgentPlan, AgentUsage, QuizFeedbackResult } from '../main/ets/models/AgentModels';
import { FocusClock } from '../main/ets/services/FocusClock';
import { LearningDecisionPolicy } from '../main/ets/services/LearningDecisionPolicy';
import { LearningFeedbackService } from '../main/ets/services/LearningFeedbackService';
import { PlanValidator } from '../main/ets/services/PlanValidator';
import { PlanCommitService } from '../main/ets/services/PlanCommitService';
import { RecommendationResult, RecommendationService } from '../main/ets/services/RecommendationService';
import { StudyDataCenter } from '../main/ets/services/StudyDataCenter';
import { TodayPlanResult, TodayPlanService } from '../main/ets/services/TodayPlanService';
import { QuizService } from '../main/ets/services/QuizService';
import { KnowledgeMasteryService } from '../main/ets/services/KnowledgeMasteryService';
import { SquadService } from '../main/ets/services/SquadService';

export default function localUnitTest() {
  describe('StudyFoundation', () => {
    it('restoresRunningFocusFromTimestamps', 0, () => {
      const remaining: number = FocusClock.remainingSeconds(1500, 120, 100000, 160000);
      expect(remaining).assertEqual(1320);
    });

    it('doesNotReturnNegativeRemainingTime', 0, () => {
      const remaining: number = FocusClock.remainingSeconds(60, 50, 100000, 120000);
      expect(remaining).assertEqual(0);
    });

    it('doesNotCreditAnEmptyFocusSession', 0, () => {
      expect(FocusClock.completedMinutes(0)).assertEqual(0);
      expect(FocusClock.completedMinutes(59)).assertEqual(0);
      expect(FocusClock.completedMinutes(60)).assertEqual(1);
    });

    it('reducesPlanWhenStudentIsTired', 0, () => {
      const result: TodayPlanResult = TodayPlanService.generate('今晚有点累，想复习高数', '线性代数', 60);
      expect(result.subject).assertEqual('高等数学');
      expect(result.firstFocusMinutes).assertEqual(15);
      expect(result.tasks.length).assertEqual(4);
    });

    it('recommendsNextIncompleteTaskWithScheduleEvidence', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('线性代数', 60);
      tasks[0].completed = true;
      const result: RecommendationResult = RecommendationService.recommend({
        goal: '期末复习',
        learningStyle: '练习驱动',
        energyState: '一般',
        subject: '线性代数',
        examDays: 14,
        scheduleReady: true,
        scheduleItems: createDemoSchedule(),
        tasks: tasks,
        now: new Date('2026-08-24T07:00:00+08:00').getTime()
      });
      expect(result.taskIndex).assertEqual(1);
      expect(result.timelineTime).assertEqual('08:00');
      expect(result.allDone).assertFalse();
    });

    it('returnsRestStateWhenAllTasksAreComplete', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('线性代数', 60);
      tasks.forEach((task: StudyTask) => {
        task.completed = true;
      });
      const result: RecommendationResult = RecommendationService.recommend({
        goal: '期末复习',
        learningStyle: '练习驱动',
        energyState: '一般',
        subject: '线性代数',
        examDays: 14,
        scheduleReady: true,
        scheduleItems: createDemoSchedule(),
        tasks: tasks,
        now: new Date('2026-08-24T20:00:00+08:00').getTime()
      });
      expect(result.allDone).assertTrue();
      expect(result.minutes).assertEqual(0);
    });

    it('aggregatesTasksFocusAndQuizFromOneDay', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('线性代数', 60);
      tasks[0].completed = true;
      const focusRecords: FocusRecord[] = [{
        id: 'focus-test',
        taskId: tasks[0].id ?? 'task-test',
        taskTitle: tasks[0].title,
        subject: tasks[0].subject,
        plannedMinutes: 25,
        elapsedSeconds: 1500,
        completedAt: 1000,
        dayKey: '2026-08-28'
      }];
      const quizAttempts: QuizAttempt[] = [{
        id: 'quiz-test',
        questionId: 'matrix-invertible-01',
        subject: '线性代数',
        answer: 'B',
        correct: true,
        attemptedAt: 1000,
        dayKey: '2026-08-28'
      }];
      const metrics: StudyMetrics = StudyDataCenter.calculateMetrics(
        tasks,
        focusRecords,
        quizAttempts,
        '2026-08-28',
        0
      );
      expect(metrics.completedTaskCount).assertEqual(1);
      expect(metrics.planProgress).assertEqual(25);
      expect(metrics.todayFocusMinutes).assertEqual(25);
      expect(metrics.todayFocusSessionCount).assertEqual(1);
      expect(metrics.quizCorrectCount).assertEqual(1);
    });

    it('keepsInterruptedFocusTimeWithoutCountingACompletedRound', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('线性代数', 60);
      const focusRecords: FocusRecord[] = [{
        id: 'focus-interrupted',
        taskId: tasks[0].id ?? 'task-test',
        taskTitle: tasks[0].title,
        subject: tasks[0].subject,
        plannedMinutes: 25,
        elapsedSeconds: 620,
        completedAt: 1000,
        dayKey: '2026-09-01',
        completed: false
      }];
      const metrics: StudyMetrics = StudyDataCenter.calculateMetrics(
        tasks,
        focusRecords,
        [],
        '2026-09-01',
        0
      );
      expect(metrics.todayFocusMinutes).assertEqual(10);
      expect(metrics.todayFocusSessionCount).assertEqual(0);
    });

    it('calculatesOneSharedBudgetFromFocusAndEnergy', 0, () => {
      const normalBudget: number = LearningDecisionPolicy.availableMinutes(60, 20, '一般');
      const tiredBudget: number = LearningDecisionPolicy.availableMinutes(60, 20, '有点累');
      const exhaustedBudget: number = LearningDecisionPolicy.availableMinutes(60, 60, '一般');
      expect(normalBudget).assertEqual(40);
      expect(tiredBudget).assertEqual(36);
      expect(exhaustedBudget).assertEqual(0);
    });

    it('keepsPlanningAfterDailyTargetAndHonorsRequestedTime', 0, () => {
      expect(LearningDecisionPolicy.planningBudget('今晚用40分钟复习高数', 0, 60)).assertEqual(40);
      expect(LearningDecisionPolicy.planningBudget('帮我安排学习', 0, 60)).assertEqual(45);
      expect(LearningDecisionPolicy.requestedMinutes('我有半小时')).assertEqual(30);
    });

    it('validatesModelPlanAgainstSharedBudget', 0, () => {
      const usage: AgentUsage = { promptTokens: 0, completionTokens: 0, totalTokens: 0 };
      const plan: AgentPlan = {
        summary: '复习并完成小测',
        detectedSubject: '线性代数',
        recommendationReasons: ['考试临近'],
        tasks: [
          {
            title: '复习矩阵运算',
            subject: '线性代数',
            type: 'review',
            minutes: 30,
            priority: 1,
            reason: '薄弱点'
          },
          {
            title: '完成矩阵小测',
            subject: '线性代数',
            type: 'quiz',
            minutes: 30,
            priority: 2,
            reason: '即时反馈'
          }
        ],
        totalMinutes: 60,
        source: 'openpangu',
        model: 'openpangu-2.0-flash',
        usage: usage
      };
      const validated: AgentPlan = PlanValidator.validate(plan, 40);
      expect(validated.totalMinutes).assertEqual(40);
      expect(validated.tasks[1].minutes).assertEqual(10);
    });

    it('turnsWrongQuizIntoOneFeedbackTask', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('线性代数', 60);
      const first: QuizFeedbackResult = LearningFeedbackService.applyQuizResult(
        tasks, '线性代数', false, '可逆矩阵与秩');
      const second: QuizFeedbackResult = LearningFeedbackService.applyQuizResult(
        first.tasks, '线性代数', false, '可逆矩阵与秩');
      expect(first.tasks.length).assertEqual(tasks.length + 1);
      expect(first.tasks[0].title).assertContain('针对复习');
      expect(second.tasks.length).assertEqual(first.tasks.length);
      expect(second.message).assertContain('无需重复添加');
    });

    it('selectsQuizFromFocusedSubject', 0, () => {
      const englishQuestion = QuizService.questionFor('英语四六级', '速记30个高频单词');
      const algebraQuestion = QuizService.questionFor('线性代数', '回顾矩阵运算');
      expect(englishQuestion.knowledgePoint).assertEqual('高频词汇语境');
      expect(englishQuestion.correctAnswer).assertEqual('A');
      expect(algebraQuestion.knowledgePoint).assertEqual('可逆矩阵与秩');
    });

    it('updatesKnowledgeMasteryFromQuizFeedback', 0, () => {
      const first: KnowledgeMastery[] = KnowledgeMasteryService.update(
        [], '线性代数', '可逆矩阵与秩', false, 1000);
      const second: KnowledgeMastery[] = KnowledgeMasteryService.update(
        first, '线性代数', '可逆矩阵与秩', true, 2000);
      expect(first[0].score).assertEqual(28);
      expect(first[0].status).assertEqual('需要复习');
      expect(second[0].score).assertEqual(46);
      expect(second[0].attemptCount).assertEqual(2);
      expect(second[0].correctCount).assertEqual(1);
    });

    it('keepsCompletedTasksWhenAcceptingFeedbackPlan', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('英语四六级', 60);
      tasks[0].completed = true;
      const usage: AgentUsage = { promptTokens: 0, completionTokens: 0, totalTokens: 0 };
      const plan: AgentPlan = {
        summary: '根据小测调整',
        detectedSubject: '英语四六级',
        recommendationReasons: ['小测反馈'],
        tasks: [{
          title: '完成词汇语境练习', subject: '英语四六级', type: 'practice', minutes: 20,
          priority: 1, reason: '巩固薄弱点'
        }],
        totalMinutes: 20,
        source: 'openpangu',
        model: 'openpangu-2.0-flash',
        usage: usage
      };
      const merged = PlanCommitService.mergeAfterFeedback(tasks, plan);
      expect(merged.tasks.length).assertEqual(2);
      expect(merged.tasks[0].completed).assertTrue();
      expect(merged.tasks[1].completed).assertFalse();
      expect(merged.currentTaskIndex).assertEqual(1);
    });

    it('appendsFloatingAgentPlanWithoutReplacingExistingTasks', 0, () => {
      const tasks: StudyTask[] = createDemoTasks('英语四六级', 60);
      const originalFirstId: string = tasks[0].id ?? '';
      const usage: AgentUsage = { promptTokens: 0, completionTokens: 0, totalTokens: 0 };
      const plan: AgentPlan = {
        summary: '追加一项复习', detectedSubject: '英语四六级', recommendationReasons: ['用户确认'],
        tasks: [{ title: '复盘阅读错题', subject: '英语四六级', type: 'review', minutes: 15,
          priority: 1, reason: '巩固错题' }],
        totalMinutes: 15, source: 'openpangu', model: 'openpangu-2.0-flash', usage: usage
      };
      const appended = PlanCommitService.append(tasks, plan, 20);
      expect(appended.tasks.length).assertEqual(tasks.length + 1);
      expect(appended.tasks[0].id).assertEqual(originalFirstId);
      expect(appended.tasks[appended.tasks.length - 1].title).assertEqual('复盘阅读错题');
    });

    it('keepsSquadMembersAndSyncsTheCurrentLearner', 0, () => {
      const members: SquadMember[] = createDefaultSquadMembers('小林');
      const synced: SquadMember[] = SquadService.syncSelf(
        members, '乌萨奇', 36, true, '复习矩阵乘法');
      expect(synced.length).assertEqual(3);
      expect(synced[0].name).assertEqual('乌萨奇');
      expect(synced[0].status).assertEqual('专注中');
      expect(synced[0].todayMinutes).assertEqual(36);
      expect(SquadService.focusingCount(synced)).assertEqual(2);
    });

    it('recordsLowInterruptionEncouragement', 0, () => {
      const members: SquadMember[] = createDefaultSquadMembers('小林');
      const encouraged: SquadMember[] = SquadService.encourage(members, 'demo-xiaoyu');
      expect(encouraged[1].encouragementCount).assertEqual(3);
      expect(encouraged[0].encouragementCount).assertEqual(0);
      expect(SquadService.inviteCode('小林', 1000000)).assertContain('LIGHT-');
    });
  });
}
