import { describe, expect, it } from '@ohos/hypium';
import { createDemoSchedule, createDemoTasks, StudyTask } from '../main/ets/models/StudyModels';
import { FocusClock } from '../main/ets/services/FocusClock';
import { RecommendationResult, RecommendationService } from '../main/ets/services/RecommendationService';
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
  });
}
