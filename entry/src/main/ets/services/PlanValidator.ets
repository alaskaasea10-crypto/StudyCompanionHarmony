import { AgentGeneratedTask, AgentPlan, AgentUsage } from '../models/AgentModels';

export class PlanValidator {
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
      usage: usage
    };
  }
}
