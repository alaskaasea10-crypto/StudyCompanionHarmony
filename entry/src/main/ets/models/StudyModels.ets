export type StudyExperience = 'smooth' | 'normal' | 'struggling';

export interface StudyTask {
  id?: string;
  title: string;
  subject: string;
  minutes: number;
  completed: boolean;
  source?: string;
  createdAt?: number;
  completedAt?: number;
  goalId?: string;
  milestoneId?: string;
  outcome?: string;
  focusedAt?: number;
  submittedAt?: number;
  verifiedAt?: number;
  resultNote?: string;
  // 用户对本次学习体验的自述，不代表知识掌握度。
  studyExperience?: StudyExperience;
}

export interface ActionDeferral {
  key: string;
  until: number;
  kind: string;
}

// 只影响指定日期的调度；临时任务仍使用原 StudyTask 和稳定 taskId 保存。
export interface TodayStudyOverride {
  date: string;
  availableMinutes?: number;
  preferredTaskId?: string;
  preferredSubject?: string;
  skippedTaskIds?: string[];
  temporaryTaskIds?: string[];
}

export interface ScheduleItem {
  id: string;
  weekday: number;
  startTime: string;
  endTime: string;
  course: string;
  location: string;
}

export interface AcademicGoal {
  id: string;
  title: string;
  type: string;
  subject: string;
  deadline: string;
  estimatedMinutes: number;
  completed: boolean;
  createdAt: number;
  milestones?: GoalMilestone[];
}

export interface GoalMilestone {
  id: string;
  title: string;
  description: string;
  dueDate: string;
  minutes: number;
  completed: boolean;
}

export interface FocusRecord {
  id: string;
  taskId: string;
  taskTitle: string;
  subject: string;
  plannedMinutes: number;
  elapsedSeconds: number;
  completedAt: number;
  dayKey: string;
  completed?: boolean;
}

export interface QuizAttempt {
  id: string;
  questionId: string;
  subject: string;
  taskId?: string;
  knowledgePoint?: string;
  answer: string;
  correct: boolean;
  attemptedAt: number;
  dayKey: string;
}

export interface KnowledgeMastery {
  subject: string;
  knowledgePoint: string;
  score: number;
  attemptCount: number;
  correctCount: number;
  status: string;
  updatedAt: number;
}

export interface SquadMember {
  id: string;
  name: string;
  avatarText: string;
  accentColor: string;
  status: string;
  currentTask: string;
  todayMinutes: number;
  streakDays: number;
  isSelf: boolean;
  isDemo?: boolean;
  encouragementCount?: number;
  taskProgress?: number;
  lastQuietSignal?: string;
}

export interface StudyMetrics {
  completedTaskCount: number;
  totalTaskCount: number;
  planProgress: number;
  todayFocusMinutes: number;
  todayFocusSessionCount: number;
  quizAttemptCount: number;
  quizCorrectCount: number;
}

export interface StudyStateSnapshot {
  schemaVersion?: number;
  profileCompleted: boolean;
  profileAvatarUri?: string;
  profileName: string;
  profileGrade: string;
  profileMajor: string;
  profileGoal: string;
  profileSubject: string;
  profileExamDate: string;
  profileExamDateConfirmed?: boolean;
  profileDailyMinutes: number;
  profilePreferredTime: string;
  profileLearningStyle: string;
  profileSupportStyle: string;
  setupScheduleReady: boolean;
  tasks: StudyTask[];
  scheduleItems: ScheduleItem[];
  academicGoals?: AcademicGoal[];
  actionDeferrals?: ActionDeferral[];
  todayStudyOverride?: TodayStudyOverride;
  // 已永久删除的稳定 taskId；防止长期目标阶段任务在重启时被自动补回。
  deletedTaskIds?: string[];
  preferredTaskId?: string;
  currentTaskIndex: number;
  focusMinutes: number;
  remainingSeconds: number;
  isRunning: boolean;
  focusElapsedSeconds: number;
  focusSegmentStartedAt: number;
  focusSessionCredited: boolean;
  todayMinutes: number;
  studyDayKey: string;
  energyState: string;
  agentInput: string;
  agentGenerated: boolean;
  quizChoice: string;
  quizSubmitted: boolean;
  quizPending?: boolean;
  quizQuestionId?: string;
  quizFeedbackMessage?: string;
  focusRecords?: FocusRecord[];
  quizAttempts?: QuizAttempt[];
  knowledgeMastery?: KnowledgeMastery[];
  squadMessage?: string;
  squadMembers?: SquadMember[];
  squadInviteCode?: string;
  squadChallengeTitle?: string;
  squadChallengeMinutes?: number;
  squadChallengeJoinedCount?: number;
  squadChallengeActive?: boolean;
  notificationEnabled?: boolean;
  notificationClassEnabled?: boolean;
  notificationReviewEnabled?: boolean;
  notificationTaskEnabled?: boolean;
  notificationQuietHoursEnabled?: boolean;
  notificationQuietStart?: string;
  notificationQuietEnd?: string;
}

export function createDefaultSquadMembers(profileName: string): SquadMember[] {
  return [
    {
      id: 'self',
      name: profileName.trim().length > 0 ? profileName.trim() : '我',
      avatarText: '我',
      accentColor: '#5B5FEF',
      status: '准备开始',
      currentTask: '选择一项今日任务',
      todayMinutes: 0,
      streakDays: 11,
      isSelf: true,
      isDemo: false,
      encouragementCount: 0,
      taskProgress: 0,
      lastQuietSignal: ''
    },
    {
      id: 'demo-xiaoyu',
      name: '小雨',
      avatarText: '雨',
      accentColor: '#35C99A',
      status: '专注中',
      currentTask: '复习英语听力',
      todayMinutes: 38,
      streakDays: 7,
      isSelf: false,
      isDemo: true,
      encouragementCount: 2,
      taskProgress: 72,
      lastQuietSignal: ''
    },
    {
      id: 'demo-azhe',
      name: '阿哲',
      avatarText: '哲',
      accentColor: '#F2A65A',
      status: '休息中',
      currentTask: '数据结构课程设计',
      todayMinutes: 52,
      streakDays: 4,
      isSelf: false,
      isDemo: true,
      encouragementCount: 1,
      taskProgress: 36,
      lastQuietSignal: ''
    }
  ];
}

export function createDemoTasks(subject: string, dailyMinutes: number): StudyTask[] {
  const primaryMinutes: number = Math.min(25, Math.max(10, dailyMinutes));
  const createdAt: number = Date.now();
  return [
    {
      id: `profile-review-${createdAt}`,
      title: `回顾${subject}核心知识点`,
      subject: subject,
      minutes: primaryMinutes,
      completed: false,
      source: 'profile',
      createdAt: createdAt,
      completedAt: 0
    },
    {
      id: `profile-practice-${createdAt}`,
      title: `完成${subject}练习`,
      subject: subject,
      minutes: Math.min(30, Math.max(15, dailyMinutes - primaryMinutes)),
      completed: false,
      source: 'profile',
      createdAt: createdAt,
      completedAt: 0
    },
    {
      id: `profile-quiz-${createdAt}`,
      title: `整理${subject}学习收获`,
      subject: subject,
      minutes: 10,
      completed: false,
      source: 'profile',
      createdAt: createdAt,
      completedAt: 0
    },
    {
      id: `profile-notes-${createdAt}`,
      title: '复习今日课堂笔记',
      subject: '今日课程',
      minutes: 20,
      completed: false,
      source: 'profile',
      createdAt: createdAt,
      completedAt: 0
    }
  ];
}

export function createDemoSchedule(): ScheduleItem[] {
  return [
    {
      id: 'demo-math',
      weekday: 1,
      startTime: '08:00',
      endTime: '09:50',
      course: '高等数学',
      location: '教学楼 A203'
    },
    {
      id: 'demo-data-structure',
      weekday: 1,
      startTime: '14:00',
      endTime: '15:50',
      course: '数据结构实验',
      location: '实验楼 C301'
    }
  ];
}
