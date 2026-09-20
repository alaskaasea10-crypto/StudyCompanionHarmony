import { StudyTask } from '../models/StudyModels';

export interface TodayPlanResult {
  subject: string;
  tasks: StudyTask[];
  firstFocusMinutes: number;
  reason: string;
}

export class TodayPlanService {
  static generate(input: string, fallbackSubject: string, dailyMinutes: number): TodayPlanResult {
    const subject: string = input.includes('操作系统') ? '操作系统' :
      (input.includes('数据结构') ? '数据结构' :
        (input.includes('计算机网络') ? '计算机网络' :
          (input.includes('英语') || input.includes('四六级') ? '英语四六级' :
            (/高数|微积分|导数|求导|链式/.test(input) ? '高等数学' :
              (/线代|矩阵|可逆|秩/.test(input) ? '线性代数' : fallbackSubject)))));
    const tired: boolean = input.includes('累') || input.includes('疲惫');
    const budget: number = Math.min(240, Math.max(5, dailyMinutes));
    const desiredMinutes: number[] = [tired ? 10 : 15, tired ? 15 : 25, 10, 5];
    let titles: string[] = [
      `列出${subject}3个待巩固点`,
      `精读资料并补全${subject}笔记`,
      `完成1道例题并标记卡点`,
      '用3句话记录本轮收获'
    ];
    if (/作业|报告|论文|提交/.test(input)) {
      titles = [
        `拆解${subject}任务要求与交付物`,
        `完成${subject}任务主体内容`,
        `按要求逐项自查并修正`,
        '记录尚未解决的一个问题'
      ];
    } else if (/预习|新课|提前看/.test(input)) {
      titles = [
        `浏览${subject}章节结构并圈出重点`,
        `精读${subject}核心概念与例子`,
        `写下3个课堂待确认问题`,
        '用3句话复述本节主线'
      ];
    } else if (/背|单词|记忆/.test(input)) {
      titles = [
        `筛出${subject}本轮重点记忆项`,
        `完成一轮主动回忆并核对`,
        `重测未记住的内容`,
        '记录下一轮复习入口'
      ];
    }
    const subjects: string[] = [subject, subject, subject, '学习复盘'];
    const tasks: StudyTask[] = [];
    let remaining: number = budget;
    for (let index: number = 0; index < desiredMinutes.length; index++) {
      if (remaining < 5) {
        break;
      }
      const minutes: number = Math.min(desiredMinutes[index], remaining);
      tasks.push({
        title: titles[index],
        subject: subjects[index],
        minutes: minutes,
        completed: false
      });
      remaining -= minutes;
    }
    return {
      subject: subject,
      firstFocusMinutes: tasks[0].minutes,
      reason: tired ? '当前精力偏低，已缩短单个专注块' : '按目标产出与本次可用时间拆成可验收步骤',
      tasks: tasks
    };
  }
}
