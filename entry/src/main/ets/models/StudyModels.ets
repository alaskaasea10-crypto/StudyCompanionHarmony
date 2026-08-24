export interface StudyTask {
  title: string;
  subject: string;
  minutes: number;
  completed: boolean;
}

export interface ScheduleItem {
  id: string;
  weekday: number;
  startTime: string;
  endTime: string;
  course: string;
  location: string;
}

export interface StudyStateSnapshot {
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
}

export function createDemoTasks(subject: string, dailyMinutes: number): StudyTask[] {
  const primaryMinutes: number = Math.min(25, Math.max(10, dailyMinutes));
  return [
    {
      title: `回顾${subject}核心知识点`,
      subject: subject,
      minutes: primaryMinutes,
      completed: false
    },
    {
      title: `完成${subject}练习`,
      subject: subject,
      minutes: Math.min(30, Math.max(15, dailyMinutes - primaryMinutes)),
      completed: false
    },
    {
      title: `${subject}基础小测`,
      subject: subject,
      minutes: 10,
      completed: false
    },
    {
      title: '复习今日课堂笔记',
      subject: '今日课程',
      minutes: 20,
      completed: false
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
