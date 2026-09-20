import { StudyTask } from '../models/StudyModels';

export class BankPlanBudget {
  static available(remainingMinutes: number, tasks: StudyTask[]): number {
    if (!Number.isFinite(remainingMinutes)) { throw new Error('剩余时间无效，请重新生成'); }
    let reserved: number = 0;
    tasks.filter((task: StudyTask) => !task.completed).forEach((task: StudyTask) => {
      if (!Number.isFinite(task.minutes) || task.minutes < 0) { throw new Error('待办时长无效，请先检查原计划'); }
      reserved += task.minutes;
    });
    // 正在执行但尚未记账的待办也预留完整时长，避免把专注中的时间重复分配。
    return Math.max(0, Math.floor(remainingMinutes - reserved));
  }
}
