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

interface SmallPlanetTracePayload {
  messageId: string;
  route: string;
  intentKind: string;
  canonicalSubject: string;
  panguRequested: boolean;
  panguSucceeded: boolean;
  panguLatencyMs: number;
  panguResponseValidated: boolean;
  replySource: string;
  selectedTaskId: string;
  persisted: boolean;
  validatorResult: string;
}

interface SmallPlanetRouterTracePayload {
  messageId: string;
  routerDecision: string;
  deterministicEligible: boolean;
  deterministicConfidence: string;
  semanticRoute: string;
  panguUnderstandingRequested: boolean;
  panguUnderstandingSucceeded: boolean;
  executionRequested: boolean;
  confirmationRequired: boolean;
  subjects: string[];
  timeBudgetMinutes?: number;
  selectedTaskIds: string[];
  persistAttempted: boolean;
  persisted: boolean;
  panguReplyRequested: boolean;
  panguReplySucceeded: boolean;
  replySource: string;
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

  static candidates(ids: string[]): void {
    if (!DEBUG) { return; }
    console.debug(`[StudyDecisionDebug] CANDIDATES ${JSON.stringify(ids)}`);
  }

  static smallPlanet(payload: SmallPlanetTracePayload): void {
    if (!DEBUG) { return; }
    console.debug(`[SMALL_PLANET_TRACE] ${JSON.stringify(payload)}`);
  }

  static smallPlanetRouter(payload: SmallPlanetRouterTracePayload): void {
    if (!DEBUG) { return; }
    console.debug(`[SMALL_PLANET_ROUTER] ${JSON.stringify(payload)}`);
  }
}
