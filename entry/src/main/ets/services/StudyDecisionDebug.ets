import { DEBUG } from 'BuildProfile';

export interface StudyDecisionDebugAction {
  taskId?: string;
  subject: string;
  headline: string;
  minutes: number;
  stage: string;
}

export interface StudyDecisionDebugPlanItem {
  order: number;
  taskId: string;
  subject: string;
  title: string;
  suggestedMinutes: number;
}

interface StudyDecisionDebugRecommended {
  taskId: string;
  subject: string;
  title: string;
  suggestedMinutes: number;
  stage: string;
}

interface StudyDecisionDebugPayload {
  recommendedAction: StudyDecisionDebugRecommended;
  dailyPlan: StudyDecisionDebugPlanItem[];
}

interface StudyDecisionDebugEventPayload {
  event: string;
  taskId: string;
  subject: string;
  title: string;
  detail: string;
}

export class StudyDecisionDebug {
  private static lastDecision: string = '';

  static decision(action: StudyDecisionDebugAction, dailyPlan: StudyDecisionDebugPlanItem[]): void {
    if (!DEBUG) { return; }
    const recommended: StudyDecisionDebugRecommended = {
        taskId: action.taskId ?? '', subject: action.subject, title: action.headline,
        suggestedMinutes: action.minutes, stage: action.stage
    };
    const payloadValue: StudyDecisionDebugPayload = {
      recommendedAction: recommended, dailyPlan: dailyPlan
    };
    const payload: string = JSON.stringify(payloadValue);
    if (payload === StudyDecisionDebug.lastDecision) { return; }
    StudyDecisionDebug.lastDecision = payload;
    // BuildProfile.DEBUG 由 Hvigor 针对构建模式生成；Release 不构造或输出学习详情。
    console.debug(`[StudyDecisionDebug] ${payload}`);
  }

  static event(name: string, taskId: string, subject: string = '', title: string = '', detail: string = ''): void {
    if (!DEBUG) { return; }
    const payload: StudyDecisionDebugEventPayload = {
      event: name, taskId: taskId, subject: subject, title: title, detail: detail
    };
    console.debug(`[StudyDecisionDebug] ${JSON.stringify(payload)}`);
  }
}
