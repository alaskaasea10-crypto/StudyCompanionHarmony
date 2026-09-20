import { AcademicGoal, KnowledgeMastery, ScheduleItem, StudyTask } from './StudyModels';
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
  academicGoals?: AcademicGoal[];
  bankTopicId?: string;
  bankAppendMode?: boolean;
  bankEvidence?: BankLearningEvidence[];
  date: string;
  examDays: number;
  energyState: string;
  availableMinutesToday: number;
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
