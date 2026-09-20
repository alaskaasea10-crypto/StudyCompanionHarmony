import { common, Want, WantAgent, wantAgent } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { StudyWidgetService } from './StudyWidgetService';
import { notificationManager } from '@kit.NotificationKit';
import { ScheduleItem, StudyStateSnapshot, StudyTask } from '../models/StudyModels';

const BUNDLE_NAME: string = 'com.dongxitonghang.studycompanion';
const STATE_STORE_NAME: string = 'learner_profile';
const STATE_KEY: string = 'study_state_v1';
const REMINDER_STORE_NAME: string = 'active_reminder_state';
const LAST_FINGERPRINT_KEY: string = 'last_fingerprint';
const LAST_PUBLISHED_AT_KEY: string = 'last_published_at';
const ACTIVE_REMINDER_NOTIFICATION_ID: number = 21001;
const TEST_NOTIFICATION_ID: number = 21002;

export interface ActiveReminderCandidate {
  kind: string;
  title: string;
  text: string;
  target: string;
  taskId: string;
  fingerprint: string;
}

export interface NotificationResult {
  success: boolean;
  message: string;
}

export class ActiveReminderPolicy {
  private static timeMinutes(value: string): number {
    const pieces: string[] = value.split(':');
    if (pieces.length !== 2) {
      return -1;
    }
    const hours: number = Number(pieces[0]);
    const minutes: number = Number(pieces[1]);
    if (!Number.isInteger(hours) || !Number.isInteger(minutes) || hours < 0 || hours > 23 ||
      minutes < 0 || minutes > 59) {
      return -1;
    }
    return hours * 60 + minutes;
  }

  private static beijingNow(): Date {
    return new Date(Date.now() + 8 * 60 * 60 * 1000);
  }

  static isQuietTime(snapshot: StudyStateSnapshot, now: Date = ActiveReminderPolicy.beijingNow()): boolean {
    if (snapshot.notificationQuietHoursEnabled !== true) {
      return false;
    }
    const currentMinutes: number = now.getUTCHours() * 60 + now.getUTCMinutes();
    const quietStart: number = ActiveReminderPolicy.timeMinutes(snapshot.notificationQuietStart ?? '22:30');
    const quietEnd: number = ActiveReminderPolicy.timeMinutes(snapshot.notificationQuietEnd ?? '07:30');
    if (quietStart < 0 || quietEnd < 0) {
      return false;
    }
    return quietStart <= quietEnd ? currentMinutes >= quietStart && currentMinutes < quietEnd :
      currentMinutes >= quietStart || currentMinutes < quietEnd;
  }

  private static classCandidate(snapshot: StudyStateSnapshot, now: Date): ActiveReminderCandidate | undefined {
    if (snapshot.notificationClassEnabled !== true || !Array.isArray(snapshot.scheduleItems)) {
      return undefined;
    }
    const weekday: number = now.getUTCDay() === 0 ? 7 : now.getUTCDay();
    const nowMinutes: number = now.getUTCHours() * 60 + now.getUTCMinutes();
    const todayItems: ScheduleItem[] = snapshot.scheduleItems.filter((item: ScheduleItem) => item.weekday === weekday);
    for (let index: number = 0; index < todayItems.length; index++) {
      const item: ScheduleItem = todayItems[index];
      const startMinutes: number = ActiveReminderPolicy.timeMinutes(item.startTime);
      const minutesUntil: number = startMinutes - nowMinutes;
      if (minutesUntil >= 0 && minutesUntil <= 30) {
        return {
          kind: 'class',
          title: `${item.course}还有${minutesUntil}分钟开始`,
          text: item.location.length > 0 ? `上课地点：${item.location}，记得提前出发。` : '记得带好资料，提前进入学习状态。',
          target: 'home',
          taskId: '',
          fingerprint: `class-${item.id}-${item.startTime}`
        };
      }
    }
    return undefined;
  }

  private static reviewCandidate(snapshot: StudyStateSnapshot, now: Date): ActiveReminderCandidate | undefined {
    if (snapshot.notificationReviewEnabled !== true || !Array.isArray(snapshot.scheduleItems)) {
      return undefined;
    }
    const weekday: number = now.getUTCDay() === 0 ? 7 : now.getUTCDay();
    const nowMinutes: number = now.getUTCHours() * 60 + now.getUTCMinutes();
    const todayItems: ScheduleItem[] = snapshot.scheduleItems.filter((item: ScheduleItem) => item.weekday === weekday);
    for (let index: number = 0; index < todayItems.length; index++) {
      const item: ScheduleItem = todayItems[index];
      const endMinutes: number = ActiveReminderPolicy.timeMinutes(item.endTime);
      const elapsed: number = nowMinutes - endMinutes;
      if (elapsed >= 10 && elapsed <= 120) {
        return {
          kind: 'review',
          title: `趁热回顾${item.course}`,
          text: '课堂结束不久，建议用20分钟整理笔记和关键问题。',
          target: 'home',
          taskId: '',
          fingerprint: `review-${item.id}-${item.endTime}`
        };
      }
    }
    return undefined;
  }

  private static taskCandidate(snapshot: StudyStateSnapshot): ActiveReminderCandidate | undefined {
    if (snapshot.notificationTaskEnabled !== true || !Array.isArray(snapshot.tasks)) {
      return undefined;
    }
    const task: StudyTask | undefined = snapshot.tasks.find((item: StudyTask) => !item.completed);
    if (task === undefined) {
      return undefined;
    }
    return {
      kind: 'task',
      title: `下一步：${task.title}`,
      text: `Agent已结合你的画像整理好${task.minutes}分钟任务，点击直接进入专注空间。`,
      target: 'focus',
      taskId: task.id ?? '',
      fingerprint: `task-${task.id ?? task.title}-${task.completed === true ? 'done' : 'todo'}`
    };
  }

  static choose(snapshot: StudyStateSnapshot, bypassQuietHours: boolean = false): ActiveReminderCandidate | undefined {
    if (snapshot.notificationEnabled !== true || snapshot.isRunning === true) {
      return undefined;
    }
    const now: Date = ActiveReminderPolicy.beijingNow();
    if (!bypassQuietHours && ActiveReminderPolicy.isQuietTime(snapshot, now)) {
      return undefined;
    }
    return ActiveReminderPolicy.classCandidate(snapshot, now) ??
      ActiveReminderPolicy.reviewCandidate(snapshot, now) ??
      ActiveReminderPolicy.taskCandidate(snapshot);
  }
}

export class ActiveReminderService {
  static async cancelActive(): Promise<void> {
    try { await notificationManager.cancel(ACTIVE_REMINDER_NOTIFICATION_ID); } catch (error) {
      console.info('ActiveReminder: no active notification to cancel');
    }
  }
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      console.error(`ActiveReminderService: notification permission failed: ${error}`);
      return false;
    }
  }

  private static async createWantAgent(candidate: ActiveReminderCandidate,
    requestCode: number): Promise<WantAgent> {
    const targetWant: Want = {
      bundleName: BUNDLE_NAME,
      abilityName: 'EntryAbility',
      parameters: {
        source: 'studyNotification',
        target: candidate.target,
        taskId: candidate.taskId
      }
    };
    try {
      return await wantAgent.getWantAgent({
        wants: [targetWant],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: requestCode,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
    } catch (error) {
      console.error(`ActiveReminderService: unable to create notification route: ${error}`);
      throw new Error('Unable to create notification route');
    }
  }

  private static async publish(candidate: ActiveReminderCandidate, notificationId: number): Promise<void> {
    const targetAgent: WantAgent = await ActiveReminderService.createWantAgent(candidate, notificationId);
    const request: notificationManager.NotificationRequest = {
      id: notificationId,
      label: 'study-active-service',
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      tapDismissed: true,
      wantAgent: targetAgent,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: candidate.title,
          text: candidate.text,
          additionalText: '学伴 · Agent主动服务'
        }
      }
    };
    try {
      await notificationManager.publish(request);
    } catch (error) {
      console.error(`ActiveReminderService: unable to publish notification: ${error}`);
      throw new Error('Unable to publish notification');
    }
  }

  private static async loadSnapshot(context: common.UIAbilityContext): Promise<StudyStateSnapshot | undefined> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, STATE_STORE_NAME);
      const raw: string = await store.get(STATE_KEY, '') as string;
      return raw.length > 0 ? JSON.parse(raw) as StudyStateSnapshot : undefined;
    } catch (error) {
      console.error(`ActiveReminderService: unable to load state: ${error}`);
      return undefined;
    }
  }

  private static async isDuplicate(context: common.UIAbilityContext, fingerprint: string): Promise<boolean> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, REMINDER_STORE_NAME);
      const previousFingerprint: string = await store.get(LAST_FINGERPRINT_KEY, '') as string;
      const previousTime: number = await store.get(LAST_PUBLISHED_AT_KEY, 0) as number;
      return previousFingerprint === fingerprint && Date.now() - previousTime < 30 * 60 * 1000;
    } catch (error) {
      console.error(`ActiveReminderService: unable to check duplicate reminder: ${error}`);
      return false;
    }
  }

  private static async markPublished(context: common.UIAbilityContext, fingerprint: string): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, REMINDER_STORE_NAME);
      await store.put(LAST_FINGERPRINT_KEY, fingerprint);
      await store.put(LAST_PUBLISHED_AT_KEY, Date.now());
      await store.flush();
    } catch (error) {
      console.error(`ActiveReminderService: unable to persist reminder state: ${error}`);
    }
  }

  static async publishFromStoredState(context: common.UIAbilityContext): Promise<NotificationResult> {
    const snapshot: StudyStateSnapshot | undefined = await ActiveReminderService.loadSnapshot(context);
    if (snapshot === undefined || snapshot.notificationEnabled !== true) {
      return { success: false, message: '主动提醒未开启' };
    }
    let candidate: ActiveReminderCandidate | undefined = ActiveReminderPolicy.choose(snapshot);
    if (snapshot.isRunning || ActiveReminderPolicy.isQuietTime(snapshot)) {
      await ActiveReminderService.cancelActive();
      return { success: false, message: '专注或免打扰期间不发送提醒' };
    }
    if (candidate === undefined && snapshot.notificationTaskEnabled === true) {
      candidate = { kind: 'task', title: '', text: '', target: 'next', taskId: '', fingerprint: '' };
    }
    if (candidate === undefined) {
      return { success: false, message: '当前没有需要提醒的事项' };
    }
    {
      const next = await StudyWidgetService.forSnapshot(context, snapshot);
      if (next.target !== 'next' || snapshot.isRunning) {
        await ActiveReminderService.cancelActive();
        return { success: false, message: '当前没有需要提醒的行动' };
      }
      candidate.title = '星球提醒';
      candidate.text = `${next.taskTitle} · ${next.minutesText}`;
      candidate.target = 'next';
      candidate.taskId = '';
      candidate.fingerprint = `planet-${next.taskTitle}`;
    }
    if (await ActiveReminderService.isDuplicate(context, candidate.fingerprint)) {
      return { success: false, message: '相同提醒已发送，暂不重复打扰' };
    }
    try {
      if (!await ActiveReminderService.requestPermission(context)) {
        return { success: false, message: '请先允许学伴发送系统通知' };
      }
      await ActiveReminderService.publish(candidate, ACTIVE_REMINDER_NOTIFICATION_ID);
      await ActiveReminderService.markPublished(context, candidate.fingerprint);
      return { success: true, message: 'Agent主动提醒已发送' };
    } catch (error) {
      console.error(`ActiveReminderService: unable to publish active reminder: ${error}`);
      return { success: false, message: '系统通知发送失败，请稍后重试' };
    }
  }

  static async publishTest(context: common.UIAbilityContext,
    snapshot: StudyStateSnapshot): Promise<NotificationResult> {
    const candidate: ActiveReminderCandidate | undefined = ActiveReminderPolicy.choose(snapshot, true);
    const testCandidate: ActiveReminderCandidate = candidate ?? {
      kind: 'test',
      title: '星球来报到啦',
      text: '我会在合适的时候，提醒你下一步做什么。',
      target: 'home',
      taskId: '',
      fingerprint: `test-${Date.now()}`
    };
    try {
      if (!await ActiveReminderService.requestPermission(context)) {
        return { success: false, message: '通知权限未开启，请在系统设置中允许学伴通知' };
      }
      await ActiveReminderService.publish(testCandidate, TEST_NOTIFICATION_ID);
      return { success: true, message: '测试通知已发送，点击可返回对应任务' };
    } catch (error) {
      console.error(`ActiveReminderService: unable to publish test notification: ${error}`);
      return { success: false, message: '测试通知发送失败，请检查系统通知权限' };
    }
  }
}
