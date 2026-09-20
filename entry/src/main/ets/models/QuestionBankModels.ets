export interface BankQuestion {
  id: string;
  skill: string;
  prompt: string;
  options: string[];
  answer: number;
  explanation: string;
  hints: string[];
}

export interface BankSession {
  id: string;
  startedAt: number;
  questionIds: string[];
  answers: number[];
}

export interface BankState {
  version: number;
  sessions: BankSession[];
}

export interface SkillEvidence {
  skill: string;
  status: string;
  correct: number;
  total: number;
  review: string;
}

export interface BankLearningEvidence {
  topicId?: string;
  knowledgePointId: string;
  subject: string;
  knowledgePoint: string;
  status: string;
  distinctQuestions: number;
  latestCorrect: number;
  sessionStartedAt: number;
}

export interface BankTopic {
  id: string;
  title: string;
  subject: string;
  prefix: string;
  skills: string[];
  keys: string[];
  reviews: string[];
  videoModule: string;
}
