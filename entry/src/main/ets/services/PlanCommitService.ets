import { AgentGeneratedTask, AgentPlan, PlanCommitResult } from '../models/AgentModels';
import { AcademicGoal, StudyTask } from '../models/StudyModels';
import { StudyDataCenter } from './StudyDataCenter';
import { BankPlanBudget } from './BankPlanBudget';

export class PlanCommitService {
  static append(existingTasks: StudyTask[], plan: AgentPlan, availableMinutes: number): PlanCommitResult {
    const existingTitles: string[] = existingTasks.filter((task: StudyTask) => !task.completed)
      .map((task: StudyTask) => task.title);
    const generated: PlanCommitResult = PlanCommitService.commit(plan);
    const added: StudyTask[] = generated.tasks.filter((task: StudyTask) => {
      if (existingTitles.includes(task.title)) { return false; }
      existingTitles.push(task.title); return true;
    });
    const addedMinutes: number = added.reduce((total: number, task: StudyTask) => total + task.minutes, 0);
    if (addedMinutes > Math.max(0, availableMinutes)) {
      throw new Error('剩余时间已变化，请让星球重新压缩计划');
    }
    const tasks: StudyTask[] = existingTasks.concat(added);
    if (tasks.length === 0) { throw new Error('没有可以加入的任务'); }
    const firstPending: number = tasks.findIndex((task: StudyTask) => !task.completed);
    const index: number = firstPending < 0 ? 0 : firstPending;
    return { subject: generated.subject, tasks: tasks, currentTaskIndex: index,
      firstFocusMinutes: tasks[index].minutes };
  }

  // 兼容旧调用签名；长期目标只提供上下文，不再绑定或替换 milestone 任务。
  static reconcile(existing: StudyTask[], plan: AgentPlan, _goal?: AcademicGoal, protectedTaskId?: string): PlanCommitResult {
    const kept: StudyTask[] = existing.filter((task: StudyTask) => {
      if ((protectedTaskId !== undefined && task.id === protectedTaskId) || task.completed || (task.focusedAt ?? 0) > 0 || task.outcome !== undefined ||
        task.source === 'manual' || task.source === 'video-library' || task.source === 'question-bank') { return true; }
      return task.subject !== plan.detectedSubject;
    });
    const generated: PlanCommitResult = PlanCommitService.commit(plan);
    const added: StudyTask[] = generated.tasks.filter((task: StudyTask) =>
      !kept.some((item: StudyTask) => !item.completed && item.subject === task.subject && item.title === task.title));
    const tasks: StudyTask[] = kept.concat(added);
    if (tasks.length === 0) { throw new Error('没有可保存的任务'); }
    const index: number = added.length > 0 ? kept.length : Math.max(0, tasks.findIndex((task: StudyTask) => !task.completed));
    return { subject: generated.subject, tasks: tasks, currentTaskIndex: index, firstFocusMinutes: tasks[index].minutes };
  }
  static appendBankPlan(existingTasks: StudyTask[], plan: AgentPlan, remainingMinutes: number): PlanCommitResult {
    const pendingTitles: string[] = existingTasks.filter((task: StudyTask) => !task.completed)
      .map((task: StudyTask) => task.title);
    const createdAt: number = Date.now();
    const added: StudyTask[] = [];
    plan.tasks.forEach((task: AgentGeneratedTask, index: number) => {
      if (pendingTitles.includes(task.title)) { return; }
      pendingTitles.push(task.title);
      added.push({ id: `bank-agent-${createdAt}-${index}`, title: task.title, subject: task.subject,
        minutes: task.minutes, completed: false,
        source: (task.subject === '线性代数' && /矩阵|秩/.test(task.title)) ||
          (task.subject === '高等数学' && /导数|求导|链式/.test(task.title)) ? 'question-bank' : plan.source,
        createdAt: createdAt, completedAt: 0 });
    });
    const tasks: StudyTask[] = existingTasks.concat(added);
    const available: number = BankPlanBudget.available(remainingMinutes, existingTasks);
    if (added.some((task: StudyTask) => !Number.isFinite(task.minutes) || task.minutes < 5) ||
      added.reduce((sum: number, task: StudyTask) => sum + task.minutes, 0) > available) {
      throw new Error('原待办或剩余时间已变化，补学方案超出可追加时间，请重新生成；原任务未更改');
    }
    if (tasks.length === 0) { throw new Error('没有可以同步的补学任务'); }
    const index: number = added.length > 0 ? existingTasks.length : Math.max(0,
      tasks.findIndex((task: StudyTask) => !task.completed));
    return { subject: plan.detectedSubject, tasks: tasks, currentTaskIndex: index, firstFocusMinutes: tasks[index].minutes };
  }
  static commit(plan: AgentPlan): PlanCommitResult {
    if (plan.tasks.length === 0) {
      throw new Error('没有可以同步的任务');
    }
    const createdAt: number = Date.now();
    const acceptedTasks: StudyTask[] = plan.tasks.map((task: AgentGeneratedTask, index: number) => {
      const acceptedTask: StudyTask = {
        id: `decision-${createdAt}-${index}`,
        title: task.title,
        subject: task.subject,
        minutes: task.minutes,
        completed: false,
        source: plan.source,
        createdAt: createdAt,
        completedAt: 0
      };
      return acceptedTask;
    });
    return {
      subject: plan.detectedSubject.length > 0 ? plan.detectedSubject : acceptedTasks[0].subject,
      tasks: StudyDataCenter.normalizeTasks(acceptedTasks),
      firstFocusMinutes: acceptedTasks[0].minutes,
      currentTaskIndex: 0
    };
  }

  static mergeAfterFeedback(existingTasks: StudyTask[], plan: AgentPlan): PlanCommitResult {
    if (plan.tasks.length === 0) {
      throw new Error('没有可以同步的调整任务');
    }
    const completedTasks: StudyTask[] = existingTasks.filter((task: StudyTask) => task.completed);
    const createdAt: number = Date.now();
    const completedTitles: string[] = completedTasks.map((task: StudyTask) => task.title);
    const uniquePlanTasks: AgentGeneratedTask[] = plan.tasks
      .filter((task: AgentGeneratedTask) => !completedTitles.includes(task.title));
    const futurePlanTasks: AgentGeneratedTask[] = uniquePlanTasks.length > 0 ? uniquePlanTasks : plan.tasks;
    const adjustedTasks: StudyTask[] = futurePlanTasks
      .map((task: AgentGeneratedTask, index: number) => {
        const adjustedTask: StudyTask = {
          id: `feedback-decision-${createdAt}-${index}`,
          title: task.title,
          subject: task.subject,
          minutes: task.minutes,
          completed: false,
          source: plan.source,
          createdAt: createdAt,
          completedAt: 0
        };
        return adjustedTask;
      });
    const mergedTasks: StudyTask[] = StudyDataCenter.normalizeTasks(completedTasks.concat(adjustedTasks));
    const currentTaskIndex: number = Math.max(0,
      mergedTasks.findIndex((task: StudyTask) => !task.completed));
    const nextTask: StudyTask = mergedTasks[currentTaskIndex] ?? completedTasks[0];
    return {
      subject: plan.detectedSubject.length > 0 ? plan.detectedSubject : nextTask.subject,
      tasks: mergedTasks,
      firstFocusMinutes: nextTask.minutes,
      currentTaskIndex: currentTaskIndex
    };
  }
}
