import { SmallPlanetSemanticAllocation, SmallPlanetUnderstanding } from '../models/AgentModels';
import { StudyStateSnapshot, StudyTask, TodayStudyOverride } from '../models/StudyModels';
import { TodayStudyOverrideService } from './TodayStudyOverrideService';

export class SmallPlanetSemanticValidator {
  static validate(value: SmallPlanetUnderstanding | undefined, snapshot: StudyStateSnapshot,
    now: number = Date.now()): SmallPlanetUnderstanding {
    if (value === undefined || !['advice', 'explain', 'clarify'].includes(value.mode) ||
      value.executionRequested || !Array.isArray(value.subjects) || !Array.isArray(value.allocation)) {
      throw new Error('小星球没有返回可安全使用的理解结果');
    }
    const active: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const skipped: string[] = active?.skippedTaskIds ?? [];
    const tasks: StudyTask[] = (snapshot.tasks ?? []).filter((task: StudyTask) =>
      TodayStudyOverrideService.realTask(task) && TodayStudyOverrideService.consistentSubject(task) &&
      TodayStudyOverrideService.currentTask(task, active) && !task.completed &&
      !skipped.includes(task.id ?? '') && !(snapshot.deletedTaskIds ?? []).includes(task.id ?? ''));
    const knownSubjects: string[] = tasks.map((task: StudyTask) => TodayStudyOverrideService.subjectName(task.subject));
    value.subjects.forEach(item => {
      const subject: string = TodayStudyOverrideService.subjectName(item.subject);
      if (!knownSubjects.includes(subject)) { throw new Error('建议引用了当前没有真实任务的科目'); }
      item.subject = subject;
    });
    const ids: string[] = [];
    let total: number = 0;
    value.allocation.forEach((item: SmallPlanetSemanticAllocation) => {
      const task: StudyTask | undefined = tasks.find((candidate: StudyTask) => candidate.id === item.taskId);
      if (task === undefined || ids.includes(item.taskId) || !Number.isFinite(item.minutes) ||
        item.minutes < 5 || item.minutes > Math.min(45, task.minutes)) {
        throw new Error('建议引用了无效任务或时长');
      }
      ids.push(item.taskId); total += item.minutes;
    });
    if (value.timeBudgetMinutes !== undefined && (!Number.isFinite(value.timeBudgetMinutes) ||
      value.timeBudgetMinutes < 5 || value.timeBudgetMinutes > 240 || total > value.timeBudgetMinutes)) {
      throw new Error('建议超出用户表达的时间范围');
    }
    if (value.allocation.length > 0 && !value.confirmationRequired) {
      throw new Error('复杂建议必须先由用户确认');
    }
    return value;
  }
}
