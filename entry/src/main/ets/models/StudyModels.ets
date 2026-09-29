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
export interface TodayIntent {
  subject?: string;
  taskId?: string;
  requestedMinutes?: number;
  // budget 是从现在起的剩余预算；task 只约束当前行动，不冒充全天空闲。
  minutesKind?: string;
  topic?: string;
  activity?: string;
  action: string;
  scope: string;
  source: string;
}

export interface TodayStudyOverride {
  date: string;
  intent?: TodayIntent;
  // 持久层兼容字段：当天总预算。界面输入“接下来时长”时在保存边界换算为 已专注 + 追加分钟。
  availableMinutes?: number;
  preferredTaskId?: string;
  preferredSubject?: string;
  skippedTaskIds?: string[];
  temporaryTaskIds?: string[];
  // 仅保存通过 PlanValidator 的真实任务建议；用户选择与状态保护仍优先。
  suggestedTaskIds?: string[];
  suggestedTaskMinutes?: number[];
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
  // 旧版快照可能没有这个字段；加载时由 ProfileCompletionService 做一次兼容判断。
  profileCompleted?: boolean;
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
  // 已永久删除的稳定 taskId；用于清理今日覆盖、延期等仍可能引用旧任务的状态。
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
  // 当前仅为本机演示状态，不代表已连接真实多人服务器。
  squadJoined?: boolean;
  squadName?: string;
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
      status: '稍后学习',
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
      title: `复习${subject}课堂笔记`,
      subject: subject,
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
      id: 'demo-schedule-mon-math',
      weekday: 1,
      startTime: '08:00',
      endTime: '09:40',
      course: '高等数学',
      location: '教学楼 A203'
    },
    {
      id: 'demo-schedule-mon-english',
      weekday: 1,
      startTime: '10:00',
      endTime: '11:40',
      course: '大学英语',
      location: '教学楼 B105'
    },
    {
      id: 'demo-schedule-mon-programming',
      weekday: 1,
      startTime: '14:00',
      endTime: '15:40',
      course: '程序设计基础',
      location: '实验楼 C301'
    },
    {
      id: 'demo-schedule-tue-linear',
      weekday: 2,
      startTime: '10:00',
      endTime: '11:40',
      course: '线性代数',
      location: '教学楼 A305'
    },
    {
      id: 'demo-schedule-tue-physics',
      weekday: 2,
      startTime: '14:00',
      endTime: '15:40',
      course: '大学物理',
      location: '理科楼 B201'
    },
    {
      id: 'demo-schedule-wed-english',
      weekday: 3,
      startTime: '08:00',
      endTime: '09:40',
      course: '大学英语',
      location: '教学楼 B105'
    },
    {
      id: 'demo-schedule-wed-math',
      weekday: 3,
      startTime: '14:00',
      endTime: '15:40',
      course: '高等数学',
      location: '教学楼 A203'
    },
    {
      id: 'demo-schedule-wed-pe',
      weekday: 3,
      startTime: '16:00',
      endTime: '17:40',
      course: '体育',
      location: '东区操场'
    },
    {
      id: 'demo-schedule-thu-linear',
      weekday: 4,
      startTime: '08:00',
      endTime: '09:40',
      course: '线性代数',
      location: '教学楼 A305'
    },
    {
      id: 'demo-schedule-thu-programming',
      weekday: 4,
      startTime: '10:00',
      endTime: '11:40',
      course: '程序设计基础',
      location: '实验楼 C301'
    },
    {
      id: 'demo-schedule-thu-politics',
      weekday: 4,
      startTime: '14:00',
      endTime: '15:40',
      course: '思想政治理论',
      location: '人文楼 D102'
    },
    {
      id: 'demo-schedule-fri-math',
      weekday: 5,
      startTime: '10:00',
      endTime: '11:40',
      course: '高等数学',
      location: '教学楼 A203'
    },
    {
      id: 'demo-schedule-fri-english',
      weekday: 5,
      startTime: '14:00',
      endTime: '15:40',
      course: '大学英语',
      location: '教学楼 B105'
    }
  ];
}
