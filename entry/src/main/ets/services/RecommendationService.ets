import { ScheduleItem, StudyTask } from '../models/StudyModels';

export interface RecommendationContext {
  goal: string;
  learningStyle: string;
  energyState: string;
  subject: string;
  examDays: number;
  scheduleReady: boolean;
  scheduleItems: ScheduleItem[];
  tasks: StudyTask[];
  now: number;
}

export interface RecommendationResult {
  taskIndex: number;
  allDone: boolean;
  title: string;
  subject: string;
  minutes: number;
  reason: string;
  evidence: string[];
  timelineTime: string;
  timelineTitle: string;
  timelineDetail: string;
}

interface ScheduleInsight {
  summary: string;
  timelineTime: string;
  timelineTitle: string;
  timelineDetail: string;
}

export class RecommendationService {
  private static nextTaskIndex(tasks: StudyTask[]): number {
    const feedbackIndex: number = tasks.findIndex((task: StudyTask) =>
      !task.completed && task.source === 'quiz-feedback');
    if (feedbackIndex >= 0) {
      return feedbackIndex;
    }
    return tasks.findIndex((task: StudyTask) => !task.completed);
  }

  private static sourceText(task: StudyTask): string {
    if (task.source === 'openpangu') {
      return 'openPangu决策计划';
    }
    if (task.source === 'local-fallback') {
      return '离线决策计划';
    }
    if (task.source === 'quiz-feedback') {
      return '小测反馈触发';
    }
    if (task.source === 'manual') {
      return '用户主动添加';
    }
    return '学习画像计划';
  }

  private static timeToMinutes(value: string): number {
    const parts: string[] = value.split(':');
    if (parts.length !== 2) {
      return 0;
    }
    return Number(parts[0]) * 60 + Number(parts[1]);
  }

  private static beijingClock(now: number): Date {
    return new Date(now + 8 * 60 * 60 * 1000);
  }

  private static scheduleInsight(context: RecommendationContext, taskMinutes: number): ScheduleInsight {
    if (!context.scheduleReady || context.scheduleItems.length === 0) {
      return {
        summary: '课表尚未导入，当前先按学习画像安排',
        timelineTime: '待设置',
        timelineTitle: '导入课表后可识别空闲时间',
        timelineDetail: '学伴会避开上课时段，再主动推荐学习任务'
      };
    }
    const clock: Date = RecommendationService.beijingClock(context.now);
    const weekday: number = clock.getUTCDay();
    const nowMinutes: number = clock.getUTCHours() * 60 + clock.getUTCMinutes();
    const todayItems: ScheduleItem[] = context.scheduleItems
      .filter((item: ScheduleItem) => item.weekday === weekday)
      .sort((left: ScheduleItem, right: ScheduleItem) =>
        RecommendationService.timeToMinutes(left.startTime) - RecommendationService.timeToMinutes(right.startTime));
    const current: ScheduleItem | undefined = todayItems.find((item: ScheduleItem) =>
      RecommendationService.timeToMinutes(item.startTime) <= nowMinutes &&
        RecommendationService.timeToMinutes(item.endTime) > nowMinutes);
    if (current !== undefined) {
      return {
        summary: `${current.course}正在进行，建议把任务留到下课后`,
        timelineTime: current.endTime,
        timelineTitle: `${current.course}下课`,
        timelineDetail: `下课后先休息，再开始${taskMinutes}分钟学习任务`
      };
    }
    const next: ScheduleItem | undefined = todayItems.find((item: ScheduleItem) =>
      RecommendationService.timeToMinutes(item.startTime) > nowMinutes);
    if (next !== undefined) {
      const freeMinutes: number = RecommendationService.timeToMinutes(next.startTime) - nowMinutes;
      const enoughText: string = freeMinutes >= taskMinutes ? '足够完成当前任务' : '适合先做短时准备';
      return {
        summary: `距${next.course}还有${freeMinutes}分钟，${enoughText}`,
        timelineTime: next.startTime,
        timelineTitle: `${next.course}即将开始`,
        timelineDetail: `${next.location} · 建议提前5分钟到达`
      };
    }
    return {
      summary: '今天已无后续课程，可使用连续空闲时间学习',
      timelineTime: '20:30',
      timelineTitle: '晚间轻复盘',
      timelineDetail: `回顾今天的${context.subject}学习结果，Agent将据此调整下一步`
    };
  }

  static recommend(context: RecommendationContext): RecommendationResult {
    const taskIndex: number = RecommendationService.nextTaskIndex(context.tasks);
    if (taskIndex < 0) {
      return {
        taskIndex: 0,
        allDone: true,
        title: '今天的计划已经完成',
        subject: context.subject,
        minutes: 0,
        reason: '所有行动项均已完成。现在更值得休息，晚些时候再做一次轻复盘。',
        evidence: ['今日任务：全部完成', `考试：${context.subject}还有${context.examDays}天`, `当前状态：${context.energyState}`],
        timelineTime: '20:30',
        timelineTitle: '生成今日复盘',
        timelineDetail: '根据完成情况整理收获，并准备下一次主动建议'
      };
    }
    const task: StudyTask = context.tasks[taskIndex];
    const schedule: ScheduleInsight = RecommendationService.scheduleInsight(context, task.minutes);
    const energyText: string = context.energyState === '有点累' ?
      '当前精力偏低，先完成一个明确的小目标' : `当前状态为“${context.energyState}”，适合继续推进`;
    const feedbackText: string = task.source === 'quiz-feedback' ?
      '刚才的小测暴露了这个薄弱点，因此优先安排针对复习；' : '';
    return {
      taskIndex: taskIndex,
      allDone: false,
      title: task.title,
      subject: task.subject,
      minutes: task.minutes,
      reason: `${feedbackText}${schedule.summary}；距离${context.subject}考试还有${context.examDays}天。${energyText}。`,
      evidence: [
        `课表：${schedule.summary}`,
        `考试：${context.subject}还有${context.examDays}天`,
        `状态：${context.energyState}`,
        `画像：${context.goal} · ${context.learningStyle}`,
        `来源：${RecommendationService.sourceText(task)}`
      ],
      timelineTime: schedule.timelineTime,
      timelineTitle: schedule.timelineTitle,
      timelineDetail: schedule.timelineDetail
    };
  }
}
