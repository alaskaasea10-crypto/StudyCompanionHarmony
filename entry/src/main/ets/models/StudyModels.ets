export interface StudyTask {
  id?: string;
  title: string;
  subject: string;
  minutes: number;
  completed: boolean;
  source?: string;
  createdAt?: number;
  completedAt?: number;
}

export interface ScheduleItem {
  id: string;
  weekday: number;
  startTime: string;
  endTime: string;
  course: string;
  location: string;
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
}

export interface QuizAttempt {
  id: string;
  questionId: string;
  subject: string;
  answer: string;
  correct: boolean;
  attemptedAt: number;
  dayKey: string;
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
  profileName: string;
  profileGrade: string;
  profileMajor: string;
  profileGoal: string;
  profileSubject: string;
  profileExamDate: string;
  profileDailyMinutes: number;
  profilePreferredTime: string;
  profileLearningStyle: string;
  profileSupportStyle: string;
  setupScheduleReady: boolean;
  tasks: StudyTask[];
  scheduleItems: ScheduleItem[];
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
  focusRecords?: FocusRecord[];
  quizAttempts?: QuizAttempt[];
  squadMessage?: string;
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
      title: `${subject}基础小测`,
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
