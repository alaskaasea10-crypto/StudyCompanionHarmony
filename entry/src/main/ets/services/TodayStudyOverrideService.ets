import { StudyStateSnapshot, StudyTask, TodayStudyOverride } from '../models/StudyModels';
import { canonicalSubjectName, subjectAliases } from '../utils/SubjectDisplayName';

export class TodayStudyOverrideService {
  static subjectsIn(text: string): string[] {
    const aliases: string[] = subjectAliases();
    const result: string[] = [];
    aliases.forEach((alias: string) => {
      const name: string = TodayStudyOverrideService.subjectName(alias);
      if (text.toLowerCase().includes(alias.toLowerCase()) && !result.includes(name)) { result.push(name); }
    });
    return result;
  }

  static consistentSubject(task: StudyTask): boolean {
    const names: string[] = TodayStudyOverrideService.subjectsIn(task.title);
    return names.length === 0 || names.every((name: string) => name ===
      TodayStudyOverrideService.subjectName(task.subject));
  }

  static realTask(task: StudyTask): boolean {
    return !!task.id && task.id !== 'safe-fallback-task' && task.source !== 'recovery' &&
      !task.id.startsWith('demo-') && !task.id.startsWith('placeholder-');
  }
  static subjectName(subject: string): string {
    return canonicalSubjectName(subject);
  }

  static matchesIntent(task: StudyTask, override?: TodayStudyOverride): boolean {
    const subject: string = override?.intent?.subject ?? override?.preferredSubject ?? '';
    return subject.length === 0 || TodayStudyOverrideService.subjectName(task.subject) ===
      TodayStudyOverrideService.subjectName(subject);
  }
  static date(now: number = Date.now()): string {
    return new Date(now + 8 * 3600000).toISOString().substring(0, 10);
  }

  static active(snapshot: StudyStateSnapshot, now: number = Date.now()): TodayStudyOverride | undefined {
    const override: TodayStudyOverride | undefined = snapshot.todayStudyOverride;
    return override?.date === TodayStudyOverrideService.date(now) ? override : undefined;
  }

  static eligibleTask(task: StudyTask, override?: TodayStudyOverride): boolean {
    if (!TodayStudyOverrideService.realTask(task) || task.completed ||
      !TodayStudyOverrideService.consistentSubject(task)) { return false; }
    if ((override?.skippedTaskIds ?? []).includes(task.id ?? '')) { return false; }
    return TodayStudyOverrideService.currentTask(task, override);
  }

  static currentTask(task: StudyTask, override?: TodayStudyOverride): boolean {
    const temporary: boolean = task.source === 'today-temporary' || task.source === 'today-agent';
    if (!temporary) { return true; }
    return (override?.temporaryTaskIds ?? []).includes(task.id ?? '') &&
      (task.createdAt === undefined || TodayStudyOverrideService.date(task.createdAt) === override?.date);
  }

  // 首页、学习页和“调整今天安排”共享同一个真实任务全集，不按 source 另建白名单。
  static activeTaskIndices(tasks: StudyTask[], override?: TodayStudyOverride, today?: string): number[] {
    const active: TodayStudyOverride | undefined = override !== undefined &&
      (today === undefined || override.date === today) ? override : undefined;
    const result: number[] = [];
    tasks.forEach((task: StudyTask, index: number) => {
      if (TodayStudyOverrideService.realTask(task) && !task.completed &&
        TodayStudyOverrideService.consistentSubject(task) && TodayStudyOverrideService.currentTask(task, active)) {
        result.push(index);
      }
    });
    return result;
  }

  static visibleTasks(tasks: StudyTask[], override?: TodayStudyOverride, today?: string): StudyTask[] {
    const active: TodayStudyOverride | undefined = override !== undefined &&
      (today === undefined || override.date === today) ? override : undefined;
    return tasks.filter((task: StudyTask) => TodayStudyOverrideService.realTask(task) &&
      TodayStudyOverrideService.consistentSubject(task) && TodayStudyOverrideService.currentTask(task, active));
  }
}
