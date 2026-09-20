import {
  FocusRecord,
  QuizAttempt,
  StudyMetrics,
  StudyStateSnapshot,
  StudyTask
} from '../models/StudyModels';

export class StudyDataCenter {
  static learningStreak(focusRecords: FocusRecord[], quizAttempts: QuizAttempt[],
    bankDays: string[], now: number = Date.now()): number {
    const days: Set<string> = new Set<string>(bankDays);
    focusRecords.forEach((record: FocusRecord) => {
      if (record.elapsedSeconds >= 60) { days.add(record.dayKey); }
    });
    quizAttempts.forEach((attempt: QuizAttempt) => { days.add(attempt.dayKey); });
    let cursor: number = Math.floor((now + 8 * 3600000) / 86400000) * 86400000;
    // 今天尚未学习时保留截至昨天的连续记录，整天中断后再归零。
    if (!days.has(new Date(cursor).toISOString().substring(0, 10))) { cursor -= 86400000; }
    let count: number = 0;
    while (days.has(new Date(cursor).toISOString().substring(0, 10))) {
      count++;
      cursor -= 86400000;
    }
    return count;
  }

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
        completedAt: task.completed ? (task.completedAt ?? now) : 0,
        goalId: task.goalId,
        milestoneId: task.milestoneId,
        outcome: task.outcome,
        focusedAt: task.focusedAt,
        submittedAt: task.submittedAt,
        verifiedAt: task.verifiedAt,
        resultNote: task.resultNote
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
      return total + Math.max(0, Math.floor(record.elapsedSeconds / 60));
    }, 0);
    const todayAttempts: QuizAttempt[] = quizAttempts.filter((attempt: QuizAttempt) => {
      return attempt.dayKey === dayKey;
    });
    const metrics: StudyMetrics = {
      completedTaskCount: completedTaskCount,
      totalTaskCount: totalTaskCount,
      planProgress: planProgress,
      todayFocusMinutes: Math.max(legacyTodayMinutes, recordMinutes),
      todayFocusSessionCount: todayRecords.filter((record: FocusRecord) => record.completed !== false).length,
      quizAttemptCount: todayAttempts.length,
      quizCorrectCount: todayAttempts.filter((attempt: QuizAttempt) => attempt.correct).length
    };
    return metrics;
  }

  static createFocusRecord(task: StudyTask, plannedMinutes: number, elapsedSeconds: number,
    dayKey: string, completed: boolean = true): FocusRecord {
    const completedAt: number = Date.now();
    const record: FocusRecord = {
      id: `focus-${completedAt}`,
      taskId: task.id ?? `task-${completedAt}`,
      taskTitle: task.title,
      subject: task.subject,
      plannedMinutes: plannedMinutes,
      elapsedSeconds: Math.max(0, elapsedSeconds),
      completedAt: completedAt,
      dayKey: dayKey,
      completed: completed
    };
    return record;
  }

  static createQuizAttempt(questionId: string, subject: string, taskId: string,
    knowledgePoint: string, answer: string, correct: boolean, dayKey: string): QuizAttempt {
    const attemptedAt: number = Date.now();
    const attempt: QuizAttempt = {
      id: `quiz-${attemptedAt}`,
      questionId: questionId,
      subject: subject,
      taskId: taskId,
      knowledgePoint: knowledgePoint,
      answer: answer,
      correct: correct,
      attemptedAt: attemptedAt,
      dayKey: dayKey
    };
    return attempt;
  }
}
