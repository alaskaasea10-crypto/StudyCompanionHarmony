import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { StudyMetrics, StudyStateSnapshot, StudyTask } from '../models/StudyModels';
import { StudyDataCenter } from './StudyDataCenter';
import { DailyActionService } from './DailyActionService';
import { AgentDecisionService } from './AgentDecisionService';
import { GoalPlanningService } from './GoalPlanningService';

const STUDY_STORE_NAME: string = 'learner_profile';
const STUDY_STATE_KEY: string = 'study_state_v1';
const WIDGET_STORE_NAME: string = 'study_widget_forms';
const WIDGET_FORM_IDS_KEY: string = 'form_ids';

export class StudyWidgetData {
  appName: string = '学伴';
  eyebrow: string = '星球提醒';
  taskTitle: string = '准备好了吗？一起学一点。';
  subject: string = '学习任务';
  minutesText: string = '轻轻开始';
  examText: string = '等待设置考试';
  progressText: string = '0/0';
  progressPercent: string = '0%';
  actionText: string = '打开学伴';
  target: string = 'home';
  taskId: string = '';
}

export class StudyWidgetService {
  private static examDays(examDate: string): number {
    const examTime: number = new Date(`${examDate}T00:00:00+08:00`).getTime();
    if (Number.isNaN(examTime)) {
      return 0;
    }
    const beijingNow: Date = new Date(Date.now() + 8 * 60 * 60 * 1000);
    const today: string = `${beijingNow.getUTCFullYear()}-${(beijingNow.getUTCMonth() + 1)
      .toString().padStart(2, '0')}-${beijingNow.getUTCDate().toString().padStart(2, '0')}`;
    const todayTime: number = new Date(`${today}T00:00:00+08:00`).getTime();
    return Math.max(0, Math.ceil((examTime - todayTime) / 86400000));
  }

  static fromSnapshot(snapshot: StudyStateSnapshot): StudyWidgetData {
    const data: StudyWidgetData = new StudyWidgetData();
    if (!snapshot.profileCompleted) { return data; }
    const tasks: StudyTask[] = Array.isArray(snapshot.tasks) ? snapshot.tasks : [];
    const action = AgentDecisionService.decide(snapshot).recommendedAction;
    data.subject = action.subject;
    data.taskTitle = action.headline;
    data.minutesText = action.minutes > 0 ? '约 ' + action.minutes + ' 分钟' : '休息一下';
    data.actionText = action.actionTitle;
    // 点击时用最新档案重新判断，避免旧卡片重开已完成任务。
    data.target = action.stage === 'done' || action.stage === 'wait' ? 'home' : 'next';
    return data;
  }

  static async forSnapshot(context: Context, snapshot: StudyStateSnapshot): Promise<StudyWidgetData> {
    return StudyWidgetService.fromSnapshot(snapshot);
  }

  static bindingData(data: StudyWidgetData): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(data);
  }

  static async loadStudyData(context: Context): Promise<StudyWidgetData> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, STUDY_STORE_NAME);
      const raw: string = await store.get(STUDY_STATE_KEY, '') as string;
      if (raw.length === 0) {
        return new StudyWidgetData();
      }
      const snapshot: StudyStateSnapshot = JSON.parse(raw) as StudyStateSnapshot;
      return await StudyWidgetService.forSnapshot(context, snapshot);
    } catch (error) {
      console.error(`StudyWidgetService: unable to load study data: ${error}`);
      return new StudyWidgetData();
    }
  }

  private static async formStore(context: Context): Promise<preferences.Preferences> {
    try {
      return await preferences.getPreferences(context, WIDGET_STORE_NAME);
    } catch (error) {
      console.error(`StudyWidgetService: unable to open widget storage: ${error}`);
      throw new Error('Unable to open widget storage');
    }
  }

  static async formIds(context: Context): Promise<string[]> {
    try {
      const store: preferences.Preferences = await StudyWidgetService.formStore(context);
      const raw: string = await store.get(WIDGET_FORM_IDS_KEY, '[]') as string;
      const parsed: string[] = JSON.parse(raw) as string[];
      return Array.isArray(parsed) ? parsed.filter((formId: string) => formId.length > 0) : [];
    } catch (error) {
      console.error(`StudyWidgetService: unable to load form ids: ${error}`);
      return [];
    }
  }

  static async registerForm(context: Context, formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    try {
      const store: preferences.Preferences = await StudyWidgetService.formStore(context);
      const ids: string[] = await StudyWidgetService.formIds(context);
      if (!ids.includes(formId)) {
        await store.put(WIDGET_FORM_IDS_KEY, JSON.stringify(ids.concat([formId])));
        await store.flush();
      }
    } catch (error) {
      console.error(`StudyWidgetService: unable to register form ${formId}: ${error}`);
    }
  }

  static async removeForm(context: Context, formId: string): Promise<void> {
    try {
      const store: preferences.Preferences = await StudyWidgetService.formStore(context);
      const ids: string[] = await StudyWidgetService.formIds(context);
      await store.put(WIDGET_FORM_IDS_KEY, JSON.stringify(ids.filter((id: string) => id !== formId)));
      await store.flush();
    } catch (error) {
      console.error(`StudyWidgetService: unable to remove form ${formId}: ${error}`);
    }
  }

  static async refreshForm(context: Context, formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    try {
      const data: StudyWidgetData = await StudyWidgetService.loadStudyData(context);
      await formProvider.updateForm(formId, StudyWidgetService.bindingData(data));
    } catch (error) {
      console.error(`StudyWidgetService: unable to refresh form ${formId}: ${error}`);
    }
  }

  static async updateAll(context: Context, snapshot: StudyStateSnapshot): Promise<void> {
    const ids: string[] = await StudyWidgetService.formIds(context);
    if (ids.length === 0) {
      return;
    }
    const binding: formBindingData.FormBindingData = StudyWidgetService.bindingData(
      await StudyWidgetService.forSnapshot(context, snapshot));
    for (let index: number = 0; index < ids.length; index++) {
      try {
        await formProvider.updateForm(ids[index], binding);
      } catch (error) {
        console.error(`StudyWidgetService: unable to update form ${ids[index]}: ${error}`);
      }
    }
  }

  static async clearPrivateData(context: Context): Promise<void> {
    const ids: string[] = await StudyWidgetService.formIds(context);
    const binding = StudyWidgetService.bindingData(new StudyWidgetData());
    for (const id of ids) { await formProvider.updateForm(id, binding); }
  }
}
