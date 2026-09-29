import { AcademicGoal, GoalMilestone, StudyTask } from '../models/StudyModels';

export interface GoalPriority {
  goal: AcademicGoal;
  daysLeft: number;
  reason: string;
}

export class GoalPlanningService {
  static create(title: string, subject: string, deadline: string, estimatedMinutes: number,
    type: string = '考试'): AcademicGoal {
    const now: number = Date.now();
    const goal: AcademicGoal = { id: `goal-${now}`, title: title.trim(), type: type, subject: subject.trim(),
      deadline: GoalPlanningService.normalizeDeadline(deadline),
      estimatedMinutes: Math.min(6000, Math.max(60, estimatedMinutes)),
      completed: false, createdAt: now };
    goal.milestones = GoalPlanningService.decompose(goal);
    return goal;
  }

  private static dateKey(time: number): string {
    const date: Date = new Date(time + 8 * 60 * 60 * 1000);
    return `${date.getUTCFullYear()}-${(date.getUTCMonth() + 1).toString().padStart(2, '0')}-${date.getUTCDate().toString().padStart(2, '0')}`;
  }

  static normalizeDeadline(deadline: string): string {
    const value: string = deadline.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) { return ''; }
    const target: number = new Date(`${value}T00:00:00+08:00`).getTime();
    if (!Number.isFinite(target) || GoalPlanningService.dateKey(target) !== value) { return ''; }
    return value;
  }

  static deadlineFromDate(value: Date): string {
    if (!Number.isFinite(value.getTime())) { return ''; }
    const year: string = value.getFullYear().toString().padStart(4, '0');
    const month: string = (value.getMonth() + 1).toString().padStart(2, '0');
    const day: string = value.getDate().toString().padStart(2, '0');
    return GoalPlanningService.normalizeDeadline(`${year}-${month}-${day}`);
  }

  static pickerDate(deadline: string, now: number = Date.now()): Date {
    const value: string = GoalPlanningService.normalizeDeadline(deadline);
    if (value.length > 0) {
      const parts: string[] = value.split('-');
      return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    const clock: Date = new Date(now + 8 * 60 * 60 * 1000);
    return new Date(clock.getUTCFullYear(), clock.getUTCMonth(), clock.getUTCDate());
  }

  static displayDeadline(deadline: string): string {
    const value: string = GoalPlanningService.normalizeDeadline(deadline);
    if (value.length === 0) { return '请选择日期'; }
    const parts: string[] = value.split('-');
    return `${parts[0]}年${Number(parts[1])}月${Number(parts[2])}日`;
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
      // 过期目标或被提前的目标，所有内部阶段日期都必须以目标 deadline 为上限。
      const guardedDueTime: number = Math.min(safeDeadline, dueTime);
      return { id: `${goal.id}-m${index + 1}`, title: title,
        description: index === titles.length - 1 ? '用可检查的结果确认目标是否达成' : '完成本阶段后自动解锁下一阶段',
        dueDate: GoalPlanningService.dateKey(guardedDueTime), minutes: baseMinutes, completed: false };
    });
  }

  private static refreshedMilestones(goal: AcademicGoal, existing: GoalMilestone[] | undefined): GoalMilestone[] {
    const generated: GoalMilestone[] = GoalPlanningService.decompose(goal);
    const previous: GoalMilestone[] = existing ?? [];
    return generated.map((item: GoalMilestone, index: number): GoalMilestone => {
      const old: GoalMilestone | undefined = previous[index];
      return { id: old?.id ?? item.id, title: item.title, description: item.description,
        dueDate: item.dueDate, minutes: item.minutes, completed: old?.completed ?? false };
    });
  }

  static normalize(goal: AcademicGoal): AcademicGoal {
    const normalized: AcademicGoal = { id: goal.id, title: goal.title, type: goal.type, subject: goal.subject,
      deadline: GoalPlanningService.normalizeDeadline(goal.deadline),
      estimatedMinutes: goal.estimatedMinutes, completed: goal.completed,
      createdAt: goal.createdAt };
    normalized.milestones = GoalPlanningService.refreshedMilestones(normalized, goal.milestones);
    return normalized;
  }

  // 编辑长期目标时保留 goalId、创建时间、完成状态与已有阶段身份。
  static update(goal: AcademicGoal, title: string, subject: string, deadline: string,
    estimatedMinutes: number): AcademicGoal {
    const updated: AcademicGoal = { id: goal.id, title: title.trim(), type: goal.type, subject: subject.trim(),
      deadline: GoalPlanningService.normalizeDeadline(deadline),
      estimatedMinutes: Math.min(6000, Math.max(60, estimatedMinutes)),
      completed: goal.completed, createdAt: goal.createdAt };
    updated.milestones = GoalPlanningService.refreshedMilestones(updated, goal.milestones);
    return updated;
  }

  static daysUntil(deadline: string, now: number = Date.now()): number {
    const value: string = GoalPlanningService.normalizeDeadline(deadline);
    if (value.length === 0) { return 999; }
    const target: number = new Date(`${value}T00:00:00+08:00`).getTime();
    const clock: Date = new Date(now + 8 * 60 * 60 * 1000);
    const today: number = new Date(`${clock.getUTCFullYear()}-${(clock.getUTCMonth() + 1).toString().padStart(2, '0')}-${clock.getUTCDate().toString().padStart(2, '0')}T00:00:00+08:00`).getTime();
    return Math.ceil((target - today) / 86400000);
  }

  // 长期目标只作为今天及未来的提醒和规划上下文；过期目标仍保留在持久层。
  static activeGoals(goals: AcademicGoal[], now: number = Date.now()): AcademicGoal[] {
    const active: AcademicGoal[] = goals.filter((goal: AcademicGoal) => {
      const days: number = GoalPlanningService.daysUntil(goal.deadline, now);
      return days !== 999 && days >= 0;
    });
    active.sort((left: AcademicGoal, right: AcademicGoal): number => {
      const dayDifference: number = GoalPlanningService.daysUntil(left.deadline, now) -
        GoalPlanningService.daysUntil(right.deadline, now);
      return dayDifference !== 0 ? dayDifference : left.createdAt - right.createdAt;
    });
    return active;
  }

  static prioritize(goals: AcademicGoal[], _tasks: StudyTask[], now: number = Date.now()): GoalPriority | undefined {
    const active: AcademicGoal[] = GoalPlanningService.activeGoals(goals, now);
    const ranked: GoalPriority[] = active.map((goal: AcademicGoal): GoalPriority => {
      const daysLeft: number = GoalPlanningService.daysUntil(goal.deadline, now);
      const urgency: string = daysLeft === 0 ? '今天截止' : `还有${daysLeft}天`;
      return { goal: goal, daysLeft: daysLeft, reason: urgency };
    });
    ranked.sort((left: GoalPriority, right: GoalPriority) => {
      if (left.daysLeft !== right.daysLeft) { return left.daysLeft - right.daysLeft; }
      return left.goal.createdAt - right.goal.createdAt;
    });
    return ranked[0];
  }
}
