import { AcademicGoal, GoalMilestone, StudyTask } from '../models/StudyModels';

export interface GoalPriority {
  goal: AcademicGoal;
  daysLeft: number;
  unfinishedTaskCount: number;
  reason: string;
}

export class GoalPlanningService {
  static create(title: string, subject: string, deadline: string, estimatedMinutes: number,
    type: string = '考试'): AcademicGoal {
    const now: number = Date.now();
    const goal: AcademicGoal = { id: `goal-${now}`, title: title.trim(), type: type, subject: subject.trim(),
      deadline: deadline.trim(), estimatedMinutes: Math.min(6000, Math.max(60, estimatedMinutes)),
      completed: false, createdAt: now };
    goal.milestones = GoalPlanningService.decompose(goal);
    return goal;
  }

  private static dateKey(time: number): string {
    const date: Date = new Date(time + 8 * 60 * 60 * 1000);
    return `${date.getUTCFullYear()}-${(date.getUTCMonth() + 1).toString().padStart(2, '0')}-${date.getUTCDate().toString().padStart(2, '0')}`;
  }

  static decompose(goal: AcademicGoal): GoalMilestone[] {
    const linear: string[] = ['确认考试范围与评分要求', '攻克矩阵运算与核心概念', '攻克可逆矩阵、秩与方程', '整理学习收获与考前回顾'];
    const calculus: string[] = ['确认考试范围与评分要求', '巩固基本求导规则', '攻克链式法则与综合应用', '整理学习收获与考前回顾'];
    const general: string[] = ['明确目标范围与交付标准', '整理核心概念与资料', '完成关键练习或初稿', '检查结果并完成最终提交'];
    const titles: string[] = goal.subject.includes('线性代数') ? linear :
      goal.subject.includes('高等数学') || goal.subject.includes('微积分') ? calculus : general;
    const deadlineTime: number = new Date(`${goal.deadline}T00:00:00+08:00`).getTime();
    const safeDeadline: number = Number.isFinite(deadlineTime) ? deadlineTime : goal.createdAt + 7 * 86400000;
    const span: number = Math.max(0, safeDeadline - goal.createdAt);
    const baseMinutes: number = Math.max(15, Math.floor(goal.estimatedMinutes / titles.length));
    return titles.map((title: string, index: number): GoalMilestone => {
      const dueTime: number = index === titles.length - 1 ? safeDeadline :
        goal.createdAt + Math.floor(span * (index + 1) / titles.length);
      return { id: `${goal.id}-m${index + 1}`, title: title,
        description: index === titles.length - 1 ? '用可检查的结果确认目标是否达成' : '完成本阶段后自动解锁下一阶段',
        dueDate: GoalPlanningService.dateKey(dueTime), minutes: baseMinutes, completed: false };
    });
  }

  static normalize(goal: AcademicGoal): AcademicGoal {
    return { id: goal.id, title: goal.title, type: goal.type, subject: goal.subject, deadline: goal.deadline,
      estimatedMinutes: goal.estimatedMinutes, completed: goal.completed, createdAt: goal.createdAt,
      milestones: Array.isArray(goal.milestones) && goal.milestones.length > 0 ? goal.milestones :
        GoalPlanningService.decompose(goal) };
  }

  static nextMilestone(goal: AcademicGoal): GoalMilestone | undefined {
    return (goal.milestones ?? []).find((item: GoalMilestone) => !item.completed);
  }

  static taskFor(goal: AcademicGoal, milestone: GoalMilestone): StudyTask {
    return { id: `goal-task-${milestone.id}`, title: milestone.title, subject: goal.subject,
      minutes: Math.min(45, Math.max(15, milestone.minutes)), completed: false, source: 'goal-milestone',
      createdAt: Date.now(), completedAt: 0, goalId: goal.id, milestoneId: milestone.id };
  }

  static daysUntil(deadline: string, now: number = Date.now()): number {
    const target: number = new Date(`${deadline}T00:00:00+08:00`).getTime();
    if (!Number.isFinite(target)) { return 999; }
    const clock: Date = new Date(now + 8 * 60 * 60 * 1000);
    const today: number = new Date(`${clock.getUTCFullYear()}-${(clock.getUTCMonth() + 1).toString().padStart(2, '0')}-${clock.getUTCDate().toString().padStart(2, '0')}T00:00:00+08:00`).getTime();
    return Math.ceil((target - today) / 86400000);
  }

  static prioritize(goals: AcademicGoal[], tasks: StudyTask[], now: number = Date.now()): GoalPriority | undefined {
    const active: AcademicGoal[] = goals.filter((goal: AcademicGoal) => !goal.completed);
    const ranked: GoalPriority[] = active.map((goal: AcademicGoal): GoalPriority => {
      const daysLeft: number = GoalPlanningService.daysUntil(goal.deadline, now);
      const unfinished: number = tasks.filter((task: StudyTask) => !task.completed && task.subject === goal.subject).length;
      const urgency: string = daysLeft < 0 ? `已逾期${Math.abs(daysLeft)}天` : daysLeft === 0 ? '今天截止' : `还有${daysLeft}天`;
      return { goal: goal, daysLeft: daysLeft, unfinishedTaskCount: unfinished,
        reason: `${urgency} · ${unfinished}项相关任务未完成` };
    });
    ranked.sort((left: GoalPriority, right: GoalPriority) => {
      const leftDays: number = left.daysLeft < 0 ? -1000 + left.daysLeft : left.daysLeft;
      const rightDays: number = right.daysLeft < 0 ? -1000 + right.daysLeft : right.daysLeft;
      if (leftDays !== rightDays) { return leftDays - rightDays; }
      if (left.unfinishedTaskCount !== right.unfinishedTaskCount) { return right.unfinishedTaskCount - left.unfinishedTaskCount; }
      return left.goal.createdAt - right.goal.createdAt;
    });
    return ranked[0];
  }
}
