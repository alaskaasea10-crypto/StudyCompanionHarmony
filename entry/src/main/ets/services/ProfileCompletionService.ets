import { StudyStateSnapshot } from '../models/StudyModels';

export class ProfileCompletionService {
  private static text(value: string | undefined): boolean {
    return typeof value === 'string' && value.trim().length > 0;
  }

  // 显式 false 必须保留：它代表全新用户或尚未完成的设置流程。
  // 只有旧快照完全没有 profileCompleted 时，才按足够完整的历史证据迁移。
  static completed(snapshot: StudyStateSnapshot): boolean {
    if (snapshot.profileCompleted === true) { return true; }
    if (snapshot.profileCompleted === false) { return false; }
    const hasIdentity: boolean = ProfileCompletionService.text(snapshot.profileName) &&
      ProfileCompletionService.text(snapshot.profileMajor);
    const hasGoal: boolean = ProfileCompletionService.text(snapshot.profileSubject) &&
      ProfileCompletionService.text(snapshot.profileExamDate);
    const hasRhythm: boolean = Number.isFinite(snapshot.profileDailyMinutes) && snapshot.profileDailyMinutes > 0 &&
      ProfileCompletionService.text(snapshot.profilePreferredTime);
    const hasLearningData: boolean = (snapshot.academicGoals?.length ?? 0) > 0 || (snapshot.tasks?.length ?? 0) > 0;
    return hasIdentity && hasGoal && hasRhythm && hasLearningData;
  }
}
