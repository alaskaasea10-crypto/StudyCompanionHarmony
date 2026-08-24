import { preferences } from '@kit.ArkData';
import {
  createDemoSchedule,
  createDemoTasks,
  ScheduleItem,
  StudyStateSnapshot,
  StudyTask
} from '../models/StudyModels';
import { FocusClock } from '../services/FocusClock';
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

  private choiceValue(group: string): string {
    if (group === 'grade') {
      return this.profileGrade;
    }
    if (group === 'goal') {
      return this.profileGoal;
    }
    if (group === 'time') {
      return this.profilePreferredTime;
    }
    if (group === 'style') {
      return this.profileLearningStyle;
    }
    if (group === 'support') {
      return this.profileSupportStyle;
    }
    return this.profileDailyMinutes.toString();
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

  private formatTime(seconds: number): string {
    const minute: number = Math.floor(seconds / 60);
    const second: number = seconds % 60;
    return `${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}`;
  }

  private todayTimeText(): string {
    if (this.todayMinutes < 60) {
      return `${this.todayMinutes}分钟`;
    }
    const hour: number = Math.floor(this.todayMinutes / 60);
    const minute: number = this.todayMinutes % 60;
    return `${hour}小时${minute}分钟`;
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

  @Builder
  ChoiceChip(group: string, value: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.choiceValue(group) === value ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.choiceValue(group) === value ? Color.White : '#5F6478')
      .backgroundColor(this.choiceValue(group) === value ? '#5B5FEF' : '#F0F1F6')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .borderRadius(18)
      .onClick(() => {
        this.setChoice(group, value);
      })
  }

  @Builder
  SetupSection(number: string, title: string, subtitle: string) {
    Row({ space: 12 }) {
      Text(number)
        .width(32).height(32).textAlign(TextAlign.Center)
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .backgroundColor('#5B5FEF').borderRadius(16)
      Column({ space: 3 }) {
        Text(title).width('100%').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#25283A')
        Text(subtitle).width('100%').fontSize(12).fontColor('#9397A9')
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  LoadingPage() {
    Column({ space: 16 }) {
      Text('✦').fontSize(42).fontColor('#5B5FEF')
      Text('正在读取学习画像').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#25283A')
      Text('学伴正在准备你的个性化学习空间').fontSize(13).fontColor('#9397A9')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#F6F7FC')
  }

  @Builder
  SetupPage() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 7 }) {
          Text('✦ 第一次见面').width('100%').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          Text('先让学伴认识你').width('100%').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#202235')
          Text('这些信息只保存在本机，用来生成符合你真实情况的建议。以后可以在“我的”里重新设置。')
            .width('100%').fontSize(14).fontColor('#777C90').lineHeight(22)
        }
        .width('100%').padding({ top: 10, bottom: 4 })

        Column({ space: 14 }) {
          this.SetupSection('1', '基本信息', '称呼、年级与专业')
          TextInput({ placeholder: '希望学伴怎么称呼你', text: this.profileName })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.profileName = value;
            })
          Row({ space: 8 }) {
            this.ChoiceChip('grade', '大一', '大一')
            this.ChoiceChip('grade', '大二', '大二')
            this.ChoiceChip('grade', '大三', '大三')
            this.ChoiceChip('grade', '大四', '大四')
          }
          .width('100%')
          TextInput({ placeholder: '例如：计算机科学与技术', text: this.profileMajor })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.profileMajor = value;
            })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('2', '导入课表', '让 Agent 找到真正可用的学习时间')
          Row() {
            Column({ space: 4 }) {
              Text(this.setupScheduleReady ? '演示课表已就绪' : '暂未导入课表')
                .width('100%').fontSize(15).fontWeight(FontWeight.Bold)
              Text(this.setupScheduleReady ? '周一至周五课程已加入时间感知' : '现在可先使用演示课表，之后再接入 OCR')
                .width('100%').fontSize(12).fontColor('#9397A9')
            }
            .layoutWeight(1)
            Button(this.setupScheduleReady ? '已导入' : '使用演示课表')
              .height(38).fontSize(12)
              .fontColor(this.setupScheduleReady ? '#218764' : Color.White)
              .backgroundColor(this.setupScheduleReady ? '#E5F7F0' : '#5B5FEF')
              .onClick(() => {
                this.setupScheduleReady = true;
              })
          }
          .width('100%').padding(14).backgroundColor('#F6F7FB').borderRadius(16)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('3', '最近目标', '科目、考试日期与目标类型')
          Row({ space: 8 }) {
            this.ChoiceChip('goal', '期末复习', '期末复习')
            this.ChoiceChip('goal', '考研准备', '考研准备')
            this.ChoiceChip('goal', '能力提升', '能力提升')
          }
          .width('100%')
          TextInput({ placeholder: '当前最重要的科目', text: this.profileSubject })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.profileSubject = value;
            })
          TextInput({ placeholder: '考试日期，例如 2026-09-07', text: this.profileExamDate })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.profileExamDate = value;
            })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('4', '学习节奏', '每天能学多久、什么时候更舒服')
          Row({ space: 8 }) {
            this.ChoiceChip('minutes', '30', '30分钟')
            this.ChoiceChip('minutes', '60', '60分钟')
            this.ChoiceChip('minutes', '90', '90分钟')
            this.ChoiceChip('minutes', '120', '120分钟')
          }
          .width('100%')
          Row({ space: 8 }) {
            this.ChoiceChip('time', '清晨', '清晨')
            this.ChoiceChip('time', '午后', '午后')
            this.ChoiceChip('time', '晚间', '晚间')
            this.ChoiceChip('time', '不固定', '不固定')
          }
          .width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('5', '学习偏好', '决定 Agent 如何安排和陪伴你')
          Text('计划方式').width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            this.ChoiceChip('style', '练习驱动', '练习驱动')
            this.ChoiceChip('style', '理解优先', '理解优先')
            this.ChoiceChip('style', '稳步推进', '稳步推进')
          }
          .width('100%')
          Text('陪伴方式').width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            this.ChoiceChip('support', '温和陪伴', '温和陪伴')
            this.ChoiceChip('support', '直接督促', '直接督促')
            this.ChoiceChip('support', '只在需要时提醒', '低打扰')
          }
          .width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Button('生成我的第一条主动建议')
          .width('100%').height(52).fontSize(16).fontWeight(FontWeight.Bold)
          .backgroundColor('#5B5FEF').borderRadius(18)
          .onClick(() => {
            this.saveProfile();
          })
        Text('你可以随时在“我的 → 重新设置学习画像”中修改')
          .width('100%').textAlign(TextAlign.Center).fontSize(12).fontColor('#A1A5B5')
      }
      .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 32 })
    }
    .width('100%').height('100%').backgroundColor('#F6F7FC')
  }

  @Builder
  TabButton(index: number, icon: string, title: string) {
    Column({ space: 3 }) {
      Text(icon).fontSize(21)
      Text(title)
        .fontSize(12)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? '#5B5FEF' : '#8B90A5')
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    })
  }

  @Builder
  PageHeader(icon: string, title: string, subtitle: string) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(icon).fontSize(25)
        Text(title).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202235')
      }
      .width('100%')
      Text(subtitle).width('100%').fontSize(14).fontColor('#8B90A5')
    }
    .width('100%')
  }

  @Builder
  HomeTaskRow(index: number) {
    Row({ space: 10 }) {
      Text(this.tasks[index].completed ? '✓' : '○')
        .fontSize(18)
        .fontColor(this.tasks[index].completed ? '#22B07D' : '#4F556B')
      Column({ space: 3 }) {
        Text(this.tasks[index].title)
          .width('100%')
          .fontSize(15)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#292C3D')
          .decoration({
            type: this.tasks[index].completed ? TextDecorationType.LineThrough : TextDecorationType.None
          })
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%')
          .fontSize(12)
          .fontColor('#9A9EB0')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .onClick(() => {
      this.setTaskCompleted(index, !this.tasks[index].completed);
    })
  }

  @Builder
  HomePage() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text(`上午好，${this.profileName}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202235')
            Text('今天从一件小事开始').fontSize(15).fontColor('#8B90A5')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('🔥 11天连续')
            .fontSize(13)
            .fontColor('#E88132')
            .backgroundColor('#FFF1DF')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(16)
        }
        .width('100%')

        Column({ space: 14 }) {
          Row({ space: 8 }) {
            Text('✦').fontColor('#5B5FEF')
            Text('主动建议').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          }
          .width('100%')
          Text(`现在最值得做：${this.tasks[0].title}`)
            .width('100%').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#202235')
          Text(`按照你“${this.profileGoal} · ${this.profileLearningStyle}”的画像，结合考试日期、今日课表和“${this.energyState}”的状态，先完成一个${this.tasks[0].minutes}分钟的小目标。`)
            .width('100%').fontSize(15).fontColor('#666C82').lineHeight(23)
          Row({ space: 8 }) {
            Text(`⏱ ${this.tasks[0].minutes}分钟`).fontSize(13).fontColor('#555A70')
            Text(`📘 ${this.profileSubject}`).fontSize(13).fontColor('#555A70')
            Text(`🎯 还有${this.examDays()}天`).fontSize(13).fontColor('#555A70')
          }
          .width('100%')
          Button(`开始 ${this.tasks[0].minutes} 分钟`)
            .width('100%').height(48).fontSize(16).backgroundColor('#5B5FEF').borderRadius(16)
            .onClick(() => {
              this.beginFocus(0);
            })
        }
        .width('100%').padding(20).backgroundColor('#F0EFFF').borderRadius(24)

        Row({ space: 12 }) {
          Column({ space: 7 }) {
            Text('今日学习').fontSize(13).fontColor('#8B90A5')
            Text(this.todayTimeText()).fontSize(21).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1).padding(16).backgroundColor(Color.White).borderRadius(18)
          Column({ space: 7 }) {
            Text('任务完成').fontSize(13).fontColor('#8B90A5')
            Text(`${this.completedCount()} / ${this.tasks.length}`).fontSize(21).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1).padding(16).backgroundColor(Color.White).borderRadius(18)
        }

        Column({ space: 4 }) {
          Text('今日待办').width('100%').fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 4 })
          ForEach(this.tasks, (task: StudyTask, index: number) => {
            this.HomeTaskRow(index)
          }, (task: StudyTask, index: number) => `${index}-${task.title}`)
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  @Builder
  PlanTaskCard(index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.tasks[index].title)
          .width('100%').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#25283A')
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%').fontSize(12).fontColor('#9A9EB0')
      }
      .layoutWeight(1)
      if (this.tasks[index].completed) {
        Text('已完成')
          .fontSize(13).fontColor('#22B07D').backgroundColor('#E8F8F2')
          .padding({ left: 11, right: 11, top: 7, bottom: 7 }).borderRadius(14)
      } else {
        Button('开始')
          .fontSize(13).height(36).backgroundColor('#5B5FEF')
          .onClick(() => {
            this.beginFocus(index);
          })
      }
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }

  @Builder
  PlanPage() {
    Scroll() {
      Column({ space: 16 }) {
        this.PageHeader('📋', '计划', '今日行动清单 · 根据考试目标动态调整')
        Column({ space: 12 }) {
          Row() {
            Text('今日课表').fontSize(18).fontWeight(FontWeight.Bold)
            Blank()
            Text(this.setupScheduleReady ? '已同步' : '待导入').fontSize(12)
              .fontColor(this.setupScheduleReady ? '#218764' : '#A26B4E')
          }
          .width('100%')
          if (this.setupScheduleReady) {
            ForEach(this.scheduleItems, (item: ScheduleItem) => {
              Row({ space: 12 }) {
                Text(item.startTime).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
                Column({ space: 3 }) {
                  Text(item.course).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
                  Text(`${item.startTime}-${item.endTime} · ${item.location}`)
                    .width('100%').fontSize(12).fontColor('#9397A9')
                }.layoutWeight(1)
              }.width('100%')
            }, (item: ScheduleItem) => item.id)
          } else {
            Button('使用演示课表')
              .width('100%').height(42).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .onClick(() => {
                this.setupScheduleReady = true;
                this.scheduleItems = createDemoSchedule();
                this.persistSilently();
              })
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        Row({ space: 10 }) {
          TextInput({ placeholder: '添加今天要完成的任务', text: this.newTaskTitle })
            .layoutWeight(1).height(46).backgroundColor(Color.White).borderRadius(14)
            .onChange((value: string) => {
              this.newTaskTitle = value;
            })
          Button('添加')
            .height(46).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.addTask();
            })
        }
        .width('100%')
        Row() {
          Column({ space: 3 }) {
            Text(`${this.profileSubject}考试`).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
            Text(this.profileExamDate).width('100%').fontSize(12).fontColor('#A26B4E')
          }
          .layoutWeight(1)
          Blank()
          Text(`还有${this.examDays()}天`).fontSize(13).fontColor('#E06B3C')
        }
        .width('100%').padding(16).backgroundColor('#FFF2E8').borderRadius(16)
        ForEach(this.tasks, (task: StudyTask, index: number) => {
          this.PlanTaskCard(index)
        }, (task: StudyTask, index: number) => `${index}-${task.title}`)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  @Builder
  QuizOption(value: string, text: string) {
    Row({ space: 10 }) {
      Text(value)
        .width(30).height(30).textAlign(TextAlign.Center).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.quizChoice === value ? Color.White : '#5B5FEF')
        .backgroundColor(this.quizChoice === value ? '#5B5FEF' : '#ECEBFF').borderRadius(15)
      Text(text).layoutWeight(1).fontSize(14).fontColor('#34374A')
    }
    .width('100%').padding(12).backgroundColor('#F7F7FB').borderRadius(14)
    .onClick(() => {
      this.quizChoice = value;
      this.quizSubmitted = false;
    })
  }

  @Builder
  LearningPage() {
    Scroll() {
      Column({ space: 16 }) {
        this.PageHeader('📚', '智能学习', '自然语言规划 · 自适应计划 · 小测反馈')
        Column({ space: 13 }) {
          Row() {
            Text('✦ 和 Agent 理清今天要做的事').fontSize(17).fontWeight(FontWeight.Bold)
            Blank()
            Text('读取学习画像').fontSize(11).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .padding({ left: 9, right: 9, top: 5, bottom: 5 }).borderRadius(12)
          }.width('100%')
          Text(`已读取：${this.profileGrade} · ${this.profileLearningStyle} · 每天${this.profileDailyMinutes}分钟`)
            .width('100%').fontSize(12).fontColor('#9397A9')
          TextArea({
            placeholder: '例如：下周线代考试，矩阵不太熟，而且今晚有点累。',
            text: this.agentInput
          })
            .width('100%').height(90).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.agentInput = value;
            })
          Button('交给 Agent')
            .width('100%').height(44).backgroundColor('#5B5FEF').borderRadius(15)
            .onClick(() => {
              this.generateTodayPlan();
            })
          if (this.agentGenerated) {
            Column({ space: 8 }) {
              Text(`今日行动清单 · ${this.tasks.length}项`).width('100%').fontSize(14)
                .fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
              ForEach(this.tasks, (task: StudyTask, index: number) => {
                Row() {
                  Text(`${index + 1}. ${task.title}`).layoutWeight(1).fontSize(13)
                  Text(`${task.minutes}分钟`).fontSize(12).fontColor('#9397A9')
                }.width('100%').padding(10).backgroundColor(Color.White).borderRadius(12)
              }, (task: StudyTask, index: number) => `agent-${index}-${task.title}`)
              Text('已同步：首页建议、今日待办、考试科目与番茄钟')
                .width('100%').fontSize(12).fontColor('#218764')
            }
            .width('100%').padding(12).backgroundColor('#E8F8F2').borderRadius(14)
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 13 }) {
          Row() {
            Text('自适应学习计划').fontSize(18).fontWeight(FontWeight.Bold)
            Blank()
            Text(`${this.planProgress()}%`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          }.width('100%')
          Text(`${this.profileSubject} · 距考试${this.examDays()}天 · ${this.profileExamDate}`)
            .width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            Text('Day 1').fontSize(12).fontColor(Color.White).backgroundColor('#5B5FEF')
              .padding({ left: 10, right: 10, top: 7, bottom: 7 }).borderRadius(12)
            Text('基础梳理').fontSize(13)
            Text('→').fontSize(13).fontColor('#A1A5B5')
            Text('针对练习').fontSize(13)
            Text('→').fontSize(13).fontColor('#A1A5B5')
            Text('即时小测').fontSize(13)
          }.width('100%')
          Text('任务完成后自动更新完成率；小测结果将决定下一轮复习重点。')
            .width('100%').fontSize(12).fontColor('#9397A9')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 12 }) {
          Text('AI 小测 · 学 → 测 → 补').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Text('若矩阵 A 可逆，下列结论正确的是？').width('100%').fontSize(15).fontWeight(FontWeight.Medium)
          this.QuizOption('A', 'det(A)=0')
          this.QuizOption('B', 'A 的列向量线性无关')
          this.QuizOption('C', 'A 没有逆矩阵')
          this.QuizOption('D', 'A 的秩小于列数')
          Button('提交答案')
            .width('100%').height(42).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.submitQuiz();
            })
          if (this.quizSubmitted) {
            Text(this.quizChoice === 'B' ? '回答正确：可逆矩阵满秩，列向量线性无关。' : '还差一点。建议回顾“可逆矩阵与秩”的关系，随后再测一次。')
              .width('100%').fontSize(13)
              .fontColor(this.quizChoice === 'B' ? '#218764' : '#C2623A')
              .backgroundColor(this.quizChoice === 'B' ? '#E8F8F2' : '#FFF2E8')
              .padding(12).borderRadius(12)
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 12 }) {
          Text('大学学习路线图').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Text(`${this.profileSubject}章节导航`).width('100%').fontSize(13).fontColor('#9397A9')
          Row({ space: 7 }) {
            Text('基础概念').fontSize(12).padding(9).backgroundColor('#ECEBFF').borderRadius(12)
            Text('→').fontSize(12)
            Text('核心方法').fontSize(12).padding(9).backgroundColor('#ECEBFF').borderRadius(12)
            Text('→').fontSize(12)
            Text('真题应用').fontSize(12).padding(9).backgroundColor('#ECEBFF').borderRadius(12)
          }.width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  @Builder
  FocusPage() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 5 }) {
          Text('正在做').fontSize(13).fontColor('#B9B6DA')
          Text(this.currentTask().title)
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White).textAlign(TextAlign.Center)
        }
        .width('100%')
        Stack() {
          Column()
            .width(230).height(230).borderRadius(115).backgroundColor('#37336C').opacity(0.6)
            .scale({ x: this.shadowPulse, y: this.shadowPulse })
          Column()
            .width(180).height(180).borderRadius(90).backgroundColor('#625AF5')
            .opacity(this.isRunning ? 0.82 : 0.48)
          Column({ space: 7 }) {
            Text(this.formatTime(this.remainingSeconds))
              .fontSize(45).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text(this.isRunning ? '学习影子正在生长' :
              (this.remainingSeconds <= 0 ? '本轮专注已完成' : '本轮专注已暂停'))
              .fontSize(13).fontColor('#D8D6F0')
          }
        }
        .width('100%').height(250)
        Row({ space: 10 }) {
          Button(this.isRunning ? '暂停' : (this.remainingSeconds <= 0 ? '再次专注' : '继续'))
            .layoutWeight(1).height(46).backgroundColor('#625AF5')
            .onClick(() => {
              if (this.isRunning) {
                this.pauseFocus();
              } else if (this.remainingSeconds <= 0) {
                this.resetFocus();
                this.startTimer();
              } else {
                this.startTimer();
              }
            })
          Button('重置')
            .layoutWeight(1).height(46).backgroundColor('#343154')
            .onClick(() => {
              this.resetFocus();
            })
        }
        .width('100%')
        Button(this.currentTask().completed ? '✓ 本轮任务已完成' : '完成本轮专注')
          .width('100%').height(46).fontColor('#24213F')
          .backgroundColor(this.currentTask().completed ? '#CAC7E8' : '#E5E2FF')
          .enabled(!this.currentTask().completed)
          .onClick(() => {
            this.finishFocus();
          })
        Row() {
          Column({ space: 5 }) {
            Text('今日累计').fontSize(12).fontColor('#AAA6CB')
            Text(this.todayTimeText()).fontSize(19).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
          Column({ space: 5 }) {
            Text('共同专注').fontSize(12).fontColor('#AAA6CB')
            Text('3个学习影子').fontSize(19).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
        }
        .width('100%').padding(18).backgroundColor('#282548').borderRadius(18)
      }
      .width('100%').padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .layoutWeight(1).backgroundColor('#17152F')
  }

  @Builder
  GrowthPage() {
    Scroll() {
      Column({ space: 16 }) {
        this.PageHeader('🌱', '成长与小队', '学习影子 · 非打扰共学 · 校园成长服务')
        Column({ space: 14 }) {
          Row({ space: 14 }) {
            Stack() {
              Column().width(70).height(70).backgroundColor('#D8F8EE').borderRadius(35)
              Text('✦').fontSize(34).fontColor('#35C99A')
            }.width(76).height(76)
            Column({ space: 5 }) {
              Text('你的学习影子 · 微光').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
              Text(`今日专注 ${this.todayTimeText()} · 随专注时长生长`).width('100%').fontSize(12).fontColor('#9397A9')
              Text(this.isRunning ? '正在发光，队友能感受到你在学习' : '开始番茄钟后，影子会进入共学空间')
                .width('100%').fontSize(12).fontColor('#35A982')
            }.layoutWeight(1)
          }.width('100%')
          Button(this.isRunning ? '进入学习影子空间' : '开始专注并进入影子空间')
            .width('100%').height(44).backgroundColor('#24213F')
            .onClick(() => {
              this.currentTab = 3;
              if (!this.isRunning) {
                this.startTimer();
              }
            })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 13 }) {
          Row() {
            Column({ space: 3 }) {
              Text(`${this.profileSubject}互助小队`).width('100%').fontSize(18).fontWeight(FontWeight.Bold)
              Text('4人小队 · 目标一致 · 轻度竞争').width('100%').fontSize(12).fontColor('#9397A9')
            }.layoutWeight(1)
            Text('Lv.2').fontSize(12).fontColor('#A85D22').backgroundColor('#FFF1DF')
              .padding({ left: 10, right: 10, top: 7, bottom: 7 }).borderRadius(13)
          }.width('100%')
          Text(`🎯 30天完成${this.profileSubject}复习`).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
          Row() {
            Text('你 · 队长').layoutWeight(1).fontSize(13)
            Text('70% · 已完成今日任务').fontSize(12).fontColor('#5B5FEF')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row() {
            Text('小明 · 氛围官').layoutWeight(1).fontSize(13)
            Text('55% · 正在专注').fontSize(12).fontColor('#35A982')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row() {
            Text('小红 · 分享者').layoutWeight(1).fontSize(13)
            Text('40% · 还有3个任务').fontSize(12).fontColor('#D26B72')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row({ space: 8 }) {
            Button('鼓励队友').layoutWeight(1).height(39).fontSize(12).backgroundColor('#5B5FEF')
              .onClick(() => {
                this.squadMessage = '已送出一束微光，既鼓励又不打扰';
              })
            Button('发起挑战').layoutWeight(1).height(39).fontSize(12).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .onClick(() => {
                this.squadMessage = '已创建“共同专注25分钟”挑战';
              })
          }.width('100%')
          Text(this.squadMessage).width('100%').fontSize(12).fontColor('#777C90')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 13 }) {
          Text('校园与职业助手').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Row({ space: 10 }) {
            Column({ space: 5 }) {
              Text('🏠').fontSize(24)
              Text('租房避坑').fontSize(13).fontWeight(FontWeight.Bold)
              Text('合同与押金检查').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#FFF4EA').borderRadius(15)
            Column({ space: 5 }) {
              Text('💼').fontSize(24)
              Text('职业规划').fontSize(13).fontWeight(FontWeight.Bold)
              Text('能力画像与路线').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#EEF3FF').borderRadius(15)
          }.width('100%')
          Row({ space: 10 }) {
            Column({ space: 5 }) {
              Text('🏥').fontSize(24)
              Text('医保报销').fontSize(13).fontWeight(FontWeight.Bold)
              Text('流程与材料清单').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#EAF8F3').borderRadius(15)
            Column({ space: 5 }) {
              Text('📄').fontSize(24)
              Text('合同检查').fontSize(13).fontWeight(FontWeight.Bold)
              Text('识别常见风险项').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#F6EEFF').borderRadius(15)
          }.width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  @Builder
  EnergyButton(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.energyState === title ? Color.White : '#5F6478')
      .backgroundColor(this.energyState === title ? '#5B5FEF' : '#F0F1F6')
      .padding({ left: 14, right: 14, top: 9, bottom: 9 }).borderRadius(16)
      .onClick(() => {
        this.energyState = title;
        this.persistSilently();
      })
  }

  @Builder
  ProfilePage() {
    Scroll() {
      Column({ space: 18 }) {
        this.PageHeader('👤', '我的', '学习画像 · 数据与隐私')
        Row({ space: 14 }) {
          Text(this.profileName.length > 0 ? this.profileName.substring(0, 1) : '学')
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#5B5FEF').borderRadius(29)
          Column({ space: 5 }) {
            Text(this.profileName).fontSize(20).fontWeight(FontWeight.Bold)
            Text(`${this.profileGrade} · ${this.profileMajor}`).fontSize(13).fontColor('#8B90A5')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 15 }) {
          Text('学习画像').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Row() {
            Text('当前目标').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(this.profileGoal).fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          Row() {
            Text('学习方式').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(this.profileLearningStyle).fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          Row() {
            Text('每日可用时间').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(`${this.profileDailyMinutes}分钟 · ${this.profilePreferredTime}`).fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          Row() {
            Text('当前科目').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(this.profileSubject).fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          Row() {
            Text('考试日期').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(`${this.profileExamDate} · ${this.examDays()}天`).fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 13 }) {
          Text('今天的状态').width('100%').fontSize(17).fontWeight(FontWeight.Bold)
          Row({ space: 9 }) {
            this.EnergyButton('状态不错')
            this.EnergyButton('一般')
            this.EnergyButton('有点累')
          }
          .width('100%')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Button('重新设置学习画像')
          .width('100%').height(46).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
          .onClick(() => {
            this.resetProfile();
          })
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  build() {
    if (!this.profileLoaded) {
      this.LoadingPage()
    } else if (!this.profileCompleted) {
      this.SetupPage()
    } else {
      Column() {
        if (this.currentTab === 0) {
          this.HomePage()
        } else if (this.currentTab === 1) {
          this.PlanPage()
        } else if (this.currentTab === 2) {
          this.LearningPage()
        } else if (this.currentTab === 3) {
          this.FocusPage()
        } else if (this.currentTab === 4) {
          this.GrowthPage()
        } else {
          this.ProfilePage()
        }
        Row() {
          this.TabButton(0, '⌂', '首页')
          this.TabButton(1, '📋', '计划')
          this.TabButton(2, '📚', '学习')
          this.TabButton(3, '◉', '专注')
          this.TabButton(4, '🌱', '成长')
          this.TabButton(5, '👤', '我的')
        }
        .width('100%').height(72).backgroundColor(Color.White)
        .borderRadius({ topLeft: 22, topRight: 22 })
      }
      .width('100%').height('100%').backgroundColor('#F6F7FC')
    }
  }
}
