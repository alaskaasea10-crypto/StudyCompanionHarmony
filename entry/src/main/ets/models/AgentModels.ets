import { FocusRecord, KnowledgeMastery, ScheduleItem, StudyTask, TodayStudyOverride } from './StudyModels';
import { BankLearningEvidence } from './QuestionBankModels';

export interface QuizFeedbackPayload {
  questionId: string;
  subject: string;
  knowledgePoint: string;
  correct: boolean;
  attemptedAt: number;
}

export interface AgentProfilePayload {
  name: string;
  grade: string;
  major: string;
  goal: string;
  subject: string;
  examDate: string;
  dailyMinutes: number;
  preferredTime: string;
  learningStyle: string;
  supportStyle: string;
}

export interface AgentContextPayload {
  bankTopicId?: string;
  bankAppendMode?: boolean;
  bankEvidence?: BankLearningEvidence[];
  date: string;
  examDays: number;
  energyState: string;
  // Only present when the user confirmed today's available time.
  availableMinutesToday?: number;
  todayStudyOverride?: TodayStudyOverride;
  localDailyPlanTaskIds?: string[];
  localDailyPlanMinutes?: number[];
  eligibleTaskIds?: string[];
  protectedTaskId?: string;
  protectedStage?: string;
  recentFocusRecords?: FocusRecord[];
  dailyTargetRemainingMinutes: number;
  appendMode?: boolean;
  scheduleReady: boolean;
  scheduleItems: ScheduleItem[];
  unfinishedTasks: StudyTask[];
  todayFocusMinutes: number;
  todayFocusSessionCount: number;
  quizAttemptCount: number;
  quizCorrectCount: number;
  recentQuizFeedback: QuizFeedbackPayload[];
  knowledgeMastery: KnowledgeMastery[];
}

export interface AgentPlanRequest {
  requestText: string;
  profile: AgentProfilePayload;
  context: AgentContextPayload;
}

export interface AgentGeneratedTask {
  taskId?: string;
  title: string;
  subject: string;
  type: string;
  minutes: number;
  priority: number;
  reason: string;
}

export interface AgentConversationMessage {
  id: string;
  role: string;
  text: string;
  mode: string;
  createdAt: number;
}

export interface AgentUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface AgentPlan {
  summary: string;
  detectedSubject: string;
  recommendationReasons: string[];
  tasks: AgentGeneratedTask[];
  totalMinutes: number;
  source: string;
  model: string;
  usage: AgentUsage;
  agentMode?: string;
  toolCalls?: string[];
  rounds?: number;
}

export interface AgentApiResponse {
  ok: boolean;
  plan?: AgentPlan;
  error?: string;
}

export interface PlanningDecision {
  plan: AgentPlan;
  notice: string;
}

export interface SmallPlanetConversationFact {
  role: string;
  text: string;
}

export interface SmallPlanetTaskFact {
  taskId: string;
  title: string;
  canonicalSubject: string;
  displaySubject: string;
  minutes: number;
  state: string;
}

export interface SmallPlanetPlanFact {
  taskId: string;
  title: string;
  displaySubject: string;
  minutes: number;
}

export interface SmallPlanetGoalFact {
  goalId: string;
  title: string;
  subject: string;
  deadline: string;
}

export interface SmallPlanetSemanticSubject {
  subject: string;
  reason: string;
}

export interface SmallPlanetSemanticAllocation {
  taskId: string;
  minutes: number;
}

export interface SmallPlanetUnderstanding {
  mode: string;
  intent: string;
  executionRequested: boolean;
  subjects: SmallPlanetSemanticSubject[];
  timeBudgetMinutes?: number;
  needsExplanation: boolean;
  confirmationRequired: boolean;
  allocation: SmallPlanetSemanticAllocation[];
}

export interface SmallPlanetReplyRequest {
  messageId: string;
  route: string;
  currentUserMessage: string;
  conversationContext: SmallPlanetConversationFact[];
  operationResult: string;
  persisted: boolean;
  canonicalSubject: string;
  remainingMinutes?: number;
  todayStudyOverride?: TodayStudyOverride;
  activeTasks: SmallPlanetTaskFact[];
  academicGoals: SmallPlanetGoalFact[];
  mentionedSubjects: string[];
  understandingRequested?: boolean;
  recommendedAction?: SmallPlanetPlanFact;
  dailyPlan: SmallPlanetPlanFact[];
  currentFocusTaskId?: string;
  pendingFeedbackTaskId?: string;
  confirmedScheduleSummary?: string;
  deterministicFallback: string;
}

export interface SmallPlanetReplyResponse {
  ok: boolean;
  reply?: string;
  source?: string;
  model?: string;
  understanding?: SmallPlanetUnderstanding;
  error?: string;
}

export interface PlanCommitResult {
  subject: string;
  tasks: StudyTask[];
  firstFocusMinutes: number;
  currentTaskIndex: number;
}

export interface QuizFeedbackResult {
  tasks: StudyTask[];
  message: string;
}

export interface QuizQuestion {
  id: string;
  subject: string;
  knowledgePoint: string;
  prompt: string;
  optionA: string;
  optionB: string;
  optionC: string;
  optionD: string;
  correctAnswer: string;
  explanation: string;
}
