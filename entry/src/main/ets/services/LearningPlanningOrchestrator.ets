import {
  AgentGeneratedTask,
  AgentPlan,
  AgentPlanRequest,
  AgentUsage,
  PlanningDecision
} from '../models/AgentModels';
import { KnowledgeMastery, StudyTask } from '../models/StudyModels';
import { AgentClient } from './AgentClient';
import { PlanValidator } from './PlanValidator';
import { TodayPlanResult, TodayPlanService } from './TodayPlanService';

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
    const result: TodayPlanResult = TodayPlanService.generate(
      request.requestText,
      request.profile.subject,
      request.context.availableMinutesToday
    );
    const tasks: AgentGeneratedTask[] = result.tasks.map((task: StudyTask, index: number) => {
      const generatedTask: AgentGeneratedTask = {
        title: task.title,
        subject: task.subject,
        type: 'review',
        minutes: task.minutes,
        priority: index + 1,
        reason: result.reason
      };
      return generatedTask;
    });
    const usage: AgentUsage = {
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0
    };
    return {
      summary: `今天先完成${tasks.length}项可执行任务`,
      detectedSubject: result.subject,
      recommendationReasons: LearningPlanningOrchestrator.mergeReasons(policyReasons, [result.reason]),
      tasks: tasks,
      totalMinutes: tasks.reduce((total: number, task: AgentGeneratedTask) => total + task.minutes, 0),
      source: 'local-fallback',
      model: 'local-policy',
      usage: usage
    };
  }

  static async decide(request: AgentPlanRequest, policyReasons: string[]): Promise<PlanningDecision> {
    if (!Number.isFinite(request.context.availableMinutesToday) || request.context.availableMinutesToday < 5) {
      throw new Error('本次可规划时长不足 5 分钟，请告诉星球你能投入多久');
    }
    try {
      const modelPlan: AgentPlan = await AgentClient.generateTodayPlan(request);
      const normalizedPlan: AgentPlan = PlanValidator.validate({
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
        usage: modelPlan.usage
      }, request.context.availableMinutesToday);
      return {
        plan: normalizedPlan,
        notice: ''
      };
    } catch (error) {
      const message: string = error instanceof Error && error.message.length > 0 ?
        error.message : 'Agent 服务暂不可用';
      const fallback: AgentPlan = PlanValidator.validate(
        LearningPlanningOrchestrator.fallbackPlan(request, policyReasons),
        request.context.availableMinutesToday
      );
      return {
        plan: fallback,
        notice: `${message}，已由同一决策链生成离线方案供你确认`
      };
    }
  }
}
