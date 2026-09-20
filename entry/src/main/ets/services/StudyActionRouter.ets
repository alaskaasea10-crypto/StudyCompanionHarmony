import { Want } from '@kit.AbilityKit';

export interface StudyExternalAction {
  source: string;
  target: string;
  taskId: string;
  requestedAt: number;
}

/**
 * 所有系统入口只传递“用户想做什么”，页面跳转与学习状态判断统一由 Index 执行。
 * 这样桌面卡片、通知、实况窗和后续的小艺意图不会各自维护一套页面编号。
 */
export class StudyActionRouter {
  private static supportedSource(source: string): boolean {
    return ['studyWidget', 'studyNotification', 'studyLiveView', 'studyIntent'].includes(source);
  }

  private static normalizeTarget(target: string): string {
    if (['home', 'next', 'focus', 'schedule', 'learning', 'support'].includes(target)) {
      return target;
    }
    return 'home';
  }

  static fromWant(want: Want): string {
    const uri: string = want.uri ?? '';
    const routePrefix: string = 'studycompanion://action/';
    const deepLink: boolean = uri.startsWith(routePrefix);
    const source: string = deepLink ? 'studyIntent' : `${want.parameters?.source ?? ''}`;
    if (!StudyActionRouter.supportedSource(source)) {
      return '';
    }
    const action: StudyExternalAction = {
      source: source,
      target: StudyActionRouter.normalizeTarget(deepLink ? uri.substring(routePrefix.length).split('?')[0] :
        `${want.parameters?.target ?? 'home'}`),
      taskId: `${want.parameters?.taskId ?? ''}`,
      requestedAt: Date.now()
    };
    return JSON.stringify(action);
  }

  static parse(routeJson: string): StudyExternalAction | undefined {
    if (routeJson.length === 0) {
      return undefined;
    }
    try {
      const raw: StudyExternalAction = JSON.parse(routeJson) as StudyExternalAction;
      if (!StudyActionRouter.supportedSource(raw.source ?? '')) {
        return undefined;
      }
      return {
        source: raw.source,
        target: StudyActionRouter.normalizeTarget(raw.target ?? 'home'),
        taskId: raw.taskId ?? '',
        requestedAt: Math.max(0, raw.requestedAt ?? 0)
      };
    } catch (error) {
      return undefined;
    }
  }
}
