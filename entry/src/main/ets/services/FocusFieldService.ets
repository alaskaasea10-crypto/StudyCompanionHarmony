import { SquadMember } from '../models/StudyModels';

export interface FocusStarProfile {
  richness: number;
  starCount: number;
  brightness: number;
  meteorInterval: number;
}

export class FocusFieldService {
  // 连续增长而非分档切换；长时间专注时逐渐趋于上限，避免画面过曝和粒子无限增加。
  static starProfile(collectiveMinutes: number): FocusStarProfile {
    const minutes: number = Number.isFinite(collectiveMinutes) ? Math.max(0, collectiveMinutes) : 0;
    const richness: number = 1 - Math.exp(-minutes / 150);
    return {
      richness: richness,
      starCount: 76 + richness * 224,
      brightness: 0.58 + richness * 0.42,
      meteorInterval: 24 - richness * 20
    };
  }

  static progress(value: number): number {
    return Math.max(0, Math.min(100, Math.round(value)));
  }

  static memberProgress(member: SquadMember): number {
    if (member.taskProgress !== undefined) {
      return FocusFieldService.progress(member.taskProgress);
    }
    return member.status === '专注中' ? 48 : 0;
  }
}
