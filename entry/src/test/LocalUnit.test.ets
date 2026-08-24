import { describe, expect, it } from '@ohos/hypium';
import { FocusClock } from '../main/ets/services/FocusClock';
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
  });
}
