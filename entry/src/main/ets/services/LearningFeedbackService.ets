import { QuizFeedbackResult } from '../models/AgentModels';
import { StudyTask } from '../models/StudyModels';

export class LearningFeedbackService {
  static applyQuizResult(tasks: StudyTask[], subject: string, correct: boolean,
    knowledgePoint: string = '当前知识点'): QuizFeedbackResult {
    if (correct) {
      const quizIndex: number = tasks.findIndex((task: StudyTask) => !task.completed && task.title.includes('小测'));
      if (quizIndex < 0) {
        return { tasks: tasks, message: '小测已记录，当前计划无需调整' };
      }
      const updated: StudyTask[] = tasks.map((task: StudyTask, index: number) => {
        if (index !== quizIndex) {
          return task;
        }
        return {
          id: task.id,
          title: task.title,
          subject: task.subject,
          minutes: task.minutes,
          completed: true,
          source: task.source,
          createdAt: task.createdAt,
          completedAt: Date.now()
        };
      });
      return { tasks: updated, message: '小测通过，已完成当前测验任务' };
    }
    const reviewTitle: string = `针对复习：${knowledgePoint}`;
    const reviewExists: boolean = tasks.some((task: StudyTask) => task.title === reviewTitle && !task.completed);
    if (reviewExists) {
      return { tasks: tasks, message: '薄弱点复习任务已在计划中，无需重复添加' };
    }
    const reviewTask: StudyTask = {
      id: `quiz-feedback-${Date.now()}`,
      title: reviewTitle,
      subject: subject,
      minutes: 10,
      completed: false,
      source: 'quiz-feedback',
      createdAt: Date.now(),
      completedAt: 0
    };
    const completedTasks: StudyTask[] = tasks.filter((task: StudyTask) => task.completed);
    const pendingTasks: StudyTask[] = tasks.filter((task: StudyTask) => !task.completed);
    return {
      tasks: completedTasks.concat([reviewTask]).concat(pendingTasks),
      message: `检测到“${knowledgePoint}”薄弱点，已加入针对复习并请求 Agent 调整后续计划`
    };
  }
}
