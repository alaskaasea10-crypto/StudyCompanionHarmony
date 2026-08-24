import { StudyTask } from '../models/StudyModels';

export interface TodayPlanResult {
  subject: string;
  tasks: StudyTask[];
  firstFocusMinutes: number;
  reason: string;
}

export class TodayPlanService {
  static generate(input: string, fallbackSubject: string, dailyMinutes: number): TodayPlanResult {
    const subject: string = input.includes('英语') ? '英语四六级' :
      (input.includes('高数') ? '高等数学' : fallbackSubject);
    const tired: boolean = input.includes('累') || input.includes('疲惫');
    const firstMinutes: number = tired ? 15 : Math.min(25, dailyMinutes);
    const practiceMinutes: number = tired ? 15 : Math.min(25, Math.max(15, dailyMinutes - firstMinutes));
    return {
      subject: subject,
      firstFocusMinutes: firstMinutes,
      reason: tired ? '检测到疲惫状态，已降低单次任务强度' : '根据每日可用时间生成可执行任务',
      tasks: [
        { title: `梳理${subject}最薄弱知识点`, subject: subject, minutes: firstMinutes, completed: false },
        { title: `完成${subject}针对练习`, subject: subject, minutes: practiceMinutes, completed: false },
        { title: `${subject}即时小测`, subject: subject, minutes: 10, completed: false },
        { title: '根据小测结果调整明日计划', subject: '学习复盘', minutes: 5, completed: false }
      ]
    };
  }
}
