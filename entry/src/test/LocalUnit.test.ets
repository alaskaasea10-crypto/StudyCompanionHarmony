import { describe, expect, it } from '@ohos/hypium';
import {
  createDemoSchedule,
  createDemoTasks,
  FocusRecord,
  QuizAttempt,
  StudyMetrics,
  StudyTask
} from '../main/ets/models/StudyModels';
import { FocusClock } from '../main/ets/services/FocusClock';
import { RecommendationResult, RecommendationService } from '../main/ets/services/RecommendationService';
import { StudyDataCenter } from '../main/ets/services/StudyDataCenter';
import { TodayPlanResult, TodayPlanService } from '../main/ets/services/TodayPlanService';

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
  });
}
