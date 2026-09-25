import { StudyTask } from '../models/StudyModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { BankLearningBridge } from './BankLearningBridge';

export type DailyActionStage = 'plan' | 'diagnose' | 'remediate' | 'retest' | 'execute' | 'done' | 'resume' | 'verify' | 'wait';

export interface DailyAction {
  key?: string;
  taskId?: string;
  stage: DailyActionStage;
  headline: string;
  actionTitle: string;
  reason: string;
  completionStandard: string;
  nextStep: string;
  subject: string;
  minutes: number;
  taskIndex: number;
  topicId: string;
}

export class DailyActionService {
  private static topicFor(subject: string): string {
    return subject.includes('高等数学') || subject.includes('微积分') ? 'derivative' : 'matrix';
  }

  private static bankSupported(subject: string): boolean {
    return subject.includes('线性代数') || subject.includes('矩阵') ||
      subject.includes('高等数学') || subject.includes('微积分');
  }

  static decide(subject: string, tasks: StudyTask[], evidence: BankLearningEvidence[]): DailyAction {
    const subjectTaskIndex: number = tasks.findIndex((task: StudyTask) => !task.completed && task.subject === subject);
    const taskIndex: number = subjectTaskIndex >= 0 ? subjectTaskIndex : tasks.findIndex((task: StudyTask) => !task.completed);
    const relevant: BankLearningEvidence[] = evidence.filter((item: BankLearningEvidence) => item.subject === subject);
    const topicId: string = DailyActionService.topicFor(subject);
    if (DailyActionService.bankSupported(subject) && relevant.length === 0) {
      return { stage: 'diagnose', headline: `先确认${subject}真正卡在哪里`, actionTitle: '开始 3 题诊断',
        reason: '目前没有可靠的答题证据，先诊断再规划，避免把时间花在已经掌握的内容上。',
        completionStandard: '连续提交 3 道题，覆盖本专题的 3 个关键能力。',
        nextStep: '完成后自动找出最薄弱知识点，并给出补学或继续任务建议。',
        subject: subject, minutes: 8, taskIndex: Math.max(0, taskIndex), topicId: topicId };
    }
    const weak: BankLearningEvidence | undefined = BankLearningBridge.weakest(relevant);
    if (weak !== undefined) {
      return { stage: 'remediate', headline: `先补上：${weak.knowledgePoint}`, actionTitle: '查看薄弱点并开始补学',
        reason: BankLearningBridge.reason(weak),
        completionStandard: '完成针对性巩固，并用同知识点的新题验证，不以看过解析代替掌握。',
        nextStep: '换题答对后继续今日任务；仍答错则保留在错题本并再次调整计划。',
        subject: weak.subject, minutes: 15, taskIndex: Math.max(0, taskIndex),
        topicId: BankLearningBridge.topicId(weak) };
    }
    const strengthening: BankLearningEvidence | undefined = relevant.find((item: BankLearningEvidence) =>
      item.status === '正在巩固');
    if (strengthening !== undefined) {
      return { stage: 'retest', headline: `再验证一次：${strengthening.knowledgePoint}`, actionTitle: '进入换题复测',
        reason: '当前只有一次正确证据，还不足以判定稳定掌握。',
        completionStandard: '同一能力至少累计 2 道不同题且最近均答对。',
        nextStep: '复测通过后推进今日任务；未通过则转为针对性补学。',
        subject: strengthening.subject, minutes: 8, taskIndex: Math.max(0, taskIndex),
        topicId: BankLearningBridge.topicId(strengthening) };
    }
    if (taskIndex >= 0) {
      const task: StudyTask = tasks[taskIndex];
      return { stage: 'execute', headline: task.title, actionTitle: `开始 ${task.minutes} 分钟`,
        reason: '诊断证据暂未发现需要抢先处理的薄弱点，现在推进计划中的首项未完成任务。',
        completionStandard: `专注完成“${task.title}”，随后提交即时小测或学习结果。`,
        nextStep: '系统会根据完成记录和小测结果，重新计算下一项任务。',
        subject: task.subject, minutes: task.minutes, taskIndex: taskIndex, topicId: topicId };
    }
    return { stage: 'done', headline: '今天的计划已经完成', actionTitle: '今日行动已完成',
      reason: '当前任务均已完成，可以休息；晚些时候做一次轻复盘。',
      completionStandard: '今日计划内任务全部完成。', nextStep: '下一次打开时根据新课表、截止日期和答题证据重新安排。',
      subject: subject, minutes: 0, taskIndex: 0, topicId: topicId };
  }
}
