import {
  AgentGeneratedTask,
  AgentPlan,
  AgentPlanRequest,
  AgentUsage,
  PlanningDecision
} from '../models/AgentModels';
import { StudyTask } from '../models/StudyModels';
import { AgentClient } from './AgentClient';
import { PlanValidator } from './PlanValidator';

export class LearningPlanningOrchestrator {
  private static mergeReasons(policyReasons: string[], modelReasons: string[]): string[] {
    const merged: string[] = [];
    policyReasons.concat(modelReasons).forEach((reason: string) => {
      const cleanReason: string = reason.trim();
      if (cleanReason.length > 0 && !merged.includes(cleanReason) && merged.length < 4) {
        merged.push(cleanReason);
      }
    });
    return merged;
  }

  private static fallbackPlan(request: AgentPlanRequest, policyReasons: string[]): AgentPlan {
    const ids: string[] = request.context.localDailyPlanTaskIds ?? [];
    if (ids.length === 0) { throw new Error('暂无可安排的真实任务，请先添加学习任务或完成当前反馈'); }
    const protectedStage: boolean = request.context.protectedStage === 'resume' ||
      request.context.protectedStage === 'verify';
    const budget: number | undefined = protectedStage ? undefined : request.context.availableMinutesToday;
    let remaining: number = budget === undefined ? 45 : budget;
    const tasks: AgentGeneratedTask[] = [];
    for (let index: number = 0; index < ids.length && tasks.length < (budget === undefined ? 1 : 4); index++) {
      const id: string = ids[index];
      const task: StudyTask | undefined = request.context.unfinishedTasks.find((item: StudyTask) => item.id === id);
      if (task === undefined) { continue; }
      const feedback: boolean = request.context.protectedStage === 'verify' && id === request.context.protectedTaskId;
      const localMinutes: number = request.context.localDailyPlanMinutes?.[index] ?? task.minutes;
      const minutes: number = feedback ? 0 : Math.min(45, task.minutes, localMinutes, remaining);
      if (!feedback && minutes < 5) { break; }
      tasks.push({ taskId: id, title: task.title, subject: task.subject, type: 'review',
        minutes: minutes, priority: tasks.length + 1, reason: '来自今天仍未完成的真实任务' });
      remaining -= minutes;
    }
    if (tasks.length === 0) { throw new Error('暂无可安排的真实任务，请先添加学习任务'); }
    const usage: AgentUsage = {
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0
    };
    return {
      summary: `今天先完成${tasks.length}项可执行任务`,
      detectedSubject: tasks[0].subject,
      recommendationReasons: LearningPlanningOrchestrator.mergeReasons(policyReasons, []),
      tasks: tasks,
      totalMinutes: tasks.reduce((total: number, task: AgentGeneratedTask) => total + task.minutes, 0),
      source: 'local-fallback',
      model: 'local-policy',
      usage: usage
    };
  }

  static async decide(request: AgentPlanRequest, policyReasons: string[]): Promise<PlanningDecision> {
    if (request.context.protectedStage === 'resume' || request.context.protectedStage === 'verify') {
      const protectedPlan: AgentPlan = PlanValidator.validateExisting(
        LearningPlanningOrchestrator.fallbackPlan(request, policyReasons), request);
      return { plan: protectedPlan, notice: '当前专注或反馈优先保留，完成后再更新学习节奏' };
    }
    const available: number | undefined = request.context.availableMinutesToday;
    if (available !== undefined && (!Number.isFinite(available) || available < 5)) {
      throw new Error('今天确认的可学习时间不足 5 分钟');
    }
    try {
      const modelPlan: AgentPlan = await AgentClient.generateTodayPlan(request);
      const normalizedPlan: AgentPlan = PlanValidator.validateExisting({
        summary: modelPlan.summary,
        detectedSubject: modelPlan.detectedSubject,
        recommendationReasons: LearningPlanningOrchestrator.mergeReasons(
          policyReasons,
          modelPlan.recommendationReasons
        ),
        tasks: modelPlan.tasks,
        totalMinutes: modelPlan.totalMinutes,
        source: 'openpangu',
        model: modelPlan.model,
        usage: modelPlan.usage,
        agentMode: modelPlan.agentMode,
        toolCalls: modelPlan.toolCalls,
        rounds: modelPlan.rounds
      }, request);
      return {
        plan: normalizedPlan,
        notice: ''
      };
    } catch (error) {
      const message: string = error instanceof Error && error.message.length > 0 ?
        error.message : 'Agent 服务暂不可用';
      const fallback: AgentPlan = PlanValidator.validateExisting(
        LearningPlanningOrchestrator.fallbackPlan(request, policyReasons), request);
      return {
        plan: fallback,
        notice: `${message}，已改用真实任务的本地安排`
      };
    }
  }
}
