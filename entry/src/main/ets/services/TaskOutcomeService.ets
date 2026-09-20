import { StudyTask } from '../models/StudyModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';

export class TaskOutcomeService {
  static kind(task: StudyTask): string {
    // 所有学科以用户提交的产出自查收尾，不再跳转题库或自动判定掌握。
    return 'self';
  }

  static topic(task: StudyTask): string {
    return /导数|链式|求导|微积分|高等数学/.test(task.title + task.subject) ? 'derivative' :
      /可逆|秩|方程/.test(task.title) ? 'rank' : 'matrix';
  }

  static focused(task: StudyTask, now: number): StudyTask {
    const result: StudyTask = JSON.parse(JSON.stringify(task)) as StudyTask;
    result.completed = false; result.completedAt = 0; result.outcome = 'focused';
    result.focusedAt = now; result.submittedAt = 0; result.verifiedAt = 0; result.resultNote = '';
    return result;
  }

  static submit(task: StudyTask, passed: boolean, note: string, now: number): StudyTask {
    const self: boolean = TaskOutcomeService.kind(task) === 'self';
    const result: StudyTask = JSON.parse(JSON.stringify(task)) as StudyTask;
    result.outcome = passed && !self ? 'verified' : 'submitted'; result.submittedAt = now;
    result.verifiedAt = passed && !self ? now : 0; result.resultNote = note;
    result.completed = passed; result.completedAt = passed ? now : 0;
    return result;
  }

  static bankPassed(task: StudyTask, evidence: BankLearningEvidence[]): boolean {
    const relevant: BankLearningEvidence[] = evidence.filter((item: BankLearningEvidence) =>
      item.subject === task.subject && item.topicId === TaskOutcomeService.topic(task));
    return (task.outcome === 'focused' || task.outcome === 'submitted') && (task.focusedAt ?? 0) > 0 && relevant.length >= 3 &&
      relevant.every((item: BankLearningEvidence) => item.status === '初步掌握' &&
        item.sessionStartedAt >= (task.focusedAt ?? 0));
  }
}
