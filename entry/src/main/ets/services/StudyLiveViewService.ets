import { common, Want, WantAgent, wantAgent } from '@kit.AbilityKit';
import { liveViewManager } from '@kit.LiveViewKit';

const BUNDLE_NAME: string = 'com.dongxitonghang.studycompanion';
const FOCUS_LIVE_VIEW_ID: number = 23001;
const ACTIVE_STATUS: number = 1;

export class StudyLiveViewService {
  private static pending: Promise<void> = Promise.resolve();

  private static enqueue(operation: () => Promise<void>): void {
    StudyLiveViewService.pending = StudyLiveViewService.pending.then(operation).catch((error: Error) => {
      console.info(`StudyLiveView: unavailable (${error.message})`);
    });
  }

  private static async clickAction(): Promise<WantAgent> {
    const targetWant: Want = {
      bundleName: BUNDLE_NAME,
      abilityName: 'EntryAbility',
      parameters: {
        source: 'studyLiveView',
        target: 'focus',
        taskId: ''
      }
    };
    return await wantAgent.getWantAgent({
      wants: [targetWant],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: FOCUS_LIVE_VIEW_ID,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
  }

  private static async build(subject: string, remainingSeconds: number, paused: boolean,
    sequence: number): Promise<liveViewManager.LiveView> {
    const safeSubject: string = subject.trim().length > 0 ? subject.trim() : '学习任务';
    const timeMs: number = Math.max(0, remainingSeconds) * 1000;
    return {
      id: FOCUS_LIVE_VIEW_ID,
      event: 'TIMER',
      sequence: sequence,
      isMute: true,
      timer: {
        time: timeMs,
        isCountdown: true,
        isPaused: paused,
        countdownPreset: {
          presetTitle: '本轮专注完成',
          presetContent: '回到学伴记录结果'
        },
        capsuleCountdownPreset: {
          presetTitle: '完成',
          presetContent: '星球在等你'
        }
      },
      liveViewData: {
        primary: {
          title: paused ? '星球等你回来' : '星球陪你专注',
          content: [{ text: `${safeSubject} · ${paused ? '已暂停' : '专注中'}` }],
          keepTime: 0,
          clickAction: await StudyLiveViewService.clickAction(),
          layoutData: {
            layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PICKUP,
            title: '剩余时间',
            content: '${placeholder.timer}',
            underlineColor: '#FF8B7CC8',
            descPic: 'study_planet.svg'
          },
          extensionData: {
            type: liveViewManager.ExtensionType.EXTENSION_TYPE_DEFAULT
          }
        },
        capsule: {
          type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
          status: ACTIVE_STATUS,
          icon: 'study_planet.svg',
          backgroundColor: '#FF6D63B8',
          content: paused ? '已暂停' : '专注中',
          time: timeMs,
          isCountdown: true,
          isPaused: paused
        }
      }
    };
  }

  private static async active(): Promise<liveViewManager.LiveView | undefined> {
    try {
      return await liveViewManager.getActiveLiveView(FOCUS_LIVE_VIEW_ID);
    } catch (error) {
      return undefined;
    }
  }

  private static async sync(_context: common.UIAbilityContext, subject: string,
    remainingSeconds: number, paused: boolean): Promise<void> {
    if (!await liveViewManager.isLiveViewEnabled()) {
      return;
    }
    const active: liveViewManager.LiveView | undefined = await StudyLiveViewService.active();
    const sequence: number = (active?.sequence ?? 0) + 1;
    const view: liveViewManager.LiveView = await StudyLiveViewService.build(
      subject, remainingSeconds, paused, sequence
    );
    if (active === undefined) {
      await liveViewManager.startLiveView(view);
    } else {
      await liveViewManager.updateLiveView(view);
    }
  }

  static startOrResume(context: common.UIAbilityContext | undefined, subject: string,
    remainingSeconds: number): void {
    if (context === undefined || remainingSeconds <= 0) {
      return;
    }
    StudyLiveViewService.enqueue(async (): Promise<void> => {
      await StudyLiveViewService.sync(context, subject, remainingSeconds, false);
    });
  }

  static pause(context: common.UIAbilityContext | undefined, subject: string,
    remainingSeconds: number): void {
    if (context === undefined || remainingSeconds <= 0) {
      return;
    }
    StudyLiveViewService.enqueue(async (): Promise<void> => {
      await StudyLiveViewService.sync(context, subject, remainingSeconds, true);
    });
  }

  static stop(): void {
    StudyLiveViewService.enqueue(async (): Promise<void> => {
      const active: liveViewManager.LiveView | undefined = await StudyLiveViewService.active();
      if (active === undefined) {
        return;
      }
      active.sequence = (active.sequence ?? 0) + 1;
      active.isMute = true;
      active.timer = { isPaused: true };
      active.liveViewData.primary.title = '本轮专注已结束';
      active.liveViewData.primary.content = [{ text: '回到学伴记录学习结果' }];
      active.liveViewData.primary.keepTime = 0;
      active.liveViewData.capsule = {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
        status: ACTIVE_STATUS,
        icon: 'study_planet.svg',
        backgroundColor: '#FF6D63B8',
        title: '星球',
        content: '专注完成'
      };
      await liveViewManager.stopLiveView(active);
    });
  }
}
