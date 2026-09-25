import { StudyStateSnapshot, StudyTask, TodayStudyOverride } from '../models/StudyModels';

export class TodayStudyOverrideService {
  static date(now: number = Date.now()): string {
    return new Date(now + 8 * 3600000).toISOString().substring(0, 10);
  }

  static active(snapshot: StudyStateSnapshot, now: number = Date.now()): TodayStudyOverride | undefined {
    const override: TodayStudyOverride | undefined = snapshot.todayStudyOverride;
    return override?.date === TodayStudyOverrideService.date(now) ? override : undefined;
  }

  static eligibleTask(task: StudyTask, override?: TodayStudyOverride): boolean {
    if (task.id === undefined || task.completed) { return false; }
    if ((override?.skippedTaskIds ?? []).includes(task.id)) { return false; }
    return TodayStudyOverrideService.currentTask(task, override);
  }

  static currentTask(task: StudyTask, override?: TodayStudyOverride): boolean {
    return task.source !== 'today-temporary' || (override?.temporaryTaskIds ?? []).includes(task.id ?? '');
  }
}
