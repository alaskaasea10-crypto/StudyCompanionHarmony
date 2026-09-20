import { createDefaultSquadMembers, SquadMember } from '../models/StudyModels';

export class SquadService {
  static normalizeMembers(members: SquadMember[], profileName: string): SquadMember[] {
    const source: SquadMember[] = Array.isArray(members) && members.length > 0 ?
      members : createDefaultSquadMembers(profileName);
    const normalized: SquadMember[] = source.map((member: SquadMember, index: number) => {
      const normalizedMember: SquadMember = {
        id: member.id?.trim().length > 0 ? member.id : `member-${index}`,
        name: member.name?.trim().length > 0 ? member.name.trim() : `成员${index + 1}`,
        avatarText: member.avatarText?.trim().length > 0 ? member.avatarText.trim().slice(0, 1) : '伴',
        accentColor: member.accentColor?.trim().length > 0 ? member.accentColor : '#5B5FEF',
        status: member.status?.trim().length > 0 ? member.status : '离线',
        currentTask: member.currentTask?.trim().length > 0 ? member.currentTask : '暂未设置任务',
        todayMinutes: Math.max(0, member.todayMinutes ?? 0),
        streakDays: Math.max(0, member.streakDays ?? 0),
        isSelf: member.isSelf === true,
        isDemo: member.isDemo === true,
        encouragementCount: Math.max(0, member.encouragementCount ?? 0),
        taskProgress: Math.max(0, Math.min(100, member.taskProgress ?? (member.status === '专注中' ? 48 : 0))),
        lastQuietSignal: member.lastQuietSignal ?? ''
      };
      return normalizedMember;
    });
    if (!normalized.some((member: SquadMember) => member.isSelf)) {
      normalized.unshift(createDefaultSquadMembers(profileName)[0]);
    }
    return normalized.map((member: SquadMember) => {
      if (!member.isSelf) {
        return member;
      }
      const selfMember: SquadMember = {
        id: 'self',
        name: profileName.trim().length > 0 ? profileName.trim() : '我',
        avatarText: '我',
        accentColor: member.accentColor,
        status: member.status,
        currentTask: member.currentTask,
        todayMinutes: member.todayMinutes,
        streakDays: member.streakDays,
        isSelf: true,
        isDemo: false,
        encouragementCount: member.encouragementCount,
        taskProgress: member.taskProgress,
        lastQuietSignal: member.lastQuietSignal
      };
      return selfMember;
    });
  }

  static syncSelf(members: SquadMember[], profileName: string, todayMinutes: number,
    isRunning: boolean, currentTask: string, taskProgress: number = 0): SquadMember[] {
    return SquadService.normalizeMembers(members, profileName).map((member: SquadMember) => {
      if (!member.isSelf) {
        return member;
      }
      const selfMember: SquadMember = {
        id: member.id,
        name: profileName.trim().length > 0 ? profileName.trim() : '我',
        avatarText: member.avatarText,
        accentColor: member.accentColor,
        status: isRunning ? '专注中' : '准备开始',
        currentTask: currentTask.trim().length > 0 ? currentTask : '选择一项今日任务',
        todayMinutes: Math.max(0, todayMinutes),
        streakDays: member.streakDays,
        isSelf: true,
        isDemo: false,
        encouragementCount: member.encouragementCount,
        taskProgress: Math.max(0, Math.min(100, taskProgress)),
        lastQuietSignal: member.lastQuietSignal
      };
      return selfMember;
    });
  }

  static encourage(members: SquadMember[], memberId: string, signal: string = '加油'): SquadMember[] {
    return members.map((member: SquadMember) => {
      if (member.id !== memberId || member.isSelf) {
        return member;
      }
      const encouragedMember: SquadMember = {
        id: member.id,
        name: member.name,
        avatarText: member.avatarText,
        accentColor: member.accentColor,
        status: member.status,
        currentTask: member.currentTask,
        todayMinutes: member.todayMinutes,
        streakDays: member.streakDays,
        isSelf: member.isSelf,
        isDemo: member.isDemo,
        encouragementCount: Math.max(0, member.encouragementCount ?? 0) + 1,
        taskProgress: member.taskProgress,
        lastQuietSignal: signal
      };
      return encouragedMember;
    });
  }

  static focusingCount(members: SquadMember[]): number {
    return members.filter((member: SquadMember) => member.status === '专注中').length;
  }

  static inviteCode(profileName: string, timestamp: number = Date.now()): string {
    const seed: number = Array.from(profileName).reduce((total: number, value: string) => {
      return total + value.charCodeAt(0);
    }, 0);
    const suffix: number = (seed + Math.floor(timestamp / 1000)) % 10000;
    return `LIGHT-${suffix.toString().padStart(4, '0')}`;
  }
}
