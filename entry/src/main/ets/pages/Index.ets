import { preferences } from '@kit.ArkData';
import { BottomNavigation } from '../components/BottomNavigation';
import { FocusPageView } from './FocusPage';
import { GrowthPageView } from './GrowthPage';
import { HomePageView } from './HomePage';
import { LearningPageView } from './LearningPage';
import { LoadingPageView } from './LoadingPage';
import { PlanPageView } from './PlanPage';
import { ProfilePageView } from './ProfilePage';
import { ProfileSetupPageView } from './ProfileSetupPage';
import {
  createDemoSchedule,
  createDemoTasks,
  ScheduleItem,
  StudyStateSnapshot,
  StudyTask
} from '../models/StudyModels';
import { FocusClock } from '../services/FocusClock';
import { RecommendationResult, RecommendationService } from '../services/RecommendationService';
import { StudyRepository } from '../services/StudyRepository';
import { TodayPlanResult, TodayPlanService } from '../services/TodayPlanService';

@Entry
@Component
struct Index {
  @State profileLoaded: boolean = false;
  @State profileCompleted: boolean = false;
  @State profileName: string = '小林';
  @State profileGrade: string = '大二';
  @State profileMajor: string = '计算机科学与技术';
  @State profileGoal: string = '期末复习';
  @State profileSubject: string = '线性代数';
  @State profileExamDate: string = '';
  @State profileDailyMinutes: number = 60;
  @State profilePreferredTime: string = '晚间';
  @State profileLearningStyle: string = '练习驱动';
  @State profileSupportStyle: string = '温和陪伴';
  @State setupScheduleReady: boolean = false;
  @State currentTab: number = 0;
  @State tasks: StudyTask[] = createDemoTasks('线性代数', 60);
  @State scheduleItems: ScheduleItem[] = createDemoSchedule();
  @State currentTaskIndex: number = 0;
  @State focusMinutes: number = 25;
  @State remainingSeconds: number = 25 * 60;
  @State isRunning: boolean = false;
  @State focusElapsedSeconds: number = 0;
  @State focusSegmentStartedAt: number = 0;
  @State focusSessionCredited: boolean = false;
  @State todayMinutes: number = 0;
  @State studyDayKey: string = '';
  @State shadowPulse: number = 1;
  @State newTaskTitle: string = '';
  @State energyState: string = '一般';
  @State agentInput: string = '';
  @State agentGenerated: boolean = false;
  @State quizChoice: string = '';
  @State quizSubmitted: boolean = false;
  @State showRecommendationDetails: boolean = false;
  @State squadMessage: string = '小队成员正在安静共学';
  private timerId: number = -1;
  private profileStore?: preferences.Preferences;
  private repository?: StudyRepository;

  aboutToAppear(): void {
    this.loadAppState();
  }

  aboutToDisappear(): void {
    this.clearTimerInterval();
    this.persistSilently();
  }

  private futureDate(days: number): string {
    const date: Date = new Date();
    date.setDate(date.getDate() + days);
    const year: number = date.getFullYear();
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private examDays(): number {
    const examTime: number = new Date(`${this.profileExamDate}T00:00:00+08:00`).getTime();
    if (Number.isNaN(examTime)) {
      return 14;
    }
    const now: Date = new Date();
    const todayTime: number = new Date(
      `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}T00:00:00+08:00`
    ).getTime();
    return Math.max(0, Math.ceil((examTime - todayTime) / 86400000));
  }

  private beijingDayKey(): string {
    const beijingDate: Date = new Date(Date.now() + 8 * 60 * 60 * 1000);
    const year: number = beijingDate.getUTCFullYear();
    const month: string = (beijingDate.getUTCMonth() + 1).toString().padStart(2, '0');
    const day: string = beijingDate.getUTCDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private async ensureProfileStore(): Promise<preferences.Preferences> {
    if (this.profileStore === undefined) {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        throw new Error('Unable to access application context');
      }
      try {
        this.profileStore = await preferences.getPreferences(hostContext, 'learner_profile');
      } catch (error) {
        console.error(`Index: unable to open local storage: ${error}`);
        throw new Error('Unable to open local study storage');
      }
      this.repository = new StudyRepository(this.profileStore);
    }
    return this.profileStore;
  }

  private restoreSnapshot(snapshot: StudyStateSnapshot): void {
    this.profileCompleted = snapshot.profileCompleted;
    this.profileName = snapshot.profileName;
    this.profileGrade = snapshot.profileGrade;
    this.profileMajor = snapshot.profileMajor;
    this.profileGoal = snapshot.profileGoal;
    this.profileSubject = snapshot.profileSubject;
    this.profileExamDate = snapshot.profileExamDate;
    this.profileDailyMinutes = snapshot.profileDailyMinutes;
    this.profilePreferredTime = snapshot.profilePreferredTime;
    this.profileLearningStyle = snapshot.profileLearningStyle;
    this.profileSupportStyle = snapshot.profileSupportStyle;
    this.setupScheduleReady = snapshot.setupScheduleReady;
    this.tasks = snapshot.tasks.length > 0 ? snapshot.tasks : createDemoTasks(snapshot.profileSubject,
      snapshot.profileDailyMinutes);
    this.scheduleItems = snapshot.scheduleItems.length > 0 ? snapshot.scheduleItems : createDemoSchedule();
    this.currentTaskIndex = Math.min(Math.max(0, snapshot.currentTaskIndex), this.tasks.length - 1);
    this.focusMinutes = snapshot.focusMinutes;
    this.remainingSeconds = snapshot.remainingSeconds;
    this.isRunning = snapshot.isRunning;
    this.focusElapsedSeconds = snapshot.focusElapsedSeconds;
    this.focusSegmentStartedAt = snapshot.focusSegmentStartedAt;
    this.focusSessionCredited = snapshot.focusSessionCredited === true;
    this.todayMinutes = snapshot.todayMinutes;
    this.studyDayKey = snapshot.studyDayKey;
    this.energyState = snapshot.energyState;
    this.agentInput = snapshot.agentInput;
    this.agentGenerated = snapshot.agentGenerated;
    this.quizChoice = snapshot.quizChoice;
    this.quizSubmitted = snapshot.quizSubmitted;
  }

  private snapshot(): StudyStateSnapshot {
    return {
      profileCompleted: this.profileCompleted,
      profileName: this.profileName,
      profileGrade: this.profileGrade,
      profileMajor: this.profileMajor,
      profileGoal: this.profileGoal,
      profileSubject: this.profileSubject,
      profileExamDate: this.profileExamDate,
      profileDailyMinutes: this.profileDailyMinutes,
      profilePreferredTime: this.profilePreferredTime,
      profileLearningStyle: this.profileLearningStyle,
      profileSupportStyle: this.profileSupportStyle,
      setupScheduleReady: this.setupScheduleReady,
      tasks: this.tasks,
      scheduleItems: this.scheduleItems,
      currentTaskIndex: this.currentTaskIndex,
      focusMinutes: this.focusMinutes,
      remainingSeconds: this.remainingSeconds,
      isRunning: this.isRunning,
      focusElapsedSeconds: this.focusElapsedSeconds,
      focusSegmentStartedAt: this.focusSegmentStartedAt,
      focusSessionCredited: this.focusSessionCredited,
      todayMinutes: this.todayMinutes,
      studyDayKey: this.studyDayKey,
      energyState: this.energyState,
      agentInput: this.agentInput,
      agentGenerated: this.agentGenerated,
      quizChoice: this.quizChoice,
      quizSubmitted: this.quizSubmitted
    };
  }

  private async persistState(): Promise<void> {
    await this.ensureProfileStore();
    if (this.repository !== undefined) {
      await this.repository.save(this.snapshot());
    }
  }

  private persistSilently(): void {
    this.persistState().catch((error: Error) => {
      console.error(`Index: failed to persist study state: ${error.message}`);
    });
  }

  private async loadAppState(): Promise<void> {
    const defaultExamDate: string = this.futureDate(14);
    try {
      const store: preferences.Preferences = await this.ensureProfileStore();
      const snapshot: StudyStateSnapshot | undefined = await this.repository?.load();
      if (snapshot !== undefined) {
        this.restoreSnapshot(snapshot);
      } else {
      this.profileCompleted = await store.get('completed', false) as boolean;
      this.profileName = await store.get('name', '小林') as string;
      this.profileGrade = await store.get('grade', '大二') as string;
      this.profileMajor = await store.get('major', '计算机科学与技术') as string;
      this.profileGoal = await store.get('goal', '期末复习') as string;
      this.profileSubject = await store.get('subject', '线性代数') as string;
      this.profileExamDate = await store.get('examDate', defaultExamDate) as string;
      this.profileDailyMinutes = await store.get('dailyMinutes', 60) as number;
      this.profilePreferredTime = await store.get('preferredTime', '晚间') as string;
      this.profileLearningStyle = await store.get('learningStyle', '练习驱动') as string;
      this.profileSupportStyle = await store.get('supportStyle', '温和陪伴') as string;
      this.setupScheduleReady = await store.get('scheduleReady', false) as boolean;
        if (this.profileCompleted) {
          this.applyProfileToTasks();
        }
      }
    } catch (error) {
      this.profileCompleted = false;
      this.profileExamDate = defaultExamDate;
    }
    const currentDayKey: string = this.beijingDayKey();
    if (this.studyDayKey !== currentDayKey) {
      this.studyDayKey = currentDayKey;
      this.todayMinutes = 0;
    }
    this.profileLoaded = true;
    if (this.isRunning) {
      this.refreshFocusClock();
      if (this.isRunning) {
        this.startTimerInterval();
      }
    }
    this.persistSilently();
  }

  private applyProfileToTasks(): void {
    const primaryMinutes: number = Math.min(25, Math.max(10, this.profileDailyMinutes));
    this.tasks = createDemoTasks(this.profileSubject, this.profileDailyMinutes);
    this.currentTaskIndex = 0;
    this.focusMinutes = primaryMinutes;
    this.remainingSeconds = primaryMinutes * 60;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.isRunning = false;
  }

  private async saveProfile(): Promise<void> {
    if (this.profileName.trim().length === 0 || this.profileMajor.trim().length === 0 ||
      this.profileSubject.trim().length === 0 || this.profileExamDate.trim().length === 0) {
      return;
    }
    this.profileName = this.profileName.trim();
    this.profileMajor = this.profileMajor.trim();
    this.profileSubject = this.profileSubject.trim();
    this.profileExamDate = this.profileExamDate.trim();
    this.applyProfileToTasks();
    this.profileCompleted = true;
    this.currentTab = 0;
    await this.persistState();
  }

  private async resetProfile(): Promise<void> {
    this.pauseFocus();
    this.profileCompleted = false;
    this.currentTab = 0;
    await this.persistState();
  }

  private setChoice(group: string, value: string): void {
    if (group === 'grade') {
      this.profileGrade = value;
    } else if (group === 'goal') {
      this.profileGoal = value;
    } else if (group === 'time') {
      this.profilePreferredTime = value;
    } else if (group === 'style') {
      this.profileLearningStyle = value;
    } else if (group === 'support') {
      this.profileSupportStyle = value;
    } else {
      this.profileDailyMinutes = Number(value);
    }
  }

  private completedCount(): number {
    return this.tasks.filter((task: StudyTask) => task.completed).length;
  }

  private currentTask(): StudyTask {
    const safeIndex: number = Math.min(Math.max(0, this.currentTaskIndex), this.tasks.length - 1);
    return this.tasks[safeIndex];
  }

  private todayTimeText(): string {
    if (this.todayMinutes < 60) {
      return `${this.todayMinutes}分钟`;
    }
    const hour: number = Math.floor(this.todayMinutes / 60);
    const minute: number = this.todayMinutes % 60;
    return `${hour}小时${minute}分钟`;
  }

  private beijingGreeting(): string {
    const beijingDate: Date = new Date(Date.now() + 8 * 60 * 60 * 1000);
    const hour: number = beijingDate.getUTCHours();
    if (hour < 6) {
      return '夜深了';
    }
    if (hour < 12) {
      return '上午好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  private recommendation(): RecommendationResult {
    return RecommendationService.recommend({
      goal: this.profileGoal,
      learningStyle: this.profileLearningStyle,
      energyState: this.energyState,
      subject: this.profileSubject,
      examDays: this.examDays(),
      scheduleReady: this.setupScheduleReady,
      scheduleItems: this.scheduleItems,
      tasks: this.tasks,
      now: Date.now()
    });
  }

  private clearTimerInterval(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private beginFocus(index: number): void {
    this.clearTimerInterval();
    this.currentTaskIndex = index;
    this.focusMinutes = this.tasks[index].minutes;
    this.remainingSeconds = this.focusMinutes * 60;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.isRunning = false;
    this.currentTab = 3;
    this.startTimer();
  }

  private startTimer(): void {
    if (this.isRunning || this.remainingSeconds <= 0) {
      return;
    }
    this.isRunning = true;
    this.focusSegmentStartedAt = Date.now();
    this.startTimerInterval();
    this.persistSilently();
  }

  private startTimerInterval(): void {
    this.clearTimerInterval();
    this.timerId = setInterval(() => {
      this.refreshFocusClock();
    }, 1000);
  }

  private refreshFocusClock(): void {
    if (!this.isRunning) {
      return;
    }
    this.remainingSeconds = FocusClock.remainingSeconds(
      this.focusMinutes * 60,
      this.focusElapsedSeconds,
      this.focusSegmentStartedAt,
      Date.now()
    );
    this.shadowPulse = this.shadowPulse >= 1.08 ? 1 : this.shadowPulse + 0.01;
    if (this.remainingSeconds <= 0) {
      this.finishFocus();
    }
  }

  private pauseFocus(): void {
    if (this.isRunning) {
      this.focusElapsedSeconds = FocusClock.elapsedSeconds(
        this.focusElapsedSeconds,
        this.focusSegmentStartedAt,
        Date.now()
      );
    }
    this.remainingSeconds = Math.max(0, this.focusMinutes * 60 - this.focusElapsedSeconds);
    this.focusSegmentStartedAt = 0;
    this.isRunning = false;
    this.clearTimerInterval();
    this.persistSilently();
  }

  private resetFocus(): void {
    this.clearTimerInterval();
    this.isRunning = false;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.remainingSeconds = this.focusMinutes * 60;
    this.shadowPulse = 1;
    this.persistSilently();
  }

  private finishFocus(): void {
    let elapsedSeconds: number = this.focusElapsedSeconds;
    if (this.isRunning) {
      elapsedSeconds = FocusClock.elapsedSeconds(elapsedSeconds, this.focusSegmentStartedAt, Date.now());
    }
    this.clearTimerInterval();
    this.isRunning = false;
    this.focusSegmentStartedAt = 0;
    this.focusElapsedSeconds = Math.min(this.focusMinutes * 60, elapsedSeconds);
    this.remainingSeconds = 0;
    if (!this.focusSessionCredited) {
      this.todayMinutes += FocusClock.completedMinutes(this.focusElapsedSeconds);
      this.focusSessionCredited = true;
    }
    if (!this.tasks[this.currentTaskIndex].completed) {
      this.setTaskCompleted(this.currentTaskIndex, true);
    }
    this.persistSilently();
  }

  private setTaskCompleted(index: number, completed: boolean): void {
    this.tasks = this.tasks.map((task: StudyTask, taskIndex: number) => {
      if (taskIndex === index) {
        return {
          title: task.title,
          subject: task.subject,
          minutes: task.minutes,
          completed: completed
        };
      }
      return task;
    });
    this.persistSilently();
  }

  private addTask(): void {
    const title: string = this.newTaskTitle.trim();
    if (title.length === 0) {
      return;
    }
    this.tasks = this.tasks.concat([{
      title: title,
      subject: '自定义任务',
      minutes: 25,
      completed: false
    }]);
    this.newTaskTitle = '';
    this.persistSilently();
  }

  private generateTodayPlan(): void {
    const text: string = this.agentInput.trim();
    const result: TodayPlanResult = TodayPlanService.generate(text, this.profileSubject, this.profileDailyMinutes);
    this.profileSubject = result.subject;
    this.tasks = result.tasks;
    this.currentTaskIndex = 0;
    this.focusMinutes = result.firstFocusMinutes;
    this.remainingSeconds = result.firstFocusMinutes * 60;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.isRunning = false;
    this.agentGenerated = true;
    this.persistSilently();
  }

  private planProgress(): number {
    if (this.tasks.length === 0) {
      return 0;
    }
    return Math.round(this.completedCount() * 100 / this.tasks.length);
  }

  private submitQuiz(): void {
    if (this.quizChoice.length === 0) {
      return;
    }
    this.quizSubmitted = true;
    if (this.quizChoice === 'B') {
      const quizIndex: number = this.tasks.findIndex((task: StudyTask) => task.title.includes('小测'));
      if (quizIndex >= 0) {
        this.setTaskCompleted(quizIndex, true);
      }
    } else {
      const reviewTitle: string = '回顾可逆矩阵与秩的关系';
      const reviewExists: boolean = this.tasks.some((task: StudyTask) => task.title === reviewTitle);
      if (!reviewExists) {
        this.tasks = this.tasks.concat([{
          title: reviewTitle,
          subject: this.profileSubject,
          minutes: 10,
          completed: false
        }]);
      }
    }
    this.persistSilently();
  }

  build() {
    if (!this.profileLoaded) {
      LoadingPageView()
    } else if (!this.profileCompleted) {
      ProfileSetupPageView({
        profileName: this.profileName,
        profileGrade: this.profileGrade,
        profileMajor: this.profileMajor,
        profileGoal: this.profileGoal,
        profileSubject: this.profileSubject,
        profileExamDate: this.profileExamDate,
        profileDailyMinutes: this.profileDailyMinutes,
        profilePreferredTime: this.profilePreferredTime,
        profileLearningStyle: this.profileLearningStyle,
        profileSupportStyle: this.profileSupportStyle,
        setupScheduleReady: this.setupScheduleReady,
        onTextChange: (field: string, value: string) => {
          if (field === 'name') {
            this.profileName = value;
          } else if (field === 'major') {
            this.profileMajor = value;
          } else if (field === 'subject') {
            this.profileSubject = value;
          } else if (field === 'examDate') {
            this.profileExamDate = value;
          }
        },
        onChoiceChange: (group: string, value: string) => {
          this.setChoice(group, value);
        },
        onUseDemoSchedule: () => {
          this.setupScheduleReady = true;
          this.scheduleItems = createDemoSchedule();
        },
        onSaveProfile: () => {
          this.saveProfile();
        }
      })
    } else {
      Column() {
        if (this.currentTab === 0) {
          HomePageView({
            profileName: this.profileName,
            greeting: this.beijingGreeting(),
            profileSubject: this.profileSubject,
            examDays: this.examDays(),
            todayTimeText: this.todayTimeText(),
            completedCount: this.completedCount(),
            tasks: this.tasks,
            recommendationTitle: this.recommendation().title,
            recommendationReason: this.recommendation().reason,
            recommendationMinutes: this.recommendation().minutes,
            recommendationTaskIndex: this.recommendation().taskIndex,
            recommendationAllDone: this.recommendation().allDone,
            recommendationEvidence: this.recommendation().evidence,
            timelineTime: this.recommendation().timelineTime,
            timelineTitle: this.recommendation().timelineTitle,
            timelineDetail: this.recommendation().timelineDetail,
            showRecommendationDetails: this.showRecommendationDetails,
            onStartFocus: (index: number) => {
              this.beginFocus(index);
            },
            onToggleRecommendationDetails: () => {
              this.showRecommendationDetails = !this.showRecommendationDetails;
            },
            onToggleTask: (index: number, completed: boolean) => {
              this.setTaskCompleted(index, completed);
            }
          })
        } else if (this.currentTab === 1) {
          PlanPageView({
            setupScheduleReady: this.setupScheduleReady,
            scheduleItems: this.scheduleItems,
            newTaskTitle: this.newTaskTitle,
            profileSubject: this.profileSubject,
            profileExamDate: this.profileExamDate,
            examDays: this.examDays(),
            tasks: this.tasks,
            onUseDemoSchedule: () => {
              this.setupScheduleReady = true;
              this.scheduleItems = createDemoSchedule();
              this.persistSilently();
            },
            onNewTaskTitleChange: (value: string) => {
              this.newTaskTitle = value;
            },
            onAddTask: () => {
              this.addTask();
            },
            onStartTask: (index: number) => {
              this.beginFocus(index);
            }
          })
        } else if (this.currentTab === 2) {
          LearningPageView({
            profileGrade: this.profileGrade,
            profileLearningStyle: this.profileLearningStyle,
            profileDailyMinutes: this.profileDailyMinutes,
            profileSubject: this.profileSubject,
            profileExamDate: this.profileExamDate,
            examDays: this.examDays(),
            agentInput: this.agentInput,
            agentGenerated: this.agentGenerated,
            tasks: this.tasks,
            planProgress: this.planProgress(),
            quizChoice: this.quizChoice,
            quizSubmitted: this.quizSubmitted,
            onAgentInputChange: (value: string) => {
              this.agentInput = value;
            },
            onGeneratePlan: () => {
              this.generateTodayPlan();
            },
            onQuizChoiceChange: (value: string) => {
              this.quizChoice = value;
              this.quizSubmitted = false;
            },
            onSubmitQuiz: () => {
              this.submitQuiz();
            }
          })
        } else if (this.currentTab === 3) {
          FocusPageView({
            currentTaskTitle: this.currentTask().title,
            currentTaskCompleted: this.currentTask().completed,
            remainingSeconds: this.remainingSeconds,
            isRunning: this.isRunning,
            shadowPulse: this.shadowPulse,
            todayTimeText: this.todayTimeText(),
            onPause: () => {
              this.pauseFocus();
            },
            onContinue: () => {
              this.startTimer();
            },
            onRestart: () => {
              this.resetFocus();
              this.startTimer();
            },
            onReset: () => {
              this.resetFocus();
            },
            onFinish: () => {
              this.finishFocus();
            }
          })
        } else if (this.currentTab === 4) {
          GrowthPageView({
            profileSubject: this.profileSubject,
            todayTimeText: this.todayTimeText(),
            isRunning: this.isRunning,
            squadMessage: this.squadMessage,
            onEnterShadow: () => {
              this.currentTab = 3;
              if (!this.isRunning) {
                this.startTimer();
              }
            },
            onSquadMessageChange: (message: string) => {
              this.squadMessage = message;
            }
          })
        } else {
          ProfilePageView({
            profileName: this.profileName,
            profileGrade: this.profileGrade,
            profileMajor: this.profileMajor,
            profileGoal: this.profileGoal,
            profileLearningStyle: this.profileLearningStyle,
            profileDailyMinutes: this.profileDailyMinutes,
            profilePreferredTime: this.profilePreferredTime,
            profileSubject: this.profileSubject,
            profileExamDate: this.profileExamDate,
            examDays: this.examDays(),
            energyState: this.energyState,
            onEnergyChange: (value: string) => {
              this.energyState = value;
              this.persistSilently();
            },
            onResetProfile: () => {
              this.resetProfile();
            }
          })
        }
        BottomNavigation({
          currentTab: this.currentTab,
          onTabChange: (index: number) => {
            this.currentTab = index;
          }
        })
      }
      .width('100%').height('100%').backgroundColor('#F6F7FC')
    }
  }
}
