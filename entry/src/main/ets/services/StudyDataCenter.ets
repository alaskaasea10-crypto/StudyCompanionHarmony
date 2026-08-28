import {
  FocusRecord,
  QuizAttempt,
  StudyMetrics,
  StudyStateSnapshot,
  StudyTask
} from '../models/StudyModels';

export class StudyDataCenter {
  static normalizeTasks(tasks: StudyTask[]): StudyTask[] {
    const now: number = Date.now();
    return tasks.map((task: StudyTask, index: number) => {
      const normalizedTask: StudyTask = {
        id: task.id ?? `migrated-task-${now}-${index}`,
        title: task.title,
        subject: task.subject,
        minutes: task.minutes,
        completed: task.completed,
        source: task.source ?? 'legacy',
        createdAt: task.createdAt ?? now,
        completedAt: task.completed ? (task.completedAt ?? now) : 0
      };
      return normalizedTask;
    });
  }

  static metrics(snapshot: StudyStateSnapshot): StudyMetrics {
    const tasks: StudyTask[] = snapshot.tasks ?? [];
    const focusRecords: FocusRecord[] = Array.isArray(snapshot.focusRecords) ? snapshot.focusRecords : [];
    const quizAttempts: QuizAttempt[] = Array.isArray(snapshot.quizAttempts) ? snapshot.quizAttempts : [];
    return StudyDataCenter.calculateMetrics(
      tasks,
      focusRecords,
      quizAttempts,
      snapshot.studyDayKey,
      snapshot.todayMinutes
    );
  }

  static calculateMetrics(tasks: StudyTask[], focusRecords: FocusRecord[], quizAttempts: QuizAttempt[],
    dayKey: string, legacyTodayMinutes: number): StudyMetrics {
    const completedTaskCount: number = tasks.filter((task: StudyTask) => task.completed).length;
    const totalTaskCount: number = tasks.length;
    const planProgress: number = totalTaskCount === 0 ? 0 :
      Math.round(completedTaskCount * 100 / totalTaskCount);
    const todayRecords: FocusRecord[] = focusRecords.filter((record: FocusRecord) => {
      return record.dayKey === dayKey;
    });
    const recordMinutes: number = todayRecords.reduce((total: number, record: FocusRecord) => {
      return total + Math.max(1, Math.round(record.elapsedSeconds / 60));
    }, 0);
    const todayAttempts: QuizAttempt[] = quizAttempts.filter((attempt: QuizAttempt) => {
      return attempt.dayKey === dayKey;
    });
    const metrics: StudyMetrics = {
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      planProgress: planProgress,
      todayFocusMinutes: Math.max(legacyTodayMinutes, recordMinutes),
      todayFocusSessionCount: todayRecords.length,
      quizAttemptCount: todayAttempts.length,
      quizCorrectCount: todayAttempts.filter((attempt: QuizAttempt) => attempt.correct).length
    };
    return metrics;
  }

  static createFocusRecord(task: StudyTask, plannedMinutes: number, elapsedSeconds: number,
    dayKey: string): FocusRecord {
    const completedAt: number = Date.now();
    const record: FocusRecord = {
      id: `focus-${completedAt}`,
      taskId: task.id ?? `task-${completedAt}`,
      taskTitle: task.title,
      subject: task.subject,
      plannedMinutes: plannedMinutes,
      elapsedSeconds: elapsedSeconds,
      completedAt: completedAt,
      dayKey: dayKey
    };
    return record;
  }

  static createQuizAttempt(subject: string, answer: string, correct: boolean,
    dayKey: string): QuizAttempt {
    const attemptedAt: number = Date.now();
    const attempt: QuizAttempt = {
      id: `quiz-${attemptedAt}`,
      questionId: 'matrix-invertible-01',
      subject: subject,
      answer: answer,
      correct: correct,
      attemptedAt: attemptedAt,
      dayKey: dayKey
    };
    return attempt;
  }
}
