import { common } from '@kit.AbilityKit';
import window from '@ohos.window';
import sensor from '@ohos.sensor';
import { ImmersiveOrbit } from '../components/ImmersiveOrbit';
import { FloatingAgent } from '../components/FloatingAgent';
import { preferences } from '@kit.ArkData';
import { BottomNavigation } from '../components/BottomNavigation';
import { FocusPageView } from './FocusPage';
import { GrowthPageView } from './GrowthPage';
import { VideoLibraryPageView } from './VideoLibraryPage';
import { BankLearningEvidence, BankState } from '../models/QuestionBankModels';
import { QuestionBank } from '../services/QuestionBank';
import { BankLearningBridge } from '../services/BankLearningBridge';
import { BankPlanBudget } from '../services/BankPlanBudget';
import { LearningVideo } from '../models/VideoModels';
import { VideoCatalog } from '../services/VideoCatalog';
import { HomePageView } from './HomePage';
import { LearningHubPageView, LearningResourcesPageView } from './LearningHubPage';
import { PlanetGrowthService } from '../services/PlanetGrowthService';
import { LoadingPageView } from './LoadingPage';
import { PlanPageView } from './PlanPage';
import { ProfilePageView } from './ProfilePage';
import { ProfileSetupPageView } from './ProfileSetupPage';
import { ScheduleScannerPageView } from './ScheduleScannerPage';
import {
  createDefaultSquadMembers,
  createDemoSchedule,
  createDemoTasks,
  FocusRecord,
  KnowledgeMastery,
  QuizAttempt,
  ScheduleItem,
  SquadMember,
  StudyMetrics,
  StudyStateSnapshot,
  StudyTask,
  TodayStudyOverride
} from '../models/StudyModels';
import { AcademicGoal, GoalMilestone } from '../models/StudyModels';
import { ScheduleImportResult } from '../models/ScheduleImportModels';
import {
  AgentGeneratedTask,
  AgentConversationMessage,
  AgentPlan,
  AgentPlanRequest,
  AgentUsage,
  PlanCommitResult,
  PlanningDecision,
  QuizFeedbackResult,
  QuizQuestion
} from '../models/AgentModels';
import { EmotionalSupportMessage } from '../models/EmotionalSupportModels';
import { EmotionalSupportClient } from '../services/EmotionalSupportClient';
import { FocusClock } from '../services/FocusClock';
import { ActiveReminderService, NotificationResult } from '../services/ActiveReminderService';
import { LearningContextInput, LearningDecisionPolicy } from '../services/LearningDecisionPolicy';
import { LearningFeedbackService } from '../services/LearningFeedbackService';
import { LearningPlanningOrchestrator } from '../services/LearningPlanningOrchestrator';
import { PlanCommitService } from '../services/PlanCommitService';
import { PlanValidator } from '../services/PlanValidator';
import { RecommendationResult, RecommendationService } from '../services/RecommendationService';
import { StudyDataCenter } from '../services/StudyDataCenter';
import { StudyRepository } from '../services/StudyRepository';
import { StudyWidgetService } from '../services/StudyWidgetService';
import { StudyLiveViewService } from '../services/StudyLiveViewService';
import { StudyActionRouter, StudyExternalAction } from '../services/StudyActionRouter';
import { ScheduleImportClient } from '../services/ScheduleImportClient';
import { ScheduleEditingService } from '../services/ScheduleEditingService';
import { QuizService } from '../services/QuizService';
import { KnowledgeMasteryService } from '../services/KnowledgeMasteryService';
import { AvatarService } from '../services/AvatarService';
import { SquadService } from '../services/SquadService';
import { DailyAction, DailyActionService } from '../services/DailyActionService';
import { LearningActionService } from '../services/LearningActionService';
import { TodayStudyOverrideService } from '../services/TodayStudyOverrideService';
import { StudyTaskDeletionResult, StudyTaskDeletionService } from '../services/StudyTaskDeletionService';
import { StudyDecisionDebug } from '../services/StudyDecisionDebug';
import { AgentDecisionResult, AgentDecisionService } from '../services/AgentDecisionService';
import { TaskOutcomeService } from '../services/TaskOutcomeService';
import { ActionDeferral } from '../models/StudyModels';
import { GoalPlanningService, GoalPriority } from '../services/GoalPlanningService';

const WIDGET_ROUTE_EVENT: string = 'studyWidgetRoute';

@Component
export struct Index {
  onRegisterBack: (handler: () => boolean) => void = () => {};
  private detached: boolean = false;
  @State profileLoaded: boolean = false;
  @State profileCompleted: boolean = false;
  @State profileAvatarUri: string = '';
  @State profileName: string = '小林';
  @State profileGrade: string = '大二';
  @State profileMajor: string = '计算机科学与技术';
  @State profileGoal: string = '期末复习';
  @State profileSubject: string = '线性代数';
  @State profileExamDate: string = '';
  @State profileExamDateConfirmed: boolean = false;
  @State profileDailyMinutes: number = 60;
  @State profilePreferredTime: string = '晚间';
  @State profileLearningStyle: string = '练习驱动';
  @State profileSupportStyle: string = '温和陪伴';
  @State setupScheduleReady: boolean = false;
  @State currentTab: number = 0;
  @State bankEvidence: BankLearningEvidence[] = [];
  @State bankStudyDays: string[] = [];
  @State bankEvidenceError: string = '';
  @State bankPlanMode: boolean = false;
  @State bankTopicId: string = 'matrix';
  @State agentCommitBusy: boolean = false;
  @State videoModuleId: string = 'career';
  @State videoInitialQuery: string = '';
  @State videoReturnTab: number = 4;
  @State tasks: StudyTask[] = createDemoTasks('线性代数', 60);
  @State scheduleItems: ScheduleItem[] = createDemoSchedule();
  @State scheduleImportStatus: string = 'idle';
  @State scheduleImportMessage: string = '';
  @State scheduleImportSource: string = '';
  @State scheduleDraftItems: ScheduleItem[] = [];
  @State scheduleScannerOpen: boolean = false;
  @State currentTaskIndex: number = 0;
  @State focusMinutes: number = 25;
  @State remainingSeconds: number = 25 * 60;
  @State isRunning: boolean = false;
  @State focusElapsedSeconds: number = 0;
  @State focusSegmentStartedAt: number = 0;
  @State focusSessionCredited: boolean = false;
  @State todayMinutes: number = 0;
  @State studyDayKey: string = '';
  @State newTaskTitle: string = '';
  @State academicGoals: AcademicGoal[] = [];
  @State newGoalTitle: string = '';
  @State newGoalSubject: string = '';
  @State newGoalDeadline: string = '';
  @State newGoalEstimatedMinutes: string = '';
  @State energyState: string = '一般';
  @State agentInput: string = '';
  @State agentGenerated: boolean = false;
  @State agentLoading: boolean = false;
  @State agentError: string = '';
  @State agentPlanSource: string = '';
  @State agentPlanSummary: string = '';
  @State agentPreviewSubject: string = '';
  @State agentPreviewTasks: AgentGeneratedTask[] = [];
  @State agentRecommendationReasons: string[] = [];
  @State agentAcceptedMessage: string = '';
  @State quizChoice: string = '';
  @State quizSubmitted: boolean = false;
  @State quizPending: boolean = false;
  @State quizQuestionId: string = '';
  @State quizFeedbackMessage: string = '';
  @State agentFeedbackMode: boolean = false;
  @State floatingAgentOpen: boolean = false;
  @State floatingAgentHintVisible: boolean = true;
  @State businessOverlayOpen: boolean = false;
  @State floatingAgentMode: string = 'planning';
  @State floatingAgentInput: string = '';
  @State floatingAgentMessages: AgentConversationMessage[] = [];
  @State floatingSupportBusy: boolean = false;
  @State floatingAgentError: string = '';
  @State floatingPlanPending: boolean = false;
  @State floatingAcceptedMessage: string = '';
  @State floatingSupportSource: string = '';
  @State focusRecords: FocusRecord[] = [];
  @State quizAttempts: QuizAttempt[] = [];
  @State knowledgeMastery: KnowledgeMastery[] = [];
  @State showRecommendationDetails: boolean = false;
  @State squadMessage: string = '小队成员正在安静共学，送出微光不会打断对方';
  @State squadMembers: SquadMember[] = createDefaultSquadMembers('小林');
  @State squadInviteCode: string = '';
  @State squadChallengeTitle: string = '';
  @State squadChallengeMinutes: number = 25;
  @State squadChallengeJoinedCount: number = 0;
  @State squadChallengeActive: boolean = false;
  @State notificationEnabled: boolean = false;
  @State notificationClassEnabled: boolean = true;
  @State notificationReviewEnabled: boolean = true;
  @State notificationTaskEnabled: boolean = true;
  @State notificationQuietHoursEnabled: boolean = true;
  @State notificationQuietStart: string = '22:30';
  @State notificationQuietEnd: string = '07:30';
  @State notificationStatus: string = '开启后，Agent会在合适的时机提供低打扰提醒';
  @State avatarStatus: string = '头像仅保存在本机';
  @State actionDeferrals: ActionDeferral[] = [];
  @State preferredTaskId: string = '';
  @State todayStudyOverride: TodayStudyOverride = { date: '' };
  @State deletedTaskIds: string[] = [];
  @State actionClock: number = Date.now();
  @State actionMessage: string = '';
  @State resultNote: string = '';
  @State resultChecked: boolean = false;
  @State resultExperience: string = '';
  private actionClockId: number = -1;
  private timerId: number = -1;
  private agentRequestId: number = 0;
  private agentPlanBudget: number = 60;
  private profileStore?: preferences.Preferences;
  private repository?: StudyRepository;
  private persistenceQueue: Promise<void> = Promise.resolve();
  private widgetRouteListener: Function = (route: string): void => {
    this.handleWidgetRoute(route);
    AppStorage.set<string>(WIDGET_ROUTE_EVENT, '');
  };

  @State private orbitImmersive: boolean = false;
  private orbitChanging: boolean = false;
  private orbitCancelEntry: boolean = false;
  private orbitWindow: window.Window | undefined = undefined;
  private orbitPreviousOrientation: window.Orientation = window.Orientation.UNSPECIFIED;
  private orbitPreviousLayout: boolean = false;
  private orbitTiltStarted: number = 0;
  private orbitTiltArmed: boolean = true;
  private orbitNoticeShown: boolean = false;
  private orbitPageVisible: boolean = false;
  private orbitGravity = (data: sensor.GravityResponse): void => {
    if (Math.abs(data.y) > 7) { this.orbitTiltArmed = true; }
    if (!this.orbitPageVisible || this.currentTab !== 3 || !this.profileLoaded || !this.profileCompleted ||
      this.orbitImmersive || this.orbitChanging || !this.orbitTiltArmed ||
      Math.abs(data.x) < 7 || Math.abs(data.y) > 4) {
      this.orbitTiltStarted = 0; return;
    }
    if (this.orbitTiltStarted === 0) { this.orbitTiltStarted = Date.now(); }
    if (Date.now() - this.orbitTiltStarted > 650) { this.enterOrbit(); }
  };

  private async enterOrbit(): Promise<void> {
    if (this.orbitImmersive || this.orbitChanging) { return; }
    this.orbitChanging = true;
    this.orbitCancelEntry = false;
    this.orbitTiltArmed = false;
    try {
      const host = this.getUIContext().getHostContext();
      if (!host) { return; }
      const win = await window.getLastWindow(host);
      this.orbitWindow = win;
      this.orbitPreviousOrientation = win.getPreferredOrientation();
      this.orbitPreviousLayout = win.getWindowProperties().isLayoutFullScreen;
      await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
      await win.setWindowLayoutFullScreen(true);
      await win.setWindowSystemBarEnable([]);
      if (!this.orbitCancelEntry && !this.detached) {
        this.orbitImmersive = true;
        if (!this.orbitNoticeShown) {
          this.orbitNoticeShown = true;
          this.getUIContext().getPromptAction().showToast({
            message: '双击星域退出；系统勿扰请在控制中心手动开启', duration: 5000 });
        }
      } else { await this.restoreOrbitWindow(); }
    } catch (_) {
      await this.restoreOrbitWindow();
      this.getUIContext().getPromptAction().showToast({ message: '横屏暂未开启，请重试' });
    } finally { this.orbitChanging = false; }
  }

  private async restoreOrbitWindow(): Promise<void> {
    const win = this.orbitWindow;
    if (!win) { return; }
    try { await win.setWindowSystemBarEnable(['status', 'navigation']); } catch (_) {}
    try { await win.setWindowLayoutFullScreen(this.orbitPreviousLayout); } catch (_) {}
    try { await win.setPreferredOrientation(this.orbitPreviousOrientation); } catch (_) {}
    this.orbitWindow = undefined;
  }

  private async exitOrbit(): Promise<void> {
    this.orbitCancelEntry = true;
    this.orbitTiltArmed = false;
    if (this.orbitChanging) { return; }
    this.orbitChanging = true;
    this.orbitImmersive = false;
    await this.restoreOrbitWindow();
    this.orbitChanging = false;
  }

  aboutToAppear(): void {
    try { sensor.on(sensor.SensorId.GRAVITY, this.orbitGravity, { interval: 200000000 }); }
    catch (_) { console.info('重力传感器不可用，仍可点击进入星域'); }
    this.detached = false;
    this.actionClockId = setInterval(() => { this.actionClock = Date.now(); }, 30000);
    this.onRegisterBack(() => this.onBackPress());
    const hostContext = this.getUIContext().getHostContext();
    hostContext?.eventHub.on(WIDGET_ROUTE_EVENT, this.widgetRouteListener);
    this.loadAppState();
  }

  aboutToDisappear(): void {
    try { sensor.off(sensor.SensorId.GRAVITY, this.orbitGravity); } catch (_) {}
    this.exitOrbit();
    if (this.actionClockId >= 0) { clearInterval(this.actionClockId); this.actionClockId = -1; }
    this.detached = true;
    this.agentRequestId++;
    const hostContext = this.getUIContext().getHostContext();
    hostContext?.eventHub.off(WIDGET_ROUTE_EVENT, this.widgetRouteListener);
    this.clearTimerInterval();
    this.persistSilently();
  }

  private handleWidgetRoute(routeJson: string): void {
    if (!this.profileLoaded || routeJson.length === 0) {
      return;
    }
    const route: StudyExternalAction | undefined = StudyActionRouter.parse(routeJson);
    if (route === undefined) { this.currentTab = 0; return; }
    if (route.target === 'schedule') { this.currentTab = 10; return; }
    if (route.target === 'learning') { this.currentTab = 8; return; }
    if (route.target === 'support') {
      this.floatingAgentMode = 'support';
      this.floatingAgentHintVisible = false;
      this.floatingAgentOpen = true;
      return;
    }
    if (route.target === 'next') {
      const action: DailyAction = this.dailyAction();
      if (route.taskId.length > 0 && action.taskId !== route.taskId) {
        this.currentTab = 0;
        this.actionMessage = '学习安排已经更新，请查看现在最适合做的一项';
        return;
      }
      if (this.isRunning) { this.currentTab = 3; } else { this.runDailyAction(); }
      return;
    }
    if (route.target === 'focus') {
      const taskIndex: number = this.tasks.findIndex((task: StudyTask) => task.id === route.taskId);
      if (taskIndex >= 0 && !this.tasks[taskIndex].completed) {
        this.beginFocus(taskIndex);
        return;
      }
      if (this.isRunning || (this.remainingSeconds > 0 && this.remainingSeconds < this.focusMinutes * 60)) {
        this.currentTab = 3;
        return;
      }
      this.runDailyAction();
      return;
    }
    this.currentTab = 0;
  }

  private handlePendingWidgetRoute(): void {
    const route: string | undefined = AppStorage.get<string>(WIDGET_ROUTE_EVENT);
    if (route !== undefined && route.length > 0) {
      this.handleWidgetRoute(route);
      AppStorage.set<string>(WIDGET_ROUTE_EVENT, '');
    }
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
    this.profileCompleted = snapshot.profileCompleted === true;
    this.profileAvatarUri = snapshot.profileAvatarUri ?? '';
    this.profileName = snapshot.profileName?.trim().length > 0 ? snapshot.profileName : '小林';
    this.profileGrade = snapshot.profileGrade?.trim().length > 0 ? snapshot.profileGrade : '大二';
    this.profileMajor = snapshot.profileMajor?.trim().length > 0 ? snapshot.profileMajor : '计算机科学与技术';
    this.profileGoal = snapshot.profileGoal?.trim().length > 0 ? snapshot.profileGoal : '期末复习';
    this.profileSubject = snapshot.profileSubject?.trim().length > 0 ? snapshot.profileSubject : '线性代数';
    this.profileExamDate = snapshot.profileExamDate?.trim().length > 0 ? snapshot.profileExamDate : this.futureDate(14);
    this.profileExamDateConfirmed = snapshot.profileExamDateConfirmed === true &&
      snapshot.profileExamDate?.trim().length > 0;
    this.profileDailyMinutes = Math.min(240, Math.max(15, snapshot.profileDailyMinutes ?? 60));
    this.profilePreferredTime = snapshot.profilePreferredTime?.trim().length > 0 ? snapshot.profilePreferredTime : '晚间';
    this.profileLearningStyle = snapshot.profileLearningStyle?.trim().length > 0 ? snapshot.profileLearningStyle : '练习驱动';
    this.profileSupportStyle = snapshot.profileSupportStyle?.trim().length > 0 ? snapshot.profileSupportStyle : '温和陪伴';
    this.setupScheduleReady = snapshot.setupScheduleReady === true;
    this.actionDeferrals = (snapshot.actionDeferrals ?? []).filter((item: ActionDeferral) =>
      typeof item.key === 'string' && Number.isFinite(item.until) && item.until > Date.now());
    // 旧版 preferredTaskId 没有日期，不能迁移成永久的今日偏好。
    this.todayStudyOverride = TodayStudyOverrideService.active(snapshot) ?? { date: '' };
    this.preferredTaskId = this.todayStudyOverride.preferredTaskId ?? '';
    this.deletedTaskIds = Array.from(new Set((snapshot.deletedTaskIds ?? [])
      .filter((id: string) => typeof id === 'string' && id.length > 0)));
    const storedTasks: StudyTask[] = Array.isArray(snapshot.tasks) ? snapshot.tasks : [];
    // 已保存的空数组代表用户确实删除了全部待办，不能在重启时重新注入初始任务。
    this.tasks = Array.isArray(snapshot.tasks) ? storedTasks : createDemoTasks(this.profileSubject,
      this.profileDailyMinutes);
    this.tasks = StudyDataCenter.normalizeTasks(this.tasks).map((task: StudyTask) => {
      if (task.completed) { return task; }
      const updated: StudyTask = JSON.parse(JSON.stringify(task)) as StudyTask;
      updated.title = task.title.replace(/即时小测|基础小测/g, '学习回顾').replace(/换题验证|换题复测/g, '回顾整理');
      return updated;
    });
    const storedSchedule: ScheduleItem[] = Array.isArray(snapshot.scheduleItems) ? snapshot.scheduleItems : [];
    this.scheduleItems = storedSchedule.length > 0 ? storedSchedule : createDemoSchedule();
    const restoredGoals: AcademicGoal[] = Array.isArray(snapshot.academicGoals) ? snapshot.academicGoals : [];
    this.academicGoals = restoredGoals.length > 0 ? restoredGoals.map((goal: AcademicGoal) => GoalPlanningService.normalize(goal)) :
      [GoalPlanningService.create(`${this.profileSubject}考试`, this.profileSubject,
        this.profileExamDate, this.profileDailyMinutes * Math.max(1, this.examDays()))];
    this.ensureGoalMilestoneTask();
    this.currentTaskIndex = this.tasks.length === 0 ? 0 :
      Math.min(Math.max(0, snapshot.currentTaskIndex), this.tasks.length - 1);
    this.focusMinutes = Math.min(240, Math.max(1,
      snapshot.focusMinutes ?? this.tasks[0]?.minutes ?? this.profileDailyMinutes));
    const totalFocusSeconds: number = this.focusMinutes * 60;
    this.focusElapsedSeconds = Math.min(totalFocusSeconds, Math.max(0, snapshot.focusElapsedSeconds ?? 0));
    this.focusSegmentStartedAt = Math.max(0, snapshot.focusSegmentStartedAt ?? 0);
    this.isRunning = snapshot.isRunning === true && this.focusSegmentStartedAt > 0 &&
      this.focusElapsedSeconds < totalFocusSeconds;
    this.remainingSeconds = this.isRunning ? totalFocusSeconds - this.focusElapsedSeconds :
      Math.min(totalFocusSeconds, Math.max(0, snapshot.remainingSeconds ?? totalFocusSeconds));
    this.focusSessionCredited = snapshot.focusSessionCredited === true;
    this.todayMinutes = Math.max(0, snapshot.todayMinutes ?? 0);
    this.studyDayKey = snapshot.studyDayKey ?? '';
    this.energyState = snapshot.energyState?.trim().length > 0 ? snapshot.energyState : '一般';
    this.agentInput = snapshot.agentInput ?? '';
    // 模型预览是临时数据，重启后不展示没有内容的旧预览状态。
    this.agentGenerated = false;
    this.quizChoice = snapshot.quizChoice ?? '';
    this.quizSubmitted = snapshot.quizSubmitted === true;
    this.quizPending = false; // 旧小测不再恢复为阻塞步骤
    this.quizQuestionId = snapshot.quizQuestionId ?? '';
    this.quizFeedbackMessage = snapshot.quizFeedbackMessage ?? '';
    this.focusRecords = Array.isArray(snapshot.focusRecords) ? snapshot.focusRecords : [];
    this.quizAttempts = Array.isArray(snapshot.quizAttempts) ? snapshot.quizAttempts : [];
    this.knowledgeMastery = Array.isArray(snapshot.knowledgeMastery) ? snapshot.knowledgeMastery : [];
    this.squadMessage = snapshot.squadMessage ?? '小队成员正在安静共学，送出微光不会打断对方';
    const storedSquadMembers: SquadMember[] = Array.isArray(snapshot.squadMembers) ? snapshot.squadMembers : [];
    this.squadMembers = SquadService.normalizeMembers(storedSquadMembers, this.profileName);
    this.squadInviteCode = snapshot.squadInviteCode ?? '';
    this.squadChallengeTitle = snapshot.squadChallengeTitle ?? '';
    this.squadChallengeMinutes = Math.min(60, Math.max(5, snapshot.squadChallengeMinutes ?? 25));
    this.squadChallengeJoinedCount = Math.max(0, snapshot.squadChallengeJoinedCount ?? 0);
    this.squadChallengeActive = snapshot.squadChallengeActive === true;
    this.notificationEnabled = snapshot.notificationEnabled === true;
    this.notificationClassEnabled = snapshot.notificationClassEnabled !== false;
    this.notificationReviewEnabled = snapshot.notificationReviewEnabled !== false;
    this.notificationTaskEnabled = snapshot.notificationTaskEnabled !== false;
    this.notificationQuietHoursEnabled = snapshot.notificationQuietHoursEnabled !== false;
    this.notificationQuietStart = snapshot.notificationQuietStart ?? '22:30';
    this.notificationQuietEnd = snapshot.notificationQuietEnd ?? '07:30';
  }

  private snapshot(): StudyStateSnapshot {
    return {
      schemaVersion: 9,
      actionDeferrals: this.actionDeferrals,
      todayStudyOverride: this.todayStudyOverride,
      deletedTaskIds: this.deletedTaskIds,
      preferredTaskId: this.todayStudyOverride.date === TodayStudyOverrideService.date(this.actionClock) ?
        this.todayStudyOverride.preferredTaskId ?? '' : '',
      profileCompleted: this.profileCompleted,
      profileAvatarUri: this.profileAvatarUri,
      profileName: this.profileName,
      profileGrade: this.profileGrade,
      profileMajor: this.profileMajor,
      profileGoal: this.profileGoal,
      profileSubject: this.profileSubject,
      profileExamDate: this.profileExamDate,
      profileExamDateConfirmed: this.profileExamDateConfirmed,
      profileDailyMinutes: this.profileDailyMinutes,
      profilePreferredTime: this.profilePreferredTime,
      profileLearningStyle: this.profileLearningStyle,
      profileSupportStyle: this.profileSupportStyle,
      setupScheduleReady: this.setupScheduleReady,
      tasks: this.tasks,
      scheduleItems: this.scheduleItems,
      academicGoals: this.academicGoals,
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
      agentGenerated: false,
      quizChoice: this.quizChoice,
      quizSubmitted: this.quizSubmitted,
      quizPending: this.quizPending,
      quizQuestionId: this.quizQuestionId,
      quizFeedbackMessage: this.quizFeedbackMessage,
      focusRecords: this.focusRecords,
      quizAttempts: this.quizAttempts,
      knowledgeMastery: this.knowledgeMastery,
      squadMessage: this.squadMessage,
      // 快照只保存原始小队数据。若在这里调用 squadMembersForDisplay()，
      // 它会读取 studyMetrics()，而 studyMetrics() 又依赖 snapshot()，造成无限递归。
      squadMembers: this.squadMembers,
      squadInviteCode: this.squadInviteCode,
      squadChallengeTitle: this.squadChallengeTitle,
      squadChallengeMinutes: this.squadChallengeMinutes,
      squadChallengeJoinedCount: this.squadChallengeJoinedCount,
      squadChallengeActive: this.squadChallengeActive,
      notificationEnabled: this.notificationEnabled,
      notificationClassEnabled: this.notificationClassEnabled,
      notificationReviewEnabled: this.notificationReviewEnabled,
      notificationTaskEnabled: this.notificationTaskEnabled,
      notificationQuietHoursEnabled: this.notificationQuietHoursEnabled,
      notificationQuietStart: this.notificationQuietStart,
      notificationQuietEnd: this.notificationQuietEnd
    };
  }

  private async persistState(): Promise<void> {
    this.actionClock = Date.now();
    const value: StudyStateSnapshot = this.snapshot();
    const pending: Promise<void> = this.persistenceQueue.catch(() => {}).then(async (): Promise<void> => {
      await this.ensureProfileStore();
      if (this.repository !== undefined) {
        await this.repository.saveChecked(value);
        if (!this.detached) {
          await ActiveReminderService.cancelActive();
          const hostContext = this.getUIContext().getHostContext();
          if (hostContext !== undefined) { await StudyWidgetService.updateAll(hostContext, value); }
        }
      }
    });
    this.persistenceQueue = pending;
    await pending;
  }

  private persistSilently(): void {
    this.persistState().catch((error: Error) => {
      this.actionMessage = '本次更改尚未保存，请重试；不要切换账号';
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
      // 旧偏好未记录日期由谁填写；确认前不作为 AI 决策证据。
      this.profileExamDateConfirmed = false;
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
      this.quizChoice = '';
      this.quizSubmitted = false;
      this.quizPending = false;
      this.quizQuestionId = '';
      this.quizFeedbackMessage = '';
    }
    await this.loadBankEvidence();
    this.profileLoaded = true;
    if (this.isRunning) {
      this.refreshFocusClock();
      if (this.isRunning) {
        this.startTimerInterval();
      }
    }
    this.handlePendingWidgetRoute();
    this.persistSilently();
  }

  private applyProfileToTasks(): void {
    const primaryMinutes: number = Math.min(25, Math.max(10, this.profileDailyMinutes));
    this.tasks = createDemoTasks(this.profileSubject, this.profileDailyMinutes);
    this.todayStudyOverride = { date: '' };
    this.deletedTaskIds = [];
    this.preferredTaskId = '';
    this.currentTaskIndex = 0;
    this.focusMinutes = primaryMinutes;
    this.remainingSeconds = primaryMinutes * 60;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.isRunning = false;
    this.quizPending = false;
    this.quizQuestionId = '';
    this.quizChoice = '';
    this.quizSubmitted = false;
    this.quizFeedbackMessage = '';
    this.knowledgeMastery = [];
    this.academicGoals = [GoalPlanningService.create(`${this.profileSubject}考试`, this.profileSubject,
      this.profileExamDate, this.profileDailyMinutes * Math.max(1, this.examDays()))];
    this.ensureGoalMilestoneTask();
  }

  private async loadBankEvidence(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) { throw new Error('context'); }
      const store: preferences.Preferences = await preferences.getPreferences(context, 'matrix_question_bank_v1');
      this.updateBankRecords(QuestionBank.decode(await store.get('records', JSON.stringify(QuestionBank.empty())) as string));
    } catch (error) { console.warn('历史学习天数暂未读到'); }
  }

  private updateBankRecords(state: BankState): void {
    this.bankStudyDays = state.sessions.filter((session) => session.answers.length > 0 &&
      Number.isFinite(session.startedAt) && session.startedAt > 0)
      .map((session) => new Date(session.startedAt + 8 * 3600000).toISOString().substring(0, 10));
    // 只兼容历史连续学习天数，不再把旧答题数据用于推荐或自动完成任务。
  }

  private squadMembersForDisplay(): SquadMember[] {
    return SquadService.syncSelf(
      this.squadMembers,
      this.profileName,
      this.studyMetrics().todayFocusMinutes,
      this.isRunning,
      this.currentTask().title,
      this.currentFocusProgress()
    );
  }

  private currentFocusProgress(): number {
    const totalSeconds: number = Math.max(1, this.focusMinutes * 60);
    const elapsedSeconds: number = this.isRunning || this.focusElapsedSeconds > 0 ?
      Math.max(this.focusElapsedSeconds, totalSeconds - this.remainingSeconds) : 0;
    return Math.max(0, Math.min(100, Math.round(elapsedSeconds / totalSeconds * 100)));
  }

  private collectiveFocusMinutes(): number {
    const completedMinutes: number = this.squadMembersForDisplay().reduce(
      (total: number, member: SquadMember) => total + Math.max(0, member.todayMinutes), 0
    );
    // 已归档的本轮包含在 todayMinutes 中，不再次累计；提前结束也不按整轮时长计入。
    const activeMinutes: number = this.focusSessionCredited ? 0 : Math.floor(
      Math.min(this.focusMinutes * 60, Math.max(0, this.focusElapsedSeconds,
        this.isRunning ? this.focusMinutes * 60 - this.remainingSeconds : 0)) / 60
    );
    return completedMinutes + activeMinutes;
  }

  private encourageSquadMember(memberId: string): void {
    const members: SquadMember[] = this.squadMembersForDisplay();
    const member: SquadMember | undefined = members.find((item: SquadMember) => item.id === memberId);
    if (member === undefined || member.isSelf) {
      return;
    }
    this.squadMembers = SquadService.encourage(members, memberId);
    this.squadMessage = `已向${member.name}送出一束微光，鼓励已被记录`;
    this.persistSilently();
  }

  private sendQuietSignal(memberId: string, signal: string): void {
    const members: SquadMember[] = this.squadMembersForDisplay();
    const member: SquadMember | undefined = members.find((item: SquadMember) => item.id === memberId);
    if (member === undefined || member.isSelf) {
      return;
    }
    this.squadMembers = SquadService.encourage(members, memberId, signal);
    this.squadMessage = `已向${member.name}安静敲肩：“${signal}”`;
    this.persistSilently();
  }

  private createSquadInvite(): void {
    this.squadInviteCode = SquadService.inviteCode(this.profileName);
    this.squadMessage = `小队口令 ${this.squadInviteCode} 已生成，可分享给同学加入体验小队`;
    this.persistSilently();
  }

  private createSquadChallenge(): void {
    this.squadChallengeTitle = `共同专注${this.focusMinutes}分钟`;
    this.squadChallengeMinutes = this.focusMinutes;
    this.squadChallengeJoinedCount = 1;
    this.squadChallengeActive = true;
    this.squadMessage = `“${this.squadChallengeTitle}”已发起，你已加入挑战`;
    this.persistSilently();
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
    this.squadMembers = SquadService.normalizeMembers(this.squadMembers, this.profileName);
    this.applyProfileToTasks();
    this.profileCompleted = true;
    this.currentTab = 0;
    await this.persistState();
  }

  private async resetProfile(): Promise<void> {
    this.agentRequestId += 1;
    this.pauseFocus(false);
    this.profileCompleted = false;
    this.currentTab = 0;
    await this.persistState();
  }

  private hostAbilityContext(): common.UIAbilityContext | undefined {
    const hostContext = this.getUIContext().getHostContext();
    return hostContext === undefined ? undefined : hostContext as common.UIAbilityContext;
  }

  private async setNotificationEnabled(enabled: boolean): Promise<void> {
    if (!enabled) {
      this.notificationEnabled = false;
      this.notificationStatus = '主动提醒已关闭，桌面卡片仍会正常同步';
      await this.persistState();
      return;
    }
    const context: common.UIAbilityContext | undefined = this.hostAbilityContext();
    if (context === undefined) {
      this.notificationStatus = '暂时无法访问系统通知服务';
      return;
    }
    this.notificationStatus = '正在申请系统通知权限…';
    const granted: boolean = await ActiveReminderService.requestPermission(context);
    this.notificationEnabled = granted;
    this.notificationStatus = granted ?
      '主动提醒已开启；切到后台时，Agent会判断是否需要提醒' :
      '通知权限未开启，可在系统设置中允许“学伴”发送通知';
    await this.persistState();
  }

  private async selectAvatar(): Promise<void> {
    const context: common.UIAbilityContext | undefined = this.hostAbilityContext();
    if (context === undefined) {
      this.avatarStatus = '暂时无法访问图库';
      return;
    }
    this.avatarStatus = '正在选择头像…';
    try {
      this.profileAvatarUri = await AvatarService.selectAndSave(context, this.profileAvatarUri);
      this.avatarStatus = '头像已更新，并安全保存在本机';
      await this.persistState();
    } catch (error) {
      this.avatarStatus = error instanceof Error ? error.message : '头像更新失败，请重试';
    }
  }

  private setNotificationOption(option: string, enabled: boolean): void {
    if (option === 'class') {
      this.notificationClassEnabled = enabled;
    } else if (option === 'review') {
      this.notificationReviewEnabled = enabled;
    } else if (option === 'task') {
      this.notificationTaskEnabled = enabled;
    } else if (option === 'quiet') {
      this.notificationQuietHoursEnabled = enabled;
    }
    this.persistSilently();
  }

  private async sendTestNotification(): Promise<void> {
    const context: common.UIAbilityContext | undefined = this.hostAbilityContext();
    if (context === undefined) {
      this.notificationStatus = '暂时无法访问系统通知服务';
      return;
    }
    if (!this.notificationEnabled) {
      const granted: boolean = await ActiveReminderService.requestPermission(context);
      if (!granted) {
        this.notificationStatus = '通知权限未开启，测试通知未发送';
        return;
      }
      this.notificationEnabled = true;
      await this.persistState();
    }
    this.notificationStatus = '正在发送测试通知…';
    const result: NotificationResult = await ActiveReminderService.publishTest(context, this.snapshot());
    this.notificationStatus = result.message;
  }

  private async importScheduleImage(): Promise<void> {
    if (this.scheduleImportStatus === 'recognizing') {
      return;
    }
    this.scheduleImportStatus = 'recognizing';
    this.scheduleImportMessage = '正在选择图片并识别课程…';
    this.scheduleDraftItems = [];
    try {
      const result: ScheduleImportResult = await ScheduleImportClient.selectAndRecognize();
      this.scheduleDraftItems = result.scheduleItems;
      this.scheduleImportSource = result.source === 'core-vision' ? '华为 Core Vision' : '本机 Vision 备用识别';
      this.scheduleImportMessage = `已识别 ${result.scheduleItems.length} 门课程`;
      this.scheduleImportStatus = 'reviewing';
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      if (message.includes('取消') || message.includes('没有选择')) {
        this.scheduleImportMessage = '';
        this.scheduleImportStatus = this.setupScheduleReady ? 'imported' : 'idle';
        return;
      }
      this.scheduleImportMessage = message.length > 0 ? message : '课表识别失败，请重试';
      this.scheduleImportStatus = 'error';
    }
  }

  private openScheduleScanner(): void {
    if (this.scheduleImportStatus === 'recognizing') {
      return;
    }
    this.scheduleImportMessage = '';
    this.scheduleScannerOpen = true;
  }

  private async recognizeScannedSchedule(uri: string): Promise<void> {
    this.scheduleScannerOpen = false;
    this.scheduleImportStatus = 'recognizing';
    this.scheduleImportMessage = '正在解析扫描后的课表…';
    this.scheduleDraftItems = [];
    try {
      const result: ScheduleImportResult = await ScheduleImportClient.recognizeUri(uri);
      this.scheduleDraftItems = result.scheduleItems;
      this.scheduleImportSource = '华为 Vision 智能扫描';
      this.scheduleImportMessage = `已识别 ${result.scheduleItems.length} 门课程`;
      this.scheduleImportStatus = 'reviewing';
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      this.scheduleImportMessage = message.length > 0 ? message : '扫描课表识别失败，请重试';
      this.scheduleImportStatus = 'error';
    }
  }

  private cancelScheduleScanner(): void {
    this.scheduleScannerOpen = false;
    this.scheduleImportMessage = '';
    this.scheduleImportStatus = this.setupScheduleReady ? 'imported' : 'idle';
  }

  private confirmScheduleImport(): void {
    if (this.scheduleDraftItems.length === 0) {
      this.scheduleImportMessage = '还没有可导入的课程';
      this.scheduleImportStatus = 'error';
      return;
    }
    const prepared: ScheduleItem[] | undefined = ScheduleEditingService.prepare(this.scheduleDraftItems);
    if (prepared === undefined) {
      this.scheduleImportMessage = ScheduleEditingService.validationError(this.scheduleDraftItems);
      this.scheduleImportStatus = 'reviewing';
      return;
    }
    this.scheduleItems = prepared;
    this.setupScheduleReady = true;
    this.scheduleImportStatus = 'imported';
    this.scheduleImportMessage = `已同步 ${this.scheduleItems.length} 门课程`;
    this.scheduleDraftItems = [];
    this.persistSilently();
  }

  private updateScheduleDraftItems(items: ScheduleItem[]): void {
    this.scheduleDraftItems = ScheduleEditingService.copy(items);
    this.scheduleImportMessage = `正在核对 ${items.length} 门课程`;
  }

  private async saveScheduleEdits(items: ScheduleItem[]): Promise<boolean> {
    const prepared: ScheduleItem[] | undefined = ScheduleEditingService.prepare(items);
    if (prepared === undefined) { return false; }
    const previousItems: ScheduleItem[] = this.scheduleItems;
    const previousSource: string = this.scheduleImportSource;
    const previousStatus: string = this.scheduleImportStatus;
    this.scheduleItems = prepared;
    this.setupScheduleReady = true;
    this.scheduleImportSource = '手动编辑';
    this.scheduleImportStatus = 'imported';
    this.scheduleImportMessage = `已保存 ${prepared.length} 门课程`;
    try {
      await this.persistState();
      return true;
    } catch (error) {
      this.scheduleItems = previousItems;
      this.scheduleImportSource = previousSource;
      this.scheduleImportStatus = previousStatus;
      this.scheduleImportMessage = '课表保存失败，已保留原记录';
      return false;
    }
  }

  private useDemoSchedule(): void {
    this.setupScheduleReady = true;
    this.scheduleItems = createDemoSchedule();
    this.scheduleDraftItems = [];
    this.scheduleImportSource = '演示数据';
    this.scheduleImportMessage = '已载入演示课表';
    this.scheduleImportStatus = 'imported';
    this.persistSilently();
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
    return this.studyMetrics().completedTaskCount;
  }

  private studyMetrics(): StudyMetrics {
    return StudyDataCenter.metrics(this.snapshot());
  }

  private currentTask(): StudyTask {
    if (this.tasks.length === 0) {
      return {
        id: 'safe-fallback-task',
        title: `回顾${this.profileSubject}核心知识点`,
        subject: this.profileSubject,
        minutes: Math.max(1, this.focusMinutes),
        completed: false,
        source: 'recovery',
        createdAt: Date.now(),
        completedAt: 0
      };
    }
    const safeIndex: number = Math.min(Math.max(0, this.currentTaskIndex), this.tasks.length - 1);
    return this.tasks[safeIndex];
  }

  private currentQuizQuestion(): QuizQuestion {
    const task: StudyTask = this.currentTask();
    return QuizService.questionById(this.quizQuestionId, task.subject, task.title);
  }

  private latestMastery(): KnowledgeMastery | undefined {
    return KnowledgeMasteryService.latest(this.knowledgeMastery);
  }

  private masteryPoint(): string {
    return this.latestMastery()?.knowledgePoint ?? '';
  }

  private masteryScore(): number {
    return this.latestMastery()?.score ?? 0;
  }

  private masteryStatus(): string {
    return this.latestMastery()?.status ?? '';
  }

  private todayTimeText(): string {
    let todayFocusMinutes: number = this.studyMetrics().todayFocusMinutes;
    if (!this.focusSessionCredited) {
      const activeSeconds: number = this.isRunning && this.focusSegmentStartedAt > 0 ?
        Math.max(0, Math.floor((Date.now() - this.focusSegmentStartedAt) / 1000)) : 0;
      const unrecordedMinutes: number = Math.floor(Math.min(this.focusMinutes * 60,
        this.focusElapsedSeconds + activeSeconds) / 60);
      todayFocusMinutes += Math.max(0, unrecordedMinutes);
    }
    if (todayFocusMinutes < 60) {
      return `${todayFocusMinutes}分钟`;
    }
    const hour: number = Math.floor(todayFocusMinutes / 60);
    const minute: number = todayFocusMinutes % 60;
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

  private dailyAction(): DailyAction {
    return this.agentDecision().recommendedAction;
  }

  private agentDecision(): AgentDecisionResult {
    return AgentDecisionService.decide(this.snapshot(), this.actionClock);
  }

  private async deferAction(kind: string): Promise<void> {
    const action: DailyAction = this.dailyAction();
    if (action.key === undefined || action.stage === 'resume' || action.stage === 'wait' || action.stage === 'done') { return; }
    const now: number = Date.now();
    const nextMidnight: number = (Math.floor((now + 8 * 3600000) / 86400000) + 1) * 86400000 - 8 * 3600000;
    const until: number = kind === 'later' ? Math.min(now + 30 * 60000, nextMidnight) : nextMidnight;
    const previous: ActionDeferral[] = this.actionDeferrals;
    const previousOverride: TodayStudyOverride = this.todayStudyOverride;
    this.actionDeferrals = this.actionDeferrals.filter((item: ActionDeferral) => item.until > now && item.key !== action.key)
      .concat([{ key: action.key, until: until, kind: kind }]);
    if (kind === 'skip' && action.key.startsWith('task:')) {
      const active: TodayStudyOverride = this.todayStudyOverride.date === this.beijingDayKey() ?
        this.todayStudyOverride : { date: this.beijingDayKey() };
      const taskId: string = action.key.substring(5);
      this.todayStudyOverride = { date: active.date, availableMinutes: active.availableMinutes,
        preferredTaskId: active.preferredTaskId, preferredSubject: active.preferredSubject,
        temporaryTaskIds: active.temporaryTaskIds,
        skippedTaskIds: Array.from(new Set((active.skippedTaskIds ?? []).concat([taskId]))) };
    }
    this.actionMessage = kind === 'later' ? '已延后 30 分钟，原任务保留' : '今天先跳过，明天再安排';
    this.agentRequestId++; this.agentLoading = false; this.agentGenerated = false;
    try { await this.persistState(); } catch (error) {
      this.actionDeferrals = previous;
      this.todayStudyOverride = previousOverride;
      this.actionMessage = '暂缓未保存，请重试';
    }
  }

  private undoDeferral(): void {
    this.actionDeferrals = [];
    if (this.todayStudyOverride.date === this.beijingDayKey()) {
      this.todayStudyOverride = { date: this.todayStudyOverride.date,
        availableMinutes: this.todayStudyOverride.availableMinutes,
        preferredTaskId: this.todayStudyOverride.preferredTaskId,
        preferredSubject: this.todayStudyOverride.preferredSubject,
        temporaryTaskIds: this.todayStudyOverride.temporaryTaskIds, skippedTaskIds: [] };
    }
    this.actionMessage = '';
    this.persistSilently();
  }

  private adjustTodayTask(override: TodayStudyOverride, temporaryTitle: string, temporarySubject: string,
    temporaryMinutes: number): void {
    const date: string = this.beijingDayKey();
    if (override.date !== date) { return; }
    const previous: TodayStudyOverride = this.todayStudyOverride.date === date ? this.todayStudyOverride : { date: date };
    const available: number | undefined = override.availableMinutes === undefined ? undefined :
      Math.min(240, Math.max(0, Math.floor(override.availableMinutes)));
    const skippedIds: string[] = (override.skippedTaskIds ?? []).filter((id: string) =>
      this.tasks.some((task: StudyTask) => task.id === id && !task.completed));
    let preferredId: string = override.preferredTaskId ?? '';
    if (!this.tasks.some((task: StudyTask) => task.id === preferredId && !task.completed)) { preferredId = ''; }
    if (skippedIds.includes(preferredId)) { preferredId = ''; }
    const temporaryIds: string[] = (previous.temporaryTaskIds ?? []).slice();
    const title: string = temporaryTitle.trim();
    if (title.length > 0) {
      const now: number = Date.now();
      const id: string = `today-${now}-${this.tasks.length}`;
      const task: StudyTask = { id: id, title: title, subject: temporarySubject.trim() || this.profileSubject,
        minutes: Math.min(120, Math.max(5, temporaryMinutes)), completed: false,
        source: 'today-temporary', createdAt: now, completedAt: 0 };
      this.tasks = this.tasks.concat([task]);
      temporaryIds.push(id);
      preferredId = id;
    }
    this.todayStudyOverride = { date: date, availableMinutes: available,
      preferredTaskId: preferredId, preferredSubject: override.preferredSubject?.trim() ?? '',
      skippedTaskIds: skippedIds, temporaryTaskIds: temporaryIds };
    this.preferredTaskId = preferredId;
    this.actionDeferrals = this.actionDeferrals.filter((item: ActionDeferral) => item.kind !== 'skip' ||
      !item.key.startsWith('task:') || skippedIds.includes(item.key.substring(5)));
    if (preferredId.length > 0) {
      this.actionDeferrals = this.actionDeferrals.filter((item: ActionDeferral) => item.key !== `task:${preferredId}`);
    }
    this.actionClock = Date.now();
    this.actionMessage = '今天的安排已更新；正在进行的专注不会被打断';
    if (typeof StudyDecisionDebug !== 'undefined') {
      const adjustedTask: StudyTask | undefined = this.tasks.find((task: StudyTask) => task.id === preferredId);
      StudyDecisionDebug.event('today-override-updated', preferredId, adjustedTask?.subject ?? '',
        adjustedTask?.title ?? '', available === undefined ? 'availableMinutes=unknown' : `availableMinutes=${available}`);
    }
    this.persistSilently();
  }

  private async deleteTodayTask(taskId: string): Promise<string> {
    const taskIndex: number = this.tasks.findIndex((task: StudyTask) => task.id === taskId);
    const task: StudyTask | undefined = taskIndex >= 0 ? this.tasks[taskIndex] : undefined;
    const currentId: string = this.currentTask().id ?? '';
    const hasActiveFocusSession: boolean = this.isRunning || (taskId === currentId &&
      this.focusElapsedSeconds > 0 && this.remainingSeconds > 0);
    const blocked: string = StudyTaskDeletionService.blockReason(task, currentId, hasActiveFocusSession);
    if (blocked.length > 0) { return blocked; }

    const previousTasks: StudyTask[] = this.tasks;
    const previousOverride: TodayStudyOverride = this.todayStudyOverride;
    const previousDeferrals: ActionDeferral[] = this.actionDeferrals;
    const previousDeletedIds: string[] = this.deletedTaskIds;
    const previousTaskIndex: number = this.currentTaskIndex;
    const previousPreferredTaskId: string = this.preferredTaskId;
    const previousCurrentId: string = previousTasks[previousTaskIndex]?.id ?? '';
    const result: StudyTaskDeletionResult = StudyTaskDeletionService.remove(taskId, previousTasks,
      previousOverride, previousDeferrals, previousDeletedIds);
    this.tasks = result.tasks;
    this.todayStudyOverride = result.todayStudyOverride;
    this.actionDeferrals = result.actionDeferrals;
    this.deletedTaskIds = result.deletedTaskIds;
    this.preferredTaskId = this.todayStudyOverride.preferredTaskId ?? '';
    const retainedCurrentIndex: number = this.tasks.findIndex((item: StudyTask) => item.id === previousCurrentId);
    this.currentTaskIndex = retainedCurrentIndex >= 0 ? retainedCurrentIndex :
      Math.min(Math.max(0, previousTaskIndex), Math.max(0, this.tasks.length - 1));
    this.actionClock = Date.now();
    this.agentRequestId++;
    this.agentLoading = false;
    this.agentGenerated = false;
    try {
      await this.persistState();
      this.actionMessage = '待办已删除，今天的安排已重新计算';
      return '';
    } catch (error) {
      this.tasks = previousTasks;
      this.todayStudyOverride = previousOverride;
      this.actionDeferrals = previousDeferrals;
      this.deletedTaskIds = previousDeletedIds;
      this.currentTaskIndex = previousTaskIndex;
      this.preferredTaskId = previousPreferredTaskId;
      this.actionMessage = '删除未保存，原待办已恢复';
      return '删除未保存，原待办已恢复，请重试。';
    }
  }

  private recordTaskResult(index: number, passed: boolean, note: string, experience: string = ''): void {
    const task: StudyTask | undefined = this.tasks[index];
    if (task === undefined || task.completed) { return; }
    const updated: StudyTask = TaskOutcomeService.submit(task, passed, note, Date.now(),
      experience === 'smooth' || experience === 'normal' || experience === 'struggling' ? experience : undefined);
    this.tasks = this.tasks.map((item: StudyTask, i: number) => i === index ? updated : item);
    if (updated.completed && updated.id === this.todayStudyOverride.preferredTaskId) {
      this.todayStudyOverride = { date: this.todayStudyOverride.date,
        availableMinutes: this.todayStudyOverride.availableMinutes, preferredTaskId: '',
        preferredSubject: this.todayStudyOverride.preferredSubject,
        skippedTaskIds: this.todayStudyOverride.skippedTaskIds,
        temporaryTaskIds: this.todayStudyOverride.temporaryTaskIds };
      this.preferredTaskId = '';
    }
    if (passed) { this.advanceGoalMilestone(updated, true); }
    if (typeof StudyDecisionDebug !== 'undefined') {
      StudyDecisionDebug.event('feedback-submitted', updated.id ?? '', updated.subject, updated.title,
        `completed=${updated.completed}`);
      if (updated.completed) {
        StudyDecisionDebug.event('task-completed', updated.id ?? '', updated.subject, updated.title);
      }
    }
    this.actionDeferrals = this.actionDeferrals.filter((item: ActionDeferral) => item.key !== `task:${task.id}`);
    this.persistSilently();
  }

  private submitSelfResult(): void {
    if (!this.resultChecked || this.resultExperience.length === 0 || this.resultNote.trim().length < 4 ||
      TaskOutcomeService.kind(this.currentTask()) !== 'self') { return; }
    this.recordTaskResult(this.currentTaskIndex, true, this.resultNote.trim(), this.resultExperience);
    this.resultNote = ''; this.resultChecked = false; this.resultExperience = '';
    this.actionMessage = '';
    this.currentTab = 0;
  }

  private openTaskResult(index: number): void {
    if (index < 0 || index >= this.tasks.length) { return; }
    if (this.isRunning) { this.archiveInterruptedFocus(); }
    this.clearTimerInterval(); this.isRunning = false;
    this.remainingSeconds = 0; this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0; this.focusSessionCredited = true;
    this.currentTaskIndex = index;
    this.focusMinutes = this.tasks[index].minutes;
    this.resultNote = ''; this.resultChecked = false; this.resultExperience = '';
    const task: StudyTask = this.tasks[index];
    if (!task.completed && task.outcome !== 'focused' && task.outcome !== 'submitted') {
      this.tasks = this.tasks.map((item: StudyTask, i: number) => i === index ? TaskOutcomeService.focused(item, Date.now()) : item);
    }
    this.quizPending = false;
    if (typeof StudyDecisionDebug !== 'undefined') {
      StudyDecisionDebug.event('feedback-pending', task.id ?? '', task.subject, task.title);
    }
    this.currentTab = 3;
    this.persistSilently();
  }

  private activeGoal(): GoalPriority | undefined {
    return GoalPlanningService.prioritize(this.academicGoals, this.tasks);
  }

  private addAcademicGoal(): void {
    const title: string = this.newGoalTitle.trim();
    const subject: string = this.newGoalSubject.trim();
    const deadline: string = this.newGoalDeadline.trim();
    const estimatedText: string = this.newGoalEstimatedMinutes.trim();
    const estimated: number = Number(estimatedText);
    if (title.length === 0 || subject.length === 0 || GoalPlanningService.daysUntil(deadline) === 999 ||
      !/^\d+$/.test(estimatedText) || estimated < 60 || estimated > 6000) { return; }
    const goal: AcademicGoal = GoalPlanningService.create(title, subject, deadline, estimated, '学习目标');
    this.academicGoals = this.academicGoals.concat([goal]);
    const first: GoalMilestone | undefined = GoalPlanningService.nextMilestone(goal);
    if (first !== undefined) { this.tasks = this.tasks.concat([GoalPlanningService.taskFor(goal, first)]); }
    this.newGoalTitle = ''; this.newGoalSubject = ''; this.newGoalDeadline = ''; this.newGoalEstimatedMinutes = '';
    this.persistSilently();
  }

  private toggleAcademicGoal(id: string): void {
    this.academicGoals = this.academicGoals.map((goal: AcademicGoal): AcademicGoal => goal.id === id ?
      { id: goal.id, title: goal.title, type: goal.type, subject: goal.subject, deadline: goal.deadline,
        estimatedMinutes: goal.estimatedMinutes, completed: !goal.completed, createdAt: goal.createdAt,
        milestones: goal.milestones } : goal);
    this.persistSilently();
  }

  private async updateAcademicGoal(id: string, title: string, subject: string, deadline: string,
    estimatedMinutes: number): Promise<boolean> {
    if (title.trim().length === 0 || subject.trim().length === 0 ||
      GoalPlanningService.daysUntil(deadline.trim()) === 999 || estimatedMinutes < 60 || estimatedMinutes > 6000) {
      return false;
    }
    const previous: AcademicGoal[] = this.academicGoals;
    let found: boolean = false;
    this.academicGoals = this.academicGoals.map((goal: AcademicGoal): AcademicGoal => {
      if (goal.id !== id) { return goal; }
      found = true;
      return GoalPlanningService.update(goal, title, subject, deadline, estimatedMinutes);
    });
    if (!found) { this.academicGoals = previous; return false; }
    try {
      await this.persistState();
      return true;
    } catch (error) {
      this.academicGoals = previous;
      this.actionMessage = '学习目标保存失败，已保留原记录';
      return false;
    }
  }

  private ensureGoalMilestoneTask(): void {
    // 每个真实目标都保留自己的下一阶段，避免只有 priorityGoal 拥有可调度任务。
    this.academicGoals.filter((goal: AcademicGoal) => !goal.completed).forEach((goal: AcademicGoal) => {
      const milestone: GoalMilestone | undefined = GoalPlanningService.nextMilestone(goal);
      const milestoneTask: StudyTask | undefined = milestone === undefined ? undefined :
        GoalPlanningService.taskFor(goal, milestone);
      if (milestoneTask !== undefined && !(this.deletedTaskIds ?? []).includes(milestoneTask.id ?? '') &&
        !this.tasks.some((task: StudyTask) => task.milestoneId === milestoneTask.milestoneId)) {
        this.tasks = this.tasks.concat([milestoneTask]);
      }
    });
  }

  private advanceGoalMilestone(task: StudyTask, completed: boolean): void {
    if (task.goalId === undefined || task.milestoneId === undefined) { return; }
    if (completed && this.tasks.some((item: StudyTask) => item.goalId === task.goalId &&
      item.milestoneId === task.milestoneId && !item.completed)) { return; }
    this.academicGoals = this.academicGoals.map((goal: AcademicGoal): AcademicGoal => {
      if (goal.id !== task.goalId) { return goal; }
      const milestones: GoalMilestone[] = (goal.milestones ?? []).map((item: GoalMilestone): GoalMilestone =>
        item.id === task.milestoneId ? { id: item.id, title: item.title, description: item.description,
          dueDate: item.dueDate, minutes: item.minutes, completed: completed } : item);
      return { id: goal.id, title: goal.title, type: goal.type, subject: goal.subject, deadline: goal.deadline,
        estimatedMinutes: goal.estimatedMinutes, completed: milestones.length > 0 && milestones.every((item: GoalMilestone) => item.completed),
        createdAt: goal.createdAt, milestones: milestones };
    });
    if (completed) {
      const updated: AcademicGoal | undefined = this.academicGoals.find((goal: AcademicGoal) => goal.id === task.goalId);
      const next: GoalMilestone | undefined = updated === undefined ? undefined : GoalPlanningService.nextMilestone(updated);
      if (updated !== undefined && next !== undefined &&
        !this.tasks.some((item: StudyTask) => item.milestoneId === next.id)) {
        this.tasks = this.tasks.concat([GoalPlanningService.taskFor(updated, next)]);
      }
    }
  }

  private runDailyAction(): void {
    if (this.actionMessage.includes('未保存')) { return; }
    this.actionMessage = '';
    this.actionClock = Date.now();
    const action: DailyAction = this.dailyAction();
    if (action.stage === 'resume') { this.currentTab = 3; return; }
    if (action.stage === 'verify') { this.openTaskResult(action.taskIndex); return; }
    if (action.stage === 'wait' || action.stage === 'done') { this.currentTab = 1; return; }
    if (action.stage === 'plan') {
      this.openFloatingPlanning('请根据我今天剩余的时间和目标，帮我安排下一步学习。');
      return;
    }
    if (action.stage === 'execute') { this.beginFocus(action.taskIndex, action.minutes); }
  }

  private clearTimerInterval(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private beginFocus(index: number, minutes: number = 0): void {
    if (index < 0 || index >= this.tasks.length) {
      return;
    }
    if (index === this.currentTaskIndex && this.isRunning) { this.currentTab = 3; return; }
    this.archiveInterruptedFocus();
    this.currentTaskIndex = index;
    if (this.tasks[index].outcome === 'focused' || this.tasks[index].outcome === 'submitted') {
      this.openTaskResult(index); return;
    }
    const focusSnapshot: StudyStateSnapshot = this.snapshot();
    const free: number | undefined = LearningActionService.freeMinutes(focusSnapshot);
    const allowed: number = Math.min(LearningActionService.budget(focusSnapshot),
      free === undefined ? this.tasks[index].minutes : free);
    if (allowed < 5) { this.actionMessage = '当前时间不足，任务已保留'; this.currentTab = 0; return; }
    this.focusMinutes = Math.min(minutes > 0 ? minutes : this.tasks[index].minutes, allowed);
    const started: StudyTask = JSON.parse(JSON.stringify(this.tasks[index])) as StudyTask;
    started.focusedAt = Date.now(); started.outcome = 'studying';
    this.tasks = this.tasks.map((task: StudyTask, i: number) => i === index ? started : task);
    this.actionDeferrals = this.actionDeferrals.filter((item: ActionDeferral) => item.key !== `task:${started.id}`);
    this.remainingSeconds = this.focusMinutes * 60;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.isRunning = false;
    this.quizPending = false;
    this.quizQuestionId = '';
    this.quizChoice = '';
    this.quizSubmitted = false;
    this.quizFeedbackMessage = '';
    this.agentFeedbackMode = false;
    this.currentTab = 3;
    if (typeof StudyDecisionDebug !== 'undefined') {
      StudyDecisionDebug.event('focus-started', started.id ?? '', started.subject, started.title,
        `minutes=${this.focusMinutes}`);
    }
    this.startTimer();
  }

  private startTimer(): void {
    if (this.isRunning || this.remainingSeconds <= 0) {
      return;
    }
    this.isRunning = true;
    this.focusSegmentStartedAt = Date.now();
    this.startTimerInterval();
    StudyLiveViewService.startOrResume(
      this.hostAbilityContext(), this.currentTask().subject, this.remainingSeconds
    );
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
    if (this.remainingSeconds <= 0) {
      this.finishFocus();
    }
  }

  private pauseFocus(shouldPersist: boolean = true): void {
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
    StudyLiveViewService.pause(
      this.hostAbilityContext(), this.currentTask().subject, this.remainingSeconds
    );
    if (shouldPersist) {
      this.persistSilently();
    }
  }

  private archiveInterruptedFocus(): void {
    let elapsedSeconds: number = this.focusElapsedSeconds;
    if (this.isRunning) {
      elapsedSeconds = FocusClock.elapsedSeconds(elapsedSeconds, this.focusSegmentStartedAt, Date.now());
    }
    elapsedSeconds = Math.min(this.focusMinutes * 60, Math.max(0, elapsedSeconds));
    this.clearTimerInterval();
    StudyLiveViewService.stop();
    if (!this.focusSessionCredited && elapsedSeconds >= 60 && this.tasks.length > 0) {
      const task: StudyTask = this.currentTask();
      this.todayMinutes += FocusClock.completedMinutes(elapsedSeconds);
      this.focusRecords = this.focusRecords.concat([
        StudyDataCenter.createFocusRecord(task, this.focusMinutes, elapsedSeconds, this.studyDayKey, false)
      ]);
      this.focusSessionCredited = true;
    }
    this.isRunning = false;
    this.focusSegmentStartedAt = 0;
    this.focusElapsedSeconds = elapsedSeconds;
    this.remainingSeconds = Math.max(0, this.focusMinutes * 60 - elapsedSeconds);
  }

  private resetFocus(): void {
    this.clearTimerInterval();
    this.isRunning = false;
    this.focusElapsedSeconds = 0;
    this.focusSegmentStartedAt = 0;
    this.focusSessionCredited = false;
    this.remainingSeconds = this.focusMinutes * 60;
    StudyLiveViewService.stop();
    this.persistSilently();
  }

  private finishFocus(): void {
    const task: StudyTask = this.currentTask();
    const taskAlreadyResolved: boolean = task.completed || task.outcome === 'focused' ||
      task.outcome === 'submitted';
    let elapsedSeconds: number = this.focusElapsedSeconds;
    if (this.isRunning) {
      elapsedSeconds = FocusClock.elapsedSeconds(elapsedSeconds, this.focusSegmentStartedAt, Date.now());
    }
    this.clearTimerInterval();
    this.isRunning = false;
    this.focusSegmentStartedAt = 0;
    this.focusElapsedSeconds = Math.min(this.focusMinutes * 60, elapsedSeconds);
    this.remainingSeconds = 0;
    StudyLiveViewService.stop();
    if (taskAlreadyResolved) {
      // A completed or feedback-pending task must never leave a stale running session behind.
      // Mark this residual session closed without writing another focus record or outcome.
      this.focusSessionCredited = true;
      this.persistSilently();
      return;
    }
    if (!this.focusSessionCredited && this.focusElapsedSeconds > 0 && this.tasks.length > 0) {
      this.todayMinutes += FocusClock.completedMinutes(this.focusElapsedSeconds);
      this.focusRecords = this.focusRecords.concat([
        StudyDataCenter.createFocusRecord(
          this.currentTask(),
          this.focusMinutes,
          this.focusElapsedSeconds,
          this.studyDayKey,
          true
        )
      ]);
      this.focusSessionCredited = true;
    }
    if (this.tasks.length > 0) {
      const focused: StudyTask = TaskOutcomeService.focused(task, Date.now());
      this.tasks = this.tasks.map((task: StudyTask, index: number) => index === this.currentTaskIndex ? focused : task);
      if (typeof StudyDecisionDebug !== 'undefined') {
        StudyDecisionDebug.event('focus-finished', focused.id ?? '', focused.subject, focused.title,
          `elapsedSeconds=${this.focusElapsedSeconds}`);
      }
      this.openTaskResult(this.currentTaskIndex);
    }
    this.persistSilently();
  }

  private setTaskCompleted(index: number, completed: boolean): void {
    if (completed) { this.openTaskResult(index); return; }
    const changedTask: StudyTask | undefined = this.tasks[index];
    this.tasks = this.tasks.map((task: StudyTask, taskIndex: number) => {
      if (taskIndex === index) {
        return {
          id: task.id,
          title: task.title,
          subject: task.subject,
          minutes: task.minutes,
          completed: completed,
          source: task.source,
          createdAt: task.createdAt,
          completedAt: completed ? Date.now() : 0,
          goalId: task.goalId,
          milestoneId: task.milestoneId
        };
      }
      return task;
    });
    if (changedTask !== undefined) { this.advanceGoalMilestone(changedTask, completed); }
    this.persistSilently();
  }

  private addTask(): void {
    const title: string = this.newTaskTitle.trim();
    if (title.length === 0) {
      return;
    }
    this.tasks = this.tasks.concat([{
      id: `manual-${Date.now()}`,
      title: title,
      subject: '自定义任务',
      minutes: 25,
      completed: false,
      source: 'manual',
      createdAt: Date.now(),
      completedAt: 0
    }]);
    this.newTaskTitle = '';
    this.persistSilently();
  }

  private learningContextInput(text: string, appendMode: boolean = false,
    planningBudget?: number): LearningContextInput {
    const metrics: StudyMetrics = this.studyMetrics();
    const goals: AcademicGoal[] = this.academicGoals.filter((goal: AcademicGoal) => !goal.completed);
    const subjects: string[] = Array.from(new Set(goals.map((goal: AcademicGoal) => goal.subject).concat(
      this.tasks.filter((task: StudyTask) => !task.completed).map((task: StudyTask) => task.subject))));
    const activeOverride: TodayStudyOverride | undefined = this.todayStudyOverride.date === this.beijingDayKey() ?
      this.todayStudyOverride : undefined;
    const realSchedule: boolean = this.setupScheduleReady && this.scheduleItems.length > 0 &&
      this.scheduleItems.every((item: ScheduleItem) => !item.id.startsWith('demo-'));
    const dailyTargetRemaining: number = LearningActionService.budget(this.snapshot());
    const decision: AgentDecisionResult = AgentDecisionService.decide(this.snapshot(), this.actionClock);
    const confirmedMinutes: number | undefined = activeOverride?.availableMinutes;
    return {
      academicGoals: this.academicGoals,
      todayStudyOverride: activeOverride,
      confirmedAvailableMinutes: this.bankPlanMode && planningBudget !== undefined ? planningBudget : confirmedMinutes,
      localDailyPlanTaskIds: decision.dailyPlan.map(item => item.taskId),
      localDailyPlanMinutes: decision.dailyPlan.map(item => item.suggestedMinutes),
      eligibleTaskIds: LearningActionService.candidates(this.snapshot(), this.actionClock)
        .map(item => item.task.id ?? '').filter(id => id.length > 0),
      protectedTaskId: decision.recommendedAction.stage === 'resume' ||
        decision.recommendedAction.stage === 'verify' ? decision.recommendedAction.taskId : undefined,
      protectedStage: decision.recommendedAction.stage,
      recentFocusRecords: this.focusRecords.length > 0 ? this.focusRecords.slice(-5) : undefined,
      remainingBudget: this.bankPlanMode ? planningBudget : dailyTargetRemaining,
      dailyTargetRemainingMinutes: dailyTargetRemaining,
      appendMode: appendMode,
      requestText: text,
      profile: {
        name: this.profileName,
        grade: this.profileGrade,
        major: this.profileMajor,
        goal: goals.length > 0 ? goals.map((goal: AcademicGoal) => goal.title).join('；') : this.profileGoal,
        subject: subjects.length > 1 ? '多个课程' : subjects[0] ?? this.profileSubject,
        examDate: goals.length === 1 ? goals[0].deadline :
          this.profileExamDateConfirmed ? this.profileExamDate : '',
        dailyMinutes: this.profileDailyMinutes,
        preferredTime: this.profilePreferredTime,
        learningStyle: this.profileLearningStyle,
        supportStyle: this.profileSupportStyle
      },
      date: this.beijingDayKey(),
      examDays: goals.length === 1 ? GoalPlanningService.daysUntil(goals[0].deadline) :
        this.profileExamDateConfirmed ? this.examDays() : 999,
      energyState: this.energyState,
      scheduleReady: realSchedule,
      scheduleItems: realSchedule ? this.scheduleItems : [],
      tasks: this.tasks.filter((task: StudyTask) => TodayStudyOverrideService.currentTask(task, activeOverride)),
      metrics: metrics,
      quizAttempts: [],
      knowledgeMastery: [],
      bankEvidence: [],
      bankAppendMode: this.bankPlanMode,
      bankTopicId: this.bankPlanMode ? this.bankTopicId : undefined
    };
  }

  private setAgentPreview(plan: AgentPlan): void {
    this.agentPreviewTasks = plan.tasks;
    this.agentPreviewSubject = plan.detectedSubject;
    this.agentPlanSummary = plan.summary;
    this.agentRecommendationReasons = plan.recommendationReasons;
    this.agentPlanSource = plan.source;
    this.agentGenerated = true;
  }

  private previewPlan(): AgentPlan {
    const usage: AgentUsage = {
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0
    };
    return {
      summary: this.agentPlanSummary,
      detectedSubject: this.agentPreviewSubject,
      recommendationReasons: this.agentRecommendationReasons,
      tasks: this.agentPreviewTasks,
      totalMinutes: this.agentPreviewTasks.reduce((total: number, task: AgentGeneratedTask) => {
        return total + task.minutes;
      }, 0),
      source: this.agentPlanSource,
      model: this.agentPlanSource === 'openpangu' ? 'openpangu' : 'local-policy',
      usage: usage
    };
  }

  private generateTodayPlan(): void {
    const text: string = this.agentInput.trim();
    if (text.length === 0 || this.agentLoading || this.agentCommitBusy) {
      this.agentError = text.length === 0 ? '请先描述今天需要完成的事情' : '';
      return;
    }
    this.requestTodayPlan(text, false);
  }

  private addFloatingMessage(role: string, text: string, mode: string): void {
    const createdAt: number = Date.now();
    this.floatingAgentMessages = this.floatingAgentMessages.concat([{
      id: `${mode}-${role}-${createdAt}-${this.floatingAgentMessages.length}`,
      role: role, text: text, mode: mode, createdAt: createdAt
    } as AgentConversationMessage]);
  }

  private openFloatingPlanning(prefill: string = ''): void {
    this.floatingAgentMode = 'planning';
    this.floatingAgentHintVisible = false;
    this.floatingAgentOpen = true;
    if (prefill.length > 0) { this.floatingAgentInput = prefill; }
  }

  private sendFloatingAgent(): void {
    const text: string = this.floatingAgentInput.trim();
    if (text.length === 0 || this.agentLoading || this.agentCommitBusy || this.floatingSupportBusy) { return; }
    const mode: string = this.floatingAgentMode;
    const supportHistory: EmotionalSupportMessage[] = this.floatingAgentMessages
      .filter((message: AgentConversationMessage) => message.mode === 'support')
      .slice(-8).map((message: AgentConversationMessage): EmotionalSupportMessage => ({
        id: message.id, role: message.role, text: message.text, createdAt: message.createdAt
      }));
    this.floatingAgentInput = '';
    this.floatingAgentError = '';
    this.addFloatingMessage('user', text, mode);
    if (mode === 'planning') {
      this.agentInput = text;
      this.requestTodayPlan(text, false, true);
      return;
    }
    this.floatingSupportBusy = true;
    EmotionalSupportClient.reply(text, supportHistory).then((response) => {
      this.floatingSupportSource = response.source ?? '';
      this.addFloatingMessage('assistant', response.reply ?? '我在听。', 'support');
    }).catch((error: Error) => {
      this.floatingAgentError = error.message.length > 0 ? error.message : '星球暂时没有回应，请稍后再试';
    }).finally(() => { this.floatingSupportBusy = false; });
  }

  private todayCourseHint(): string {
    if (!this.setupScheduleReady) { return '未导入 · 点此添加课表'; }
    if (this.scheduleItems.some((item: ScheduleItem) => item.id.startsWith('demo-'))) {
      return '演示课表 · 点此导入真实课表';
    }
    const date: Date = new Date(this.actionClock + 8 * 3600000);
    const minute: number = date.getUTCHours() * 60 + date.getUTCMinutes();
    const clock = (value: string): number => {
      const parts: string[] = value.split(':');
      return Number(parts[0]) * 60 + Number(parts[1]);
    };
    const courses: ScheduleItem[] = this.scheduleItems.filter((item: ScheduleItem) =>
      item.weekday === (date.getUTCDay() || 7)).sort((a: ScheduleItem, b: ScheduleItem) =>
      clock(a.startTime) - clock(b.startTime));
    if (courses.length === 0) { return '今天没有课程'; }
    const current: ScheduleItem | undefined = courses.find((item: ScheduleItem) =>
      clock(item.startTime) <= minute && clock(item.endTime) > minute);
    if (current !== undefined) { return `正在上课 · ${current.course} · ${current.endTime} 下课`; }
    const next: ScheduleItem | undefined = courses.find((item: ScheduleItem) => clock(item.startTime) > minute);
    return next !== undefined ? `${courses.length} 节 · 下一节 ${next.startTime} ${next.course}` :
      `今日 ${courses.length} 节课已结束`;
  }

  private requestTodayPlan(text: string, feedbackMode: boolean, fromFloating: boolean = false): void {
    if (this.agentLoading || this.agentCommitBusy) {
      return;
    }
    this.floatingPlanPending = fromFloating;
    if (feedbackMode) { this.bankPlanMode = false; }
    const dailyTargetRemaining: number = this.availableMinutesToday();
    let planningBudget: number = LearningDecisionPolicy.planningBudget(
      text, dailyTargetRemaining, this.profileDailyMinutes);
    if (this.bankPlanMode) {
      try {
        planningBudget = BankPlanBudget.available(dailyTargetRemaining, this.tasks);
        if (planningBudget < 5) {
          throw new Error('扣除原待办后不足 5 分钟可追加时间，请先完成或调整原计划；不会删除原任务或超配时间');
        }
      } catch (error) {
        this.agentError = error instanceof Error ? error.message : '无法核算待办时间，请检查原计划';
        if (fromFloating) { this.floatingAgentError = this.agentError; }
        this.agentGenerated = false;
        this.agentPreviewTasks = [];
        this.floatingPlanPending = false;
        return;
      }
    }
    this.agentPlanBudget = planningBudget;
    this.agentLoading = true;
    this.agentFeedbackMode = feedbackMode;
    this.agentError = '';
    if (!feedbackMode) {
      this.agentAcceptedMessage = '';
    }
    this.agentGenerated = false;
    this.agentPreviewTasks = [];
    if (fromFloating) { this.floatingAcceptedMessage = ''; }
    const requestId: number = this.agentRequestId + 1;
    this.agentRequestId = requestId;
    const input: LearningContextInput = this.learningContextInput(text, fromFloating, planningBudget);
    const request: AgentPlanRequest = LearningDecisionPolicy.buildRequest(input);
    const policyReasons: string[] = LearningDecisionPolicy.priorityEvidence(input);
    LearningPlanningOrchestrator.decide(request, policyReasons).then((decision: PlanningDecision) => {
      if (requestId !== this.agentRequestId || !this.profileCompleted) {
        return;
      }
      this.setAgentPreview(decision.plan);
      this.agentError = decision.notice;
      if (fromFloating) {
        this.addFloatingMessage('assistant', decision.plan.summary.length > 0 ? decision.plan.summary :
          '我整理了已有任务的学习节奏；确认后会把第一项设为今天优先。', 'planning');
      }
    }).catch((error: Error) => {
      if (requestId !== this.agentRequestId || !this.profileCompleted) {
        return;
      }
      this.agentError = error.message.length > 0 ? error.message : '学习决策链暂不可用，请稍后重试';
      if (fromFloating) { this.floatingAgentError = this.agentError; }
    }).finally(() => {
      if (requestId === this.agentRequestId) {
        this.agentLoading = false;
      }
    });
  }

  private acceptAgentPlan(): void {
    if (this.agentCommitBusy) { return; }
    if (this.agentPreviewTasks.length === 0) {
      return;
    }
    if (this.bankPlanMode) { this.acceptBankPlan(); return; }
    const wasFloating: boolean = this.floatingPlanPending;
    try {
      // Recheck against current storage: a task may have been completed while the model was responding.
      const currentRequest: AgentPlanRequest = LearningDecisionPolicy.buildRequest(
        this.learningContextInput(this.agentInput, wasFloating));
      const accepted: AgentPlan = PlanValidator.validateExisting(this.previewPlan(), currentRequest);
      const stage: string = currentRequest.context.protectedStage ?? '';
      if (stage !== 'resume' && stage !== 'verify') {
        const firstId: string = accepted.tasks[0].taskId ?? '';
        const active: TodayStudyOverride = this.todayStudyOverride.date === this.beijingDayKey() ?
          this.todayStudyOverride : { date: this.beijingDayKey() };
        this.todayStudyOverride = { date: active.date, availableMinutes: active.availableMinutes,
          preferredTaskId: firstId, preferredSubject: active.preferredSubject,
          skippedTaskIds: active.skippedTaskIds, temporaryTaskIds: active.temporaryTaskIds };
      }
      this.agentAcceptedMessage = stage === 'resume' || stage === 'verify' ?
        '当前专注或学习反馈优先保留，完成后星球会重新安排' :
        '已把这项设为今天优先处理；后续会随完成情况重新安排';
      this.agentRequestId += 1;
      this.agentGenerated = false;
      this.floatingPlanPending = false;
      if (wasFloating) { this.floatingAcceptedMessage = this.agentAcceptedMessage; }
      this.agentFeedbackMode = false;
      this.bankPlanMode = false;
      this.persistSilently();
    } catch (error) {
      this.agentError = error instanceof Error ? error.message : '已有任务发生变化，请重新安排';
      if (wasFloating) { this.floatingAgentError = this.agentError; }
    }
  }

  private async acceptBankPlan(): Promise<void> {
    this.agentCommitBusy = true;
    const originalIds: string[] = this.tasks.map((task: StudyTask) => task.id ?? '');
    let addedIds: string[] = [];
    try {
      const committed: PlanCommitResult = PlanCommitService.appendBankPlan(this.tasks, this.previewPlan(), this.availableMinutesToday());
      addedIds = committed.tasks.filter((task: StudyTask) => !originalIds.includes(task.id ?? ''))
        .map((task: StudyTask) => task.id ?? '');
      this.tasks = committed.tasks;
      await this.ensureProfileStore();
      if (this.repository === undefined) { throw new Error('无法打开学习存储'); }
      await this.persistenceQueue;
      const snapshot: StudyStateSnapshot = this.snapshot();
      await this.repository.saveChecked(snapshot);
      this.agentRequestId++;
      this.agentGenerated = false;
      this.bankPlanMode = false;
      this.agentAcceptedMessage = addedIds.length === 0 ? '相同补学任务已在计划中，未重复添加' :
        `已追加 ${addedIds.length} 项补学任务，原有待办与当前专注保持不变`;
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        StudyWidgetService.updateAll(context, snapshot).catch((error: Error) => {
          console.error(`Index: bank plan saved but widget refresh failed: ${error.message}`);
        });
      }
    } catch (error) {
      this.tasks = this.tasks.filter((task: StudyTask) => !addedIds.includes(task.id ?? ''));
      this.agentError = error instanceof Error ? `补学计划未确认：${error.message}` : '补学计划保存失败，请重试。';
    } finally { this.agentCommitBusy = false; }
  }

  private planProgress(): number {
    return this.studyMetrics().planProgress;
  }

  private availableMinutesToday(): number {
    return LearningActionService.budget(this.snapshot());
  }

  onBackPress(): boolean {
    if (this.orbitImmersive || this.orbitChanging) { this.exitOrbit(); return true; }
    if (this.scheduleScannerOpen) { this.cancelScheduleScanner(); return true; }
    if (this.floatingAgentOpen) { this.floatingAgentOpen = false; return true; }
    if ([1, 7, 9, 10].includes(this.currentTab)) { this.currentTab = 8; return true; }
    if (this.currentTab === 6) {
      this.currentTab = this.videoReturnTab;
      return true;
    }
    return false;
  }

  private async addVideoTask(video: LearningVideo): Promise<void> {
    const id: string = `video-${video.id}`;
    if (this.tasks.some((task: StudyTask) => task.id === id)) { return; }
    const task: StudyTask = {
      id: id, title: `观看与记录：${video.title}`, subject: VideoCatalog.module(video.moduleId).title,
      minutes: 15, completed: false, source: 'video-library', createdAt: Date.now(), completedAt: 0
    };
    this.tasks = this.tasks.concat([task]);
    try {
      await this.persistState();
    } catch (error) {
      this.tasks = this.tasks.filter((item: StudyTask) => item.id !== id);
      throw new Error('视频任务保存失败');
    }
  }

  private plannedVideoIds(): string[] {
    return this.tasks.filter((task: StudyTask) => task.source === 'video-library')
      .map((task: StudyTask) => (task.id ?? '').substring(6));
  }

  private openCurrentVideo(): void {
    const taskId: string = this.currentTask().id ?? '';
    const video: LearningVideo | undefined = VideoCatalog.all().find((item: LearningVideo) => `video-${item.id}` === taskId);
    if (video !== undefined) {
      this.videoModuleId = video.moduleId;
      this.videoInitialQuery = video.title;
      this.videoReturnTab = 3;
      this.currentTab = 6;
    }
  }

  private async addBankReview(sessionId: string, skills: string, topicId: string = 'matrix'): Promise<void> {
    const id: string = `bank-${sessionId}`;
    if (this.tasks.some((task: StudyTask) => task.id === id)) { return; }
    const task: StudyTask = {
      id: id, title: `${QuestionBank.topic(topicId).title}巩固：${skills}`, subject: QuestionBank.topic(topicId).subject, minutes: 15,
      completed: false, source: 'question-bank', createdAt: Date.now(), completedAt: 0
    };
    this.tasks = this.tasks.concat([task]);
    try { await this.persistState(); } catch (error) {
      this.tasks = this.tasks.filter((item: StudyTask) => item.id !== id);
      throw new Error('巩固任务保存失败');
    }
  }

  private bottomTabIndex(): number {
    if (this.currentTab === 0) {
      return 0;
    }
    if ([1, 7, 8, 9, 10].includes(this.currentTab) ||
      (this.currentTab === 6 && [7, 9].includes(this.videoReturnTab))) {
      return 1;
    }
    if (this.currentTab === 3 || this.currentTab === 4 || this.currentTab === 6) {
      return 2;
    }
    return 3;
  }

  private selectBottomTab(index: number): void {
    const targetTab: number = index === 0 ? 0 : (index === 1 ? 8 : (index === 2 ? 3 : 5));
    if (this.currentTab !== targetTab) { this.floatingAgentHintVisible = false; }
    if (index === 0) {
      this.currentTab = 0;
    } else if (index === 1) {
      this.currentTab = 8;
    } else if (index === 2) {
      this.currentTab = 3;
    } else {
      this.currentTab = 5;
    }
  }

  private submitQuiz(): void {
    if (this.currentTask().completed || TaskOutcomeService.kind(this.currentTask()) !== 'quiz' || !this.quizPending) { return; }
    if (this.quizChoice.length === 0) {
      return;
    }
    if (this.quizSubmitted) {
      return;
    }
    const question: QuizQuestion = this.currentQuizQuestion();
    const correct: boolean = QuizService.isCorrect(question, this.quizChoice);
    const task: StudyTask = this.currentTask();
    this.quizSubmitted = true;
    this.quizAttempts = this.quizAttempts.concat([
      StudyDataCenter.createQuizAttempt(
        question.id,
        task.subject,
        task.id ?? '',
        question.knowledgePoint,
        this.quizChoice,
        correct,
        this.studyDayKey
      )
    ]);
    this.knowledgeMastery = KnowledgeMasteryService.update(
      this.knowledgeMastery,
      task.subject,
      question.knowledgePoint,
      correct
    );
    const updatedMastery: KnowledgeMastery | undefined = KnowledgeMasteryService.latest(this.knowledgeMastery);
    this.recordTaskResult(this.currentTaskIndex, correct, correct ? '本次小测通过' : '本次小测待巩固');
    this.agentAcceptedMessage = correct ? '本次小测通过，任务已推进' : '答题已记录，先巩固再验证';
    this.quizFeedbackMessage = correct ?
      `回答正确：${question.explanation} “${question.knowledgePoint}”掌握度更新为${updatedMastery?.score ?? 0}%。` :
      `还差一点：${question.explanation} “${question.knowledgePoint}”掌握度为${updatedMastery?.score ?? 0}%，已记录为待巩固。`;
    this.persistSilently();
    const resultText: string = correct ? '回答正确' : '回答错误';
    const adjustmentRequest: string = `我刚完成“${task.title}”，即时小测${resultText}，知识点是“${question.knowledgePoint}”。请结合今天剩余时间、未完成任务和这次测验反馈，调整接下来要做的事。`;
    this.agentInput = adjustmentRequest;
    this.requestTodayPlan(adjustmentRequest, true);
  }

  build() {
    if (this.orbitImmersive) {
      ImmersiveOrbit({ members: this.squadMembersForDisplay(), isRunning: this.isRunning,
        remainingSeconds: this.remainingSeconds,
        collectiveMinutes: this.collectiveFocusMinutes(), selfProgress: this.currentFocusProgress(),
        onExit: () => { this.exitOrbit(); } })
    } else if (this.scheduleScannerOpen) {
      ScheduleScannerPageView({
        onScanned: (uri: string) => { this.recognizeScannedSchedule(uri); },
        onCancel: () => { this.cancelScheduleScanner(); }
      })
    } else if (!this.profileLoaded) {
      LoadingPageView()
    } else if (!this.profileCompleted) {
      ProfileSetupPageView({
        profileAvatarUri: this.profileAvatarUri,
        avatarStatus: this.avatarStatus,
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
        scheduleImportStatus: this.scheduleImportStatus,
        scheduleImportMessage: this.scheduleImportMessage,
        scheduleImportSource: this.scheduleImportSource,
        scheduleDraftItems: this.scheduleDraftItems,
        onTextChange: (field: string, value: string) => {
          if (field === 'name') {
            this.profileName = value;
          } else if (field === 'major') {
            this.profileMajor = value;
          } else if (field === 'subject') {
            this.profileSubject = value;
          } else if (field === 'examDate') {
            this.profileExamDate = value;
            this.profileExamDateConfirmed = value.trim().length > 0;
          }
        },
        onSelectAvatar: () => {
          this.selectAvatar();
        },
        onChoiceChange: (group: string, value: string) => {
          this.setChoice(group, value);
        },
        onUseDemoSchedule: () => {
          this.useDemoSchedule();
        },
        onScanSchedule: () => {
          this.openScheduleScanner();
        },
        onImportSchedule: () => {
          this.importScheduleImage();
        },
        onConfirmSchedule: () => {
          this.confirmScheduleImport();
        },
        onScheduleDraftItemsChange: (items: ScheduleItem[]) => {
          this.updateScheduleDraftItems(items);
        },
        onSaveProfile: () => {
          this.saveProfile();
        }
      })
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        Column() {
        if (this.currentTab === 0) {
          HomePageView({
            courseHint: this.todayCourseHint(),
            onOpenSchedule: () => {
              this.floatingAgentHintVisible = false;
              this.currentTab = 10;
            },
            onRetrySave: () => {
              this.persistState().then(() => { this.actionMessage = '已保存'; }).catch(() => {
                this.actionMessage = '更改仍未保存，请检查存储空间后重试';
              });
            },
            actionMessage: this.actionMessage,
            hasDeferrals: this.actionDeferrals.some((item: ActionDeferral) => item.until > this.actionClock),
            onDefer: (kind: string) => { this.deferAction(kind); },
            onUndoDeferral: () => { this.undoDeferral(); },
            planetStage: PlanetGrowthService.calculate(this.focusRecords, this.quizAttempts, this.bankStudyDays).stage,
            streakDays: StudyDataCenter.learningStreak(this.focusRecords, this.quizAttempts, this.bankStudyDays),
            bankEvidence: this.bankEvidence,
            bankEvidenceError: this.bankEvidenceError,
            onOpenQuestionBank: () => {
              this.openFloatingPlanning('请根据我的题库表现，帮我安排今天的巩固任务。');
            },
            onPlanFromBank: () => {
              this.openFloatingPlanning('请根据我的错题和薄弱知识点，追加一份今天能完成的补学安排。');
            },
            profileAvatarUri: this.profileAvatarUri,
            profileName: this.profileName,
            greeting: this.beijingGreeting(),
            profileSubject: this.profileSubject,
            examDays: this.examDays(),
            todayTimeText: this.todayTimeText(),
            completedCount: this.completedCount(),
            masteryPoint: this.masteryPoint(),
            masteryScore: this.masteryScore(),
            masteryStatus: this.masteryStatus(),
            tasks: this.tasks,
            recommendationTitle: this.recommendation().title,
            recommendationSubject: this.recommendation().subject,
            recommendationReason: this.recommendation().reason,
            recommendationMinutes: this.recommendation().minutes,
            recommendationTaskIndex: this.recommendation().taskIndex,
            recommendationAllDone: this.recommendation().allDone,
            recommendationEvidence: this.recommendation().evidence,
            timelineTime: this.recommendation().timelineTime,
            timelineTitle: this.recommendation().timelineTitle,
            timelineDetail: this.recommendation().timelineDetail,
            showRecommendationDetails: this.showRecommendationDetails,
            actionEnabled: true,
            activeGoalTitle: this.profileExamDateConfirmed ? this.activeGoal()?.goal.title ?? '' : '',
            activeGoalReason: this.profileExamDateConfirmed ? this.activeGoal()?.reason ?? '' : '',
            decision: this.agentDecision(),
            onPrimaryAction: () => {
              this.floatingAgentHintVisible = false;
              this.runDailyAction();
            },
            todayStudyOverride: this.todayStudyOverride.date === this.beijingDayKey() ?
              this.todayStudyOverride : { date: this.beijingDayKey() },
            todayDate: this.beijingDayKey(),
            onAdjustToday: (override: TodayStudyOverride, title: string, subject: string, minutes: number) => {
              this.adjustTodayTask(override, title, subject, minutes);
            },
            onDeleteTask: async (taskId: string): Promise<string> => {
              return this.deleteTodayTask(taskId);
            },
            onManageToday: () => {
              this.floatingAgentHintVisible = false;
              this.currentTab = 1;
            },
            onStartFocus: (index: number) => {
              this.floatingAgentHintVisible = false;
              this.beginFocus(index);
            },
            onToggleRecommendationDetails: () => {
              this.showRecommendationDetails = !this.showRecommendationDetails;
            },
            onToggleTask: (index: number, completed: boolean) => {
              this.setTaskCompleted(index, completed);
            },
            onBusinessOverlayChange: (visible: boolean) => {
              this.businessOverlayOpen = visible;
              if (visible) { this.floatingAgentHintVisible = false; }
            }
          })
        } else if (this.currentTab === 1 || this.currentTab === 10) {
          PlanPageView({
            scheduleOnly: this.currentTab === 10,
            onBack: () => { this.currentTab = 8; },
            setupScheduleReady: this.setupScheduleReady,
            scheduleItems: this.scheduleItems,
            scheduleImportStatus: this.scheduleImportStatus,
            scheduleImportMessage: this.scheduleImportMessage,
            scheduleImportSource: this.scheduleImportSource,
            scheduleDraftItems: this.scheduleDraftItems,
            newTaskTitle: this.newTaskTitle,
            profileSubject: this.profileSubject,
            profileExamDate: this.profileExamDate,
            examDays: this.examDays(),
            tasks: this.tasks,
            academicGoals: this.academicGoals,
            newGoalTitle: this.newGoalTitle,
            newGoalSubject: this.newGoalSubject,
            newGoalDeadline: this.newGoalDeadline,
            newGoalEstimatedMinutes: this.newGoalEstimatedMinutes,
            onGoalFieldChange: (field: string, value: string) => {
              if (field === 'title') { this.newGoalTitle = value; }
              else if (field === 'subject') { this.newGoalSubject = value; }
              else if (field === 'minutes') { this.newGoalEstimatedMinutes = value; }
              else { this.newGoalDeadline = value; }
            },
            onAddGoal: () => { this.addAcademicGoal(); },
            onToggleGoal: (id: string) => { this.toggleAcademicGoal(id); },
            onUpdateGoal: async (id: string, title: string, subject: string,
              deadline: string, estimatedMinutes: number): Promise<boolean> => {
              return await this.updateAcademicGoal(id, title, subject, deadline, estimatedMinutes);
            },
            onOpenLearning: () => {
              this.openFloatingPlanning('请结合我的目标和今日待办，帮我安排下一步。');
            },
            onUseDemoSchedule: () => {
              this.useDemoSchedule();
            },
            onScanSchedule: () => {
              this.openScheduleScanner();
            },
            onImportSchedule: () => {
              this.importScheduleImage();
            },
            onConfirmSchedule: () => {
              this.confirmScheduleImport();
            },
            onScheduleDraftItemsChange: (items: ScheduleItem[]) => {
              this.updateScheduleDraftItems(items);
            },
            onSaveSchedule: async (items: ScheduleItem[]): Promise<boolean> => {
              return await this.saveScheduleEdits(items);
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
        } else if (this.currentTab === 3) {
          FocusPageView({
            onVisibilityChange: (visible: boolean) => { this.orbitPageVisible = visible; },
            onEnterImmersive: () => { this.enterOrbit(); },
            resultPending: !this.currentTask().completed && (this.currentTask().outcome === 'focused' || this.currentTask().outcome === 'submitted'),
            resultKind: TaskOutcomeService.kind(this.currentTask()),
            resultNote: this.resultNote,
            resultChecked: this.resultChecked,
            resultExperience: this.resultExperience,
            onResultNote: (value: string) => { this.resultNote = value; },
            onResultChecked: (value: boolean) => { this.resultChecked = value; },
            onResultExperience: (value: string) => { this.resultExperience = value; },
            onSubmitResult: () => { this.submitSelfResult(); },
            onOpenResult: () => { this.openTaskResult(this.currentTaskIndex); },
            onNextAction: () => { this.currentTab = 0; },
            videoTask: this.currentTask().source === 'video-library',
            onOpenVideo: () => { this.openCurrentVideo(); },
            currentTaskTitle: this.currentTask().title,
            currentTaskCompleted: this.currentTask().completed,
            remainingSeconds: this.remainingSeconds,
            isRunning: this.isRunning,
            todayTimeText: this.todayTimeText(),
            todayFocusSessionCount: this.studyMetrics().todayFocusSessionCount,
            quizPending: this.quizPending,
            quizPrompt: this.currentQuizQuestion().prompt,
            quizOptionA: this.currentQuizQuestion().optionA,
            quizOptionB: this.currentQuizQuestion().optionB,
            quizOptionC: this.currentQuizQuestion().optionC,
            quizOptionD: this.currentQuizQuestion().optionD,
            quizChoice: this.quizChoice,
            quizSubmitted: this.quizSubmitted,
            quizFeedbackMessage: this.quizFeedbackMessage,
            masteryPoint: this.masteryPoint(),
            masteryScore: this.masteryScore(),
            masteryStatus: this.masteryStatus(),
            agentLoading: this.agentLoading,
            agentPlanReady: this.agentGenerated && this.agentFeedbackMode,
            agentError: this.agentError,
            squadMembers: this.squadMembersForDisplay(),
            selfTaskProgress: this.currentFocusProgress(),
            collectiveFocusMinutes: this.collectiveFocusMinutes(),
            onQuietSignal: (memberId: string, signal: string) => {
              this.sendQuietSignal(memberId, signal);
            },
            onOpenGrowth: () => {
              this.currentTab = 4;
            },
            onPause: () => {
              this.pauseFocus();
            },
            onContinue: () => {
              this.startTimer();
            },
            onRestart: () => {
              this.quizPending = false;
              this.quizQuestionId = '';
              this.quizChoice = '';
              this.quizSubmitted = false;
              this.quizFeedbackMessage = '';
              this.resetFocus();
              this.startTimer();
            },
            onReset: () => {
              this.resetFocus();
            },
            onFinish: () => {
              this.finishFocus();
            },
            onQuizChoiceChange: (value: string) => {
              if (!this.quizSubmitted) {
                this.quizChoice = value;
              }
            },
            onSubmitQuiz: () => {
              this.submitQuiz();
            },
            onOpenAdjustment: () => {
              this.bankPlanMode = false;
              this.openFloatingPlanning(`我在学习“${this.currentTask().title}”时还有困难。${this.resultNote.trim()} 请帮我拆成更小的补学步骤。`);
            }
          })
        } else if (this.currentTab === 4) {
          GrowthPageView({
            planet: PlanetGrowthService.calculate(this.focusRecords, this.quizAttempts, this.bankStudyDays),
            squadMessage: this.squadMessage,
            squadMembers: this.squadMembersForDisplay(),
            squadInviteCode: this.squadInviteCode,
            squadChallengeTitle: this.squadChallengeTitle,
            // 新挑战跟随当前番茄钟时长；已有挑战继续显示创建时的时长。
            squadChallengeMinutes: this.squadChallengeActive ? this.squadChallengeMinutes : this.focusMinutes,
            squadChallengeJoinedCount: this.squadChallengeJoinedCount,
            squadChallengeActive: this.squadChallengeActive,
            onOpenFocus: () => {
              this.currentTab = 3;
            },
            onEncourageMember: (memberId: string) => {
              this.encourageSquadMember(memberId);
            },
            onCreateInvite: () => {
              this.createSquadInvite();
            },
            onCreateChallenge: () => {
              this.createSquadChallenge();
            },
            onOpenVideos: (moduleId: string) => {
              this.videoModuleId = moduleId;
              this.videoInitialQuery = '';
              this.videoReturnTab = 4;
              this.currentTab = 6;
            }
          })
        } else if (this.currentTab === 6) {
          VideoLibraryPageView({
            moduleId: this.videoModuleId,
            initialQuery: this.videoInitialQuery,
            backLabel: this.videoReturnTab === 9 ? '返回学习资料' : this.videoReturnTab === 7 ? '返回诊断' : this.videoReturnTab === 3 ? '返回专注' : '返回小队',
            plannedVideoIds: this.plannedVideoIds(),
            onBack: () => { this.currentTab = this.videoReturnTab; },
            onAddTask: async (video: LearningVideo): Promise<void> => { await this.addVideoTask(video); }
          })
        } else {
          if (this.currentTab === 8) {
            LearningHubPageView({
              decision: this.agentDecision(),
              now: this.actionClock,
              todayTimeText: this.todayTimeText(),
              completedCount: this.completedCount(),
              setupScheduleReady: this.setupScheduleReady,
              scheduleItems: this.scheduleItems,
              scheduleImportStatus: this.scheduleImportStatus,
              scheduleImportMessage: this.scheduleImportMessage,
              scheduleImportSource: this.scheduleImportSource,
              scheduleDraftItems: this.scheduleDraftItems,
              academicGoals: this.academicGoals,
              planetStage: PlanetGrowthService.calculate(this.focusRecords, this.quizAttempts, this.bankStudyDays).stage,
              onPrimaryAction: () => { this.runDailyAction(); },
              onOpenSchedule: () => { this.currentTab = 10; },
              onScanSchedule: () => { this.openScheduleScanner(); },
              onImportSchedule: () => { this.importScheduleImage(); },
              onConfirmSchedule: () => { this.confirmScheduleImport(); },
              onScheduleDraftItemsChange: (items: ScheduleItem[]) => {
                this.updateScheduleDraftItems(items);
              },
              onOpen: (destination: number) => { this.currentTab = destination; }
            })
          } else if (this.currentTab === 9) {
            LearningResourcesPageView({
              onBack: () => { this.currentTab = 8; },
              onSelect: (moduleId: string) => {
                this.videoModuleId = moduleId;
                this.videoInitialQuery = '';
                this.videoReturnTab = 9;
                this.currentTab = 6;
              }
            })
          } else {
          ProfilePageView({
            profileAvatarUri: this.profileAvatarUri,
            avatarStatus: this.avatarStatus,
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
            todayTimeText: this.todayTimeText(),
            completedTaskCount: this.studyMetrics().completedTaskCount,
            totalTaskCount: this.studyMetrics().totalTaskCount,
            planProgress: this.studyMetrics().planProgress,
            notificationEnabled: this.notificationEnabled,
            notificationClassEnabled: this.notificationClassEnabled,
            notificationReviewEnabled: this.notificationReviewEnabled,
            notificationTaskEnabled: this.notificationTaskEnabled,
            notificationQuietHoursEnabled: this.notificationQuietHoursEnabled,
            notificationQuietStart: this.notificationQuietStart,
            notificationQuietEnd: this.notificationQuietEnd,
            notificationStatus: this.notificationStatus,
            onEnergyChange: (value: string) => {
              this.energyState = value;
              this.persistSilently();
            },
            onSelectAvatar: () => {
              this.selectAvatar();
            },
            onNotificationEnabledChange: (enabled: boolean) => {
              this.setNotificationEnabled(enabled);
            },
            onNotificationOptionChange: (option: string, enabled: boolean) => {
              this.setNotificationOption(option, enabled);
            },
            onSendTestNotification: () => {
              this.sendTestNotification();
            },
            onResetProfile: () => {
              this.resetProfile();
            }
          })
        }
        }
          BottomNavigation({
            currentTab: this.bottomTabIndex(),
            darkMode: this.currentTab === 3,
            onTabChange: (index: number) => {
              this.selectBottomTab(index);
            }
          })
        }
        .width('100%').height('100%').backgroundColor(this.currentTab === 3 ? '#151620' : '#F6F7FC')
        FloatingAgent({
          open: this.floatingAgentOpen,
          mode: this.floatingAgentMode,
          input: this.floatingAgentInput,
          messages: this.floatingAgentMessages,
          busy: this.agentLoading || this.agentCommitBusy || this.floatingSupportBusy,
          error: this.floatingAgentError,
          planReady: this.agentGenerated && this.floatingPlanPending,
          planSummary: this.agentPlanSummary,
          planTasks: this.agentPreviewTasks,
          acceptedMessage: this.floatingAcceptedMessage,
          planSource: this.agentPlanSource,
          supportSource: this.floatingSupportSource,
          planetStage: PlanetGrowthService.calculate(this.focusRecords, this.quizAttempts, this.bankStudyDays).stage,
          showHint: this.currentTab === 0 && this.floatingAgentHintVisible,
          interactive: !this.businessOverlayOpen,
          onHintDismiss: () => { this.floatingAgentHintVisible = false; },
          onToggle: () => {
            this.floatingAgentHintVisible = false;
            this.floatingAgentOpen = !this.floatingAgentOpen;
          },
          onClose: () => { this.floatingAgentOpen = false; },
          onModeChange: (mode: string) => {
            this.floatingAgentMode = mode;
            this.floatingAgentInput = '';
            this.floatingAgentError = '';
          },
          onInputChange: (value: string) => { this.floatingAgentInput = value; },
          onSend: () => { this.sendFloatingAgent(); },
          onAcceptPlan: () => { this.acceptAgentPlan(); },
          onViewTasks: () => {
            this.floatingAgentOpen = false;
            this.currentTab = 0;
          }
        })
      }.width('100%').height('100%')
    }
  }
}
