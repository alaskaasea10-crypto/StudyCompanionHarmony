import { AgentGeneratedTask, AgentPlan, AgentPlanRequest, AgentUsage } from '../models/AgentModels';
import { StudyTask, TodayStudyOverride } from '../models/StudyModels';

export class PlanValidator {
  // 今日模型计划只可引用当前真实待办；旧的生成任务校验保留给独立补学流程。
  static validateExisting(plan: AgentPlan, request: AgentPlanRequest): AgentPlan {
    const context = request.context;
    const override: TodayStudyOverride | undefined = context.todayStudyOverride?.date === context.date ?
      context.todayStudyOverride : undefined;
    const existing: StudyTask[] = context.unfinishedTasks.filter((task: StudyTask) =>
      task.id !== undefined && !task.completed &&
      (task.id === context.protectedTaskId || !(override?.skippedTaskIds ?? []).includes(task.id)) &&
      (task.id === context.protectedTaskId || (context.eligibleTaskIds ?? []).includes(task.id)) &&
      (task.source !== 'today-temporary' || (override?.temporaryTaskIds ?? []).includes(task.id)));
    const raw: AgentGeneratedTask[] = plan.tasks.slice().sort((left: AgentGeneratedTask, right: AgentGeneratedTask) =>
      left.priority - right.priority);
    if (raw.length < 1 || raw.length > 4) { throw new Error('计划阶段数量不合理，请重新安排'); }
    const protectedStage: boolean = context.protectedStage === 'resume' || context.protectedStage === 'verify';
    const confirmed: number | undefined = protectedStage ? undefined : context.availableMinutesToday;
    if (confirmed === undefined && raw.length > 1) {
      throw new Error('未确认今日可用时间时，只能建议眼前一项');
    }
    const result: AgentGeneratedTask[] = [];
    const seen: string[] = [];
    let total: number = 0;
    for (const item of raw) {
      const id: string = item.taskId?.trim() ?? '';
      const source: StudyTask | undefined = existing.find((task: StudyTask) => task.id === id);
      if (id.length === 0 || source === undefined || seen.includes(id)) {
        throw new Error('模型计划引用了不存在、已完成或已暂缓的任务');
      }
      if (source.outcome === 'focused' || source.outcome === 'submitted') {
        if (id !== context.protectedTaskId) { throw new Error('待反馈任务不能被重新安排'); }
      }
      if (source.title !== item.title || source.subject !== item.subject) {
        throw new Error('模型计划修改了已有任务内容，请重新安排');
      }
      const protectedFeedback: boolean = context.protectedStage === 'verify' && id === context.protectedTaskId;
      const minutes: number = protectedFeedback ? 0 : item.minutes;
      const protectedResume: boolean = context.protectedStage === 'resume' && id === context.protectedTaskId;
      const resumeMinutes: number | undefined = context.localDailyPlanMinutes?.[0];
      if (!Number.isFinite(minutes) || (!protectedFeedback && (minutes < 5 || minutes > 45 ||
        minutes > source.minutes || (protectedResume && resumeMinutes !== undefined && minutes > resumeMinutes)))) {
        throw new Error('模型计划的学习时长与真实任务不符');
      }
      total += minutes;
      if (confirmed !== undefined && total > confirmed) { throw new Error('模型计划超出已确认的可用时间'); }
      seen.push(id);
      result.push({ taskId: id, title: source.title, subject: source.subject, type: item.type,
        minutes: minutes, priority: result.length + 1, reason: '这是已保存且尚未完成的任务' });
    }
    if (context.protectedTaskId !== undefined && result[0].taskId !== context.protectedTaskId) {
      throw new Error('正在专注或等待反馈的任务必须先保留');
    }
    // Model prose is not evidence: keep its valid ordering/time suggestion, but show only verifiable local wording.
    return { summary: `今天先推进${result.length}项已有学习任务`, detectedSubject: plan.detectedSubject,
      recommendationReasons: [], tasks: result,
      totalMinutes: total, source: plan.source, model: plan.model, usage: plan.usage,
      agentMode: plan.agentMode, toolCalls: plan.toolCalls, rounds: plan.rounds };
  }

  static validate(plan: AgentPlan, availableMinutes: number): AgentPlan {
    const budget: number = Math.min(240, Math.max(5, availableMinutes));
    const tasks: AgentGeneratedTask[] = [];
    const titles: string[] = [];
    let usedMinutes: number = 0;
    for (let index: number = 0; index < plan.tasks.length && tasks.length < 4; index++) {
      const sourceTask: AgentGeneratedTask = plan.tasks[index];
      const title: string = sourceTask.title.trim().slice(0, 36);
      if (title.length === 0 || titles.includes(title) || budget - usedMinutes < 5) {
        continue;
      }
      const minutes: number = Math.min(45, Math.max(5, sourceTask.minutes), budget - usedMinutes);
      const task: AgentGeneratedTask = {
        title: title,
        subject: sourceTask.subject.trim().length > 0 ? sourceTask.subject.trim().slice(0, 20) : '学习任务',
        type: sourceTask.type.trim().length > 0 ? sourceTask.type : 'practice',
        minutes: minutes,
        priority: Math.min(4, Math.max(1, sourceTask.priority)),
        reason: sourceTask.reason.trim().length > 0 ? sourceTask.reason.trim().slice(0, 60) :
          '结合学习画像与今天可用时间安排'
      };
      tasks.push(task);
      titles.push(title);
      usedMinutes += minutes;
    }
    tasks.sort((left: AgentGeneratedTask, right: AgentGeneratedTask) => left.priority - right.priority);
    if (tasks.length === 0) {
      throw new Error('生成结果中没有可执行任务');
    }
    const usage: AgentUsage = plan.usage ?? {
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0
    };
    return {
      summary: plan.summary.trim().length > 0 ? plan.summary.trim().slice(0, 80) :
        `今天先完成${tasks.length}项可执行任务`,
      detectedSubject: plan.detectedSubject.trim().length > 0 ? plan.detectedSubject.trim().slice(0, 20) :
        tasks[0].subject,
      recommendationReasons: plan.recommendationReasons.slice(0, 3),
      tasks: tasks,
      totalMinutes: usedMinutes,
      source: plan.source,
      model: plan.model,
      usage: usage,
      agentMode: plan.agentMode,
      toolCalls: plan.toolCalls,
      rounds: plan.rounds
    };
  }
}
