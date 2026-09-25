import { ActionDeferral, StudyTask, TodayStudyOverride } from '../models/StudyModels';

export interface StudyTaskDeletionResult {
  tasks: StudyTask[];
  todayStudyOverride: TodayStudyOverride;
  actionDeferrals: ActionDeferral[];
  deletedTaskIds: string[];
}

// 删除只处理已有任务身份及其引用；持久化和界面状态由 Index 统一负责。
export class StudyTaskDeletionService {
  static blockReason(task: StudyTask | undefined, currentTaskId: string, hasActiveFocusSession: boolean): string {
    if (task === undefined || task.id === undefined || task.id.length === 0) {
      return '这个待办已经不存在';
    }
    if (hasActiveFocusSession && task.id === currentTaskId) {
      return '这个待办正在专注中，请先结束本轮专注。';
    }
    if (!task.completed && (task.outcome === 'focused' || task.outcome === 'submitted')) {
      return '先记录本轮学习反馈，再管理这个待办。';
    }
    return '';
  }

  static remove(taskId: string, tasks: StudyTask[], todayStudyOverride: TodayStudyOverride,
    actionDeferrals: ActionDeferral[], deletedTaskIds: string[]): StudyTaskDeletionResult {
    const remainingTasks: StudyTask[] = tasks.filter((task: StudyTask) => task.id !== taskId);
    const override: TodayStudyOverride = {
      date: todayStudyOverride.date,
      availableMinutes: todayStudyOverride.availableMinutes,
      preferredTaskId: todayStudyOverride.preferredTaskId === taskId ? '' : todayStudyOverride.preferredTaskId,
      preferredSubject: todayStudyOverride.preferredSubject,
      skippedTaskIds: (todayStudyOverride.skippedTaskIds ?? []).filter((id: string) => id !== taskId),
      temporaryTaskIds: (todayStudyOverride.temporaryTaskIds ?? []).filter((id: string) => id !== taskId)
    };
    return {
      tasks: remainingTasks,
      todayStudyOverride: override,
      actionDeferrals: actionDeferrals.filter((item: ActionDeferral) => item.key !== `task:${taskId}`),
      deletedTaskIds: Array.from(new Set(deletedTaskIds.concat([taskId])))
    };
  }
}
