import { StudyTask, TodayStudyOverride } from '../models/StudyModels';
import { UserAvatar } from '../components/UserAvatar';
import { StudyPlanet } from '../components/StudyPlanet';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { AgentDailyPlanItem, AgentDecisionEvidence, AgentDecisionReason, AgentDecisionResult } from '../services/AgentDecisionService';
import { formatSubjectName } from '../utils/SubjectDisplayName';
import { LearningResourcePicker } from '../components/LearningResourcePicker';

@Component
export struct HomePageView {
  @Prop courseHint: string = '导入课表，安排学习时间';
  onOpenSchedule: () => void = () => {};
  @State detailsOpen: boolean = false;
  @State adjustOpen: boolean = false;
  @State resourcePickerOpen: boolean = false;
  @State draftTaskIndex: number = -1;
  @State draftPriorityMode: string = 'auto';
  @State draftTitle: string = '';
  @State draftSubject: string = '';
  @State draftMinutes: number = 25;
  @State draftAvailableMinutes: string = '';
  @State draftPreferredSubject: string = '';
  @State draftSkippedTaskIds: string[] = [];
  @State addingTemporaryTask: boolean = false;
  @State deleteConfirmTaskId: string = '';
  @State deleteMessage: string = '';
  @State deleteBusy: boolean = false;
  @Prop actionMessage: string = '';
  @Prop hasDeferrals: boolean = false;
  onDefer: (kind: string) => void = () => {};
  onUndoDeferral: () => void = () => {};
  onRetrySave: () => void = () => {};
  @Prop planetStage: number = 1;
  @Prop streakDays: number = 0;
  @Prop bankEvidence: BankLearningEvidence[] = [];
  @Prop bankEvidenceError: string = '';
  onOpenQuestionBank: () => void = () => {};
  onPlanFromBank: () => void = () => {};
  @Prop profileAvatarUri: string = '';
  @Prop profileName: string = '';
  @Prop greeting: string = '';
  @Prop profileSubject: string = '';
  @Prop examDays: number = 0;
  @Prop todayTimeText: string = '0分钟';
  @Prop completedCount: number = 0;
  @Prop masteryPoint: string = '';
  @Prop masteryScore: number = 0;
  @Prop masteryStatus: string = '';
  @Prop tasks: StudyTask[] = [];
  @Prop todayStudyOverride: TodayStudyOverride = { date: '' };
  @Prop todayDate: string = '';
  @Prop todayRemainingMinutes: number = 0;
  @Prop recommendationTitle: string = '';
  @Prop recommendationSubject: string = '';
  @Prop recommendationReason: string = '';
  @Prop recommendationMinutes: number = 0;
  @Prop recommendationTaskIndex: number = 0;
  @Prop recommendationAllDone: boolean = false;
  @Prop recommendationEvidence: string[] = [];
  @Prop timelineTime: string = '';
  @Prop timelineTitle: string = '';
  @Prop timelineDetail: string = '';
  @Prop showRecommendationDetails: boolean = false;
  @Prop actionEnabled: boolean = true;
  @Prop activeGoalTitle: string = '';
  @Prop activeGoalReason: string = '';
  @Prop decision: AgentDecisionResult = {
    recommendedAction: { stage: 'plan', headline: '等待学习安排', actionTitle: '查看学习安排', reason: '',
      completionStandard: '', nextStep: '', subject: '', minutes: 0, taskIndex: -1, topicId: '' },
    dailyPlan: [], reasonChain: [], priority: '待安排', confidenceLevel: '依据有限', evidence: [],
    status: { pendingTaskCount: 0, recentTrend: '暂无相关记录' }
  };
  onPrimaryAction: () => void = () => {};
  onAdjustToday: (override: TodayStudyOverride, title: string, subject: string, minutes: number) => void = () => {};
  onDeleteTask: (taskId: string) => Promise<string> = async () => '';
  onManageToday: () => void = () => {};
  onStartFocus: (index: number) => void = () => {};
  onToggleRecommendationDetails: () => void = () => {};
  onToggleTask: (index: number, completed: boolean) => void = () => {};
  onBusinessOverlayChange: (visible: boolean) => void = () => {};

  private availableTaskIndices(): number[] {
    const indices: number[] = [];
    this.tasks.forEach((task: StudyTask, index: number) => {
      if (!task.completed && (task.source !== 'today-temporary' ||
        (this.todayStudyOverride.temporaryTaskIds ?? []).includes(task.id ?? ''))) { indices.push(index); }
    });
    return indices;
  }

  private visibleTasks(): StudyTask[] {
    return this.tasks.filter((task: StudyTask) => task.source !== 'today-temporary' ||
      (this.todayStudyOverride.temporaryTaskIds ?? []).includes(task.id ?? ''));
  }

  private upcomingPlan(): AgentDailyPlanItem[] {
    const currentKey: string = this.decision.recommendedAction.key ?? '';
    return this.decision.dailyPlan.filter((item: AgentDailyPlanItem) =>
      `task:${item.taskId}` !== currentKey).slice(0, 2);
  }

  private currentResourceTask(): AgentDailyPlanItem | undefined {
    const first: AgentDailyPlanItem | undefined = this.decision.dailyPlan[0];
    const currentKey: string = this.decision.recommendedAction.key ?? '';
    if (first === undefined || currentKey !== `task:${first.taskId}`) { return undefined; }
    return first;
  }

  private needsMoreGoals(): boolean {
    const stage: string = this.decision.recommendedAction.stage;
    return this.decision.status.pendingTaskCount <= 1 && this.upcomingPlan().length === 0 &&
      (stage === 'execute' || stage === 'plan');
  }

  private currentArrangementReason(): string {
    const reason: AgentDecisionReason | undefined = this.decision.reasonChain[0];
    return reason === undefined ? '' : formatSubjectName(`${reason.data}；${reason.judgment}`);
  }

  private selectDraftTask(index: number): void {
    const task: StudyTask | undefined = this.tasks[index];
    if (task === undefined || task.completed) { return; }
    this.draftTaskIndex = index;
    this.draftPriorityMode = 'manual';
    this.draftSkippedTaskIds = this.draftSkippedTaskIds.filter((id: string) => id !== task.id);
  }

  private toggleDraftSkip(index: number): void {
    const taskId: string = this.tasks[index]?.id ?? '';
    if (taskId.length === 0) { return; }
    this.draftSkippedTaskIds = this.draftSkippedTaskIds.includes(taskId) ?
      this.draftSkippedTaskIds.filter((id: string) => id !== taskId) :
      this.draftSkippedTaskIds.concat([taskId]);
    if (this.draftSkippedTaskIds.includes(taskId) && this.draftTaskIndex === index) {
      this.draftTaskIndex = -1;
    }
  }

  private openTodayAdjust(): void {
    this.draftTaskIndex = this.availableTaskIndices().find((index: number) =>
      this.tasks[index].id === this.todayStudyOverride.preferredTaskId) ?? -1;
    this.draftPriorityMode = this.draftTaskIndex >= 0 ? 'manual' : 'auto';
    this.draftAvailableMinutes = this.todayStudyOverride.availableMinutes === undefined ? '' :
      `${Math.max(0, Math.floor(this.todayRemainingMinutes))}`;
    this.draftPreferredSubject = this.todayStudyOverride.preferredSubject ?? '';
    this.draftSkippedTaskIds = (this.todayStudyOverride.skippedTaskIds ?? []).slice();
    this.draftTitle = '';
    this.draftSubject = this.profileSubject;
    this.draftMinutes = 25;
    this.addingTemporaryTask = false;
    this.deleteConfirmTaskId = '';
    this.deleteMessage = '';
    this.deleteBusy = false;
    this.adjustOpen = true;
    this.onBusinessOverlayChange(true);
  }

  private closeTodayAdjust(): void {
    this.adjustOpen = false;
    this.deleteConfirmTaskId = '';
    this.onBusinessOverlayChange(false);
  }

  private newDraftTask(): void {
    this.addingTemporaryTask = !this.addingTemporaryTask;
    this.draftTitle = '';
    this.draftSubject = this.profileSubject;
    this.draftMinutes = 25;
  }

  private saveTodayAdjust(): void {
    const raw: string = this.draftAvailableMinutes.trim();
    if (!this.validAdditionalMinutes()) { return; }
    const preferredTaskId: string = this.draftPriorityMode === 'manual' && this.draftTaskIndex >= 0 ?
      this.tasks[this.draftTaskIndex].id ?? '' : '';
    const override: TodayStudyOverride = { date: this.todayDate,
      availableMinutes: raw.length === 0 ? undefined : Number(raw),
      preferredTaskId: preferredTaskId, preferredSubject: this.draftPreferredSubject.trim(),
      skippedTaskIds: this.draftSkippedTaskIds,
      temporaryTaskIds: this.todayStudyOverride.temporaryTaskIds ?? [] };
    this.onAdjustToday(override, this.addingTemporaryTask ? this.draftTitle : '',
      this.draftSubject, this.draftMinutes);
    this.closeTodayAdjust();
    this.detailsOpen = false;
  }

  private validAdditionalMinutes(): boolean {
    const raw: string = this.draftAvailableMinutes.trim();
    return raw.length === 0 || (/^\d+$/.test(raw) && Number(raw) <= 240);
  }

  private deleteTaskTitle(): string {
    return this.tasks.find((task: StudyTask) => task.id === this.deleteConfirmTaskId)?.title ?? '这个待办';
  }

  private async confirmDeleteTask(): Promise<void> {
    const taskId: string = this.deleteConfirmTaskId;
    if (taskId.length === 0 || this.deleteBusy) { return; }
    this.deleteBusy = true;
    const selectedId: string = this.draftTaskIndex >= 0 ? this.tasks[this.draftTaskIndex]?.id ?? '' : '';
    let message: string = '';
    try {
      message = await this.onDeleteTask(taskId);
    } catch (error) {
      message = '删除未保存，请重试。';
    }
    this.deleteBusy = false;
    this.deleteConfirmTaskId = '';
    if (message.length > 0) {
      this.deleteMessage = message;
      return;
    }
    this.draftSkippedTaskIds = this.draftSkippedTaskIds.filter((id: string) => id !== taskId);
    if (selectedId === taskId) {
      this.draftTaskIndex = -1;
      this.draftPriorityMode = 'auto';
    } else if (selectedId.length > 0) {
      this.draftTaskIndex = this.tasks.findIndex((task: StudyTask) => task.id === selectedId);
    }
    this.deleteMessage = '待办已删除，今天的安排已重新计算。';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Scroll() {
        Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(this.greeting + '，' + this.profileName).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#24283D')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('今天先把一件事做好').fontSize(14).fontColor('#858B9D')
              .maxLines(2)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Row({ space: 8 }) {
            Column({ space: 3 }) {
              Text('🔥 ' + this.streakDays + ' 天').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#D87A36')
              Text('连续学习').fontSize(10).fontColor('#B68C6B')
            }.padding({ left: 10, right: 10, top: 7, bottom: 7 })
              .backgroundColor('#FFF3E7').borderRadius(14)
            Column() {
              UserAvatar({ avatarUri: this.profileAvatarUri, profileName: this.profileName, avatarSize: 44 })
            }.width(48).alignItems(HorizontalAlign.Center)
          }.alignItems(VerticalAlign.Top)
        }.width('100%').alignItems(VerticalAlign.Top)
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('当前目标').fontSize(12).fontColor('#858B9D')
            Text(formatSubjectName(this.activeGoalTitle.length > 0 ? this.activeGoalTitle : '暂未设置学习目标'))
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#363B53')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.activeGoalReason.length > 0) {
              Text(formatSubjectName(this.activeGoalReason)).fontSize(12).fontColor('#858B9D')
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          StudyPlanet({ stage: this.planetStage, planetSize: 48 })
        }.width('100%').alignItems(VerticalAlign.Center)
        Row({ space: 8 }) {
          Text('今日课程').fontSize(12).fontColor('#6865D9')
          Text(formatSubjectName(this.courseHint)).fontSize(12).fontColor('#72798E').layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('›').fontSize(18).fontColor('#969BB0')
        }.width('100%').height(40).padding({ left: 12, right: 12 })
          .backgroundColor('#EFEEF8').borderRadius(12).onClick(() => { this.onOpenSchedule(); })
        Column({ space: 15 }) {
          Row() {
            Text('小星球今天这样安排').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#5450B8')
            Blank()
            Row({ space: 6 }) {
              Text('调整今天安排').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5F5BCB')
              Text('›').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#7772C8')
            }
              .height(42).padding({ left: 14, right: 12 })
              .backgroundColor('#F1F0FA').borderRadius(16)
              .border({ width: 1, color: '#D9D6F2' })
              .onClick(() => { this.openTodayAdjust(); })
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.currentArrangementReason().length > 0) {
            Column({ space: 4 }) {
              Text('小星球发现').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#5C55BA').width('100%')
              Text(this.currentArrangementReason())
                .fontSize(12).lineHeight(18).fontColor('#686E82').width('100%')
            }.width('100%').padding(12).alignItems(HorizontalAlign.Start)
              .backgroundColor('#F7F6FC').borderRadius(13)
          }
          Text('现在').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5C55BA').width('100%')
          Text(formatSubjectName(this.decision.recommendedAction.headline)).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#24283D').width('100%')
            .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.decision.recommendedAction.minutes > 0) {
            Text('约 ' + this.decision.recommendedAction.minutes + ' 分钟 · ' +
              formatSubjectName(this.decision.recommendedAction.subject))
              .fontSize(13).fontColor('#6865B5').width('100%')
          }
          if (this.todayStudyOverride.availableMinutes === undefined &&
            this.decision.recommendedAction.stage === 'execute') {
            Text('今天可学习时间尚未确认，先安排眼前这一项。')
              .fontSize(11).fontColor('#858B9D').width('100%')
          }
          if (this.upcomingPlan().length > 0) {
            Column({ space: 10 }) {
              ForEach(this.upcomingPlan(), (item: AgentDailyPlanItem, index: number) => {
                Row({ space: 10 }) {
                  Text(index === 0 ? '之后' : '稍后').fontSize(12).fontWeight(FontWeight.Bold)
                    .fontColor('#7772C8').width(34)
                  Column({ space: 3 }) {
                    Text(formatSubjectName(item.title)).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#454A61')
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                    Text(`${formatSubjectName(item.subject)} · 约${item.suggestedMinutes}分钟`)
                      .fontSize(11).fontColor('#9296A8').width('100%')
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.width('100%')
              }, (item: AgentDailyPlanItem) => item.taskId)
            }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .alignItems(HorizontalAlign.Start).backgroundColor('#F8F7FC').borderRadius(14)
          }
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text(this.todayStudyOverride.availableMinutes === undefined ? '今日目标剩余' :
                '今日可安排剩余').fontSize(11).fontColor('#8990A2')
              Text(this.decision.status.remainingGoalMinutes === undefined ? '暂无相关记录' :
                `${this.decision.status.remainingGoalMinutes}分钟`)
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#343951')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              Text('未完成安排').fontSize(11).fontColor('#8990A2')
              Text(`${this.decision.status.pendingTaskCount}项`)
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#343951')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding(12).backgroundColor('#F7F7FC').borderRadius(13)
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('待巩固知识点').fontSize(11).fontColor('#8990A2')
              Text(this.decision.status.weakPointCount === undefined ? '暂无相关记录' :
                `${this.decision.status.weakPointCount}个（历史练习）`)
                .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#343951')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 4 }) {
              Text('近期专注趋势').fontSize(11).fontColor('#8990A2')
              Text(this.decision.status.recentTrend).fontSize(12).fontWeight(FontWeight.Medium)
                .fontColor('#343951').maxLines(2)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').padding(12).backgroundColor('#F7F7FC').borderRadius(13)
          Button(this.decision.recommendedAction.stage === 'execute' ? '开始学习' :
            this.decision.recommendedAction.actionTitle).width('100%').height(48).fontSize(16).borderRadius(16)
            .backgroundColor('#6865D9').enabled(this.actionEnabled).opacity(this.actionEnabled ? 1 : 0.5)
            .onClick(() => { this.onPrimaryAction(); })
          if (this.currentResourceTask() !== undefined) {
            Row({ space: 7 }) {
              Text('✨').fontSize(14)
              Text('小星球帮我找资料').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#625DC0')
              Text('›').fontSize(18).fontColor('#8B86C7')
            }.width('100%').height(44).justifyContent(FlexAlign.Center)
              .backgroundColor('#F5F3FB').borderRadius(14)
              .onClick(() => {
                this.resourcePickerOpen = true;
                this.onBusinessOverlayChange(true);
              })
          }
          if (this.upcomingPlan().length === 0 && this.needsMoreGoals()) {
            Text('小星球还不了解你的全部安排，可以先告诉我更多学习目标。')
              .fontSize(12).lineHeight(18).fontColor('#858B9D').width('100%')
          }
          if (this.decision.recommendedAction.stage !== 'resume' &&
            this.decision.recommendedAction.stage !== 'wait' && this.decision.recommendedAction.stage !== 'done') {
            Row() {
              Text('30 分钟后').fontSize(13).fontColor('#7C8296').height(44).layoutWeight(1)
                .textAlign(TextAlign.Center).onClick(() => { this.detailsOpen = false; this.onDefer('later'); })
              Text('今天跳过').fontSize(13).fontColor('#7C8296').height(44).layoutWeight(1)
                .textAlign(TextAlign.Center).onClick(() => { this.detailsOpen = false; this.onDefer('skip'); })
            }.width('100%')
          }
          Text(this.detailsOpen ? '收起星球的小提醒 ⌃' : '看看星球为什么这样安排 ⌄').fontSize(12).fontColor('#777D94')
            .height(36).onClick(() => { this.detailsOpen = !this.detailsOpen; })
          if (this.detailsOpen) {
            ForEach(this.decision.reasonChain, (reason: AgentDecisionReason, index: number) => {
              Column({ space: 4 }) {
                Text('🌱 我发现 · ' + formatSubjectName(reason.data)).fontSize(12).fontColor('#656B80').width('100%')
                Text('💭 我想到 · ' + formatSubjectName(reason.judgment)).fontSize(12).fontColor('#656B80').width('100%')
                Text('✨ 我建议 · ' + formatSubjectName(reason.recommendation)).fontSize(12).fontWeight(FontWeight.Medium)
                  .fontColor('#5551B5').width('100%')
              }.width('100%').padding(11).backgroundColor('#F7F6FC').borderRadius(12)
            }, (reason: AgentDecisionReason, index: number) => `${index}-${reason.data}`)
            Text('我参考了这些记录').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#52586E').width('100%')
            ForEach(this.decision.evidence, (item: AgentDecisionEvidence, index: number) => {
              Text(formatSubjectName(`${item.label}：${item.value} · ${item.source}`))
                .fontSize(11).lineHeight(17).fontColor('#858B9D').width('100%')
            }, (item: AgentDecisionEvidence, index: number) => `${index}-${item.label}`)
            if (this.decision.recommendedAction.completionStandard.length > 0) {
              Text('完成标准：' + this.decision.recommendedAction.completionStandard)
                .fontSize(13).lineHeight(20).fontColor('#60677D').width('100%')
            }
          }
        }.width('100%').padding(22).backgroundColor(Color.White).borderRadius(22)
        if (this.hasDeferrals || this.actionMessage.length > 0) {
          Row({ space: 8 }) {
            Text(this.actionMessage.length > 0 ? this.actionMessage : '有暂缓的建议，原任务已保留')
              .fontSize(12).fontColor('#858B9D').layoutWeight(1)
            if (this.hasDeferrals) {
              Text('恢复').fontSize(13).fontColor('#6865D9').height(40).onClick(() => { this.onUndoDeferral(); })
            }
            if (this.actionMessage.includes('未保存')) {
              Text('重试保存').fontSize(13).fontColor('#6865D9').height(40).onClick(() => { this.onRetrySave(); })
            }
          }.width('100%')
        }
        Row() {
          Text('今日学习  ' + this.todayTimeText).fontSize(13).fontColor('#858B9D')
          Blank()
          Text('任务完成  ' + this.visibleTasks().filter((task: StudyTask) => task.completed).length +
            '/' + this.visibleTasks().length).fontSize(13).fontColor('#858B9D')
        }.width('100%').padding({ top: 8, bottom: 8 })
        }.width('100%').padding({ left: 24, right: 24, top: 20, bottom: 24 })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off)
      if (this.adjustOpen) {
        Column().width('100%').height('100%').backgroundColor('#660E1020')
          .hitTestBehavior(HitTestMode.Block).onClick(() => { this.closeTodayAdjust(); })
        Scroll() {
        Column({ space: 14 }) {
          Row() {
            Column({ space: 3 }) {
              Text('调整今天安排').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#24283D')
              Text('只对今天生效，不改变长期学习目标').fontSize(11).fontColor('#858B9D')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('×').width(34).height(34).textAlign(TextAlign.Center).fontSize(24).fontColor('#777D90')
              .onClick(() => { this.closeTodayAdjust(); })
          }.width('100%')
          Text('接下来还想学多久？').fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor('#666B80').width('100%')
          Row({ space: 8 }) {
            ForEach([15, 30, 60], (minutes: number) => {
              Text(`${minutes}分钟`).layoutWeight(1).height(34).textAlign(TextAlign.Center).fontSize(11)
                .fontColor(this.draftAvailableMinutes === `${minutes}` ? Color.White : '#6865D9')
                .backgroundColor(this.draftAvailableMinutes === `${minutes}` ? '#6865D9' : '#EFEEFA')
                .borderRadius(11).onClick(() => { this.draftAvailableMinutes = `${minutes}`; })
            }, (minutes: number) => `additional-minutes-${minutes}`)
          }.width('100%')
          TextInput({ text: this.draftAvailableMinutes, placeholder: '可自定义；留空表示未知，0 表示暂不追加' })
            .width('100%').height(42).fontSize(12).backgroundColor('#F3F2F9').borderRadius(12)
            .onChange((value: string) => { this.draftAvailableMinutes = value; })
          Text('这里填写的是从现在开始愿意再投入的时间，不需要加上今天已经专注的分钟数。')
            .fontSize(10).lineHeight(16).fontColor('#8A8FA2').width('100%')
          Text('今天想优先处理的科目（可不填）').fontSize(12).fontColor('#666B80').width('100%')
          TextInput({ text: formatSubjectName(this.draftPreferredSubject), placeholder: '例如：大学英语' })
            .width('100%').height(42).fontSize(12).backgroundColor('#F3F2F9').borderRadius(12)
            .onChange((value: string) => { this.draftPreferredSubject = value; })
          Text('今天优先').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#666B80').width('100%')
          Row({ space: 8 }) {
            Text('小星球自动安排').layoutWeight(1).height(38).textAlign(TextAlign.Center).fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.draftPriorityMode === 'auto' ? Color.White : '#625DC0')
              .backgroundColor(this.draftPriorityMode === 'auto' ? '#6865D9' : '#EFEEFA').borderRadius(12)
              .onClick(() => { this.draftPriorityMode = 'auto'; this.draftTaskIndex = -1; })
            Text('我指定一个待办优先').layoutWeight(1).height(38).textAlign(TextAlign.Center).fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.draftPriorityMode === 'manual' ? Color.White : '#625DC0')
              .backgroundColor(this.draftPriorityMode === 'manual' ? '#6865D9' : '#EFEEFA').borderRadius(12)
              .onClick(() => { this.draftPriorityMode = 'manual'; })
          }.width('100%')
          Text(this.draftPriorityMode === 'auto' ? '小星球会从未跳过的真实待办中安排顺序' : '选择一个真实待办作为今天的优先项')
            .fontSize(10).fontColor('#8A8FA2').width('100%')
          Text('管理已有待办').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#666B80').width('100%')
          Scroll() {
          Column({ space: 7 }) {
            ForEach(this.availableTaskIndices(), (taskIndex: number) => {
              Row({ space: 9 }) {
                if (this.draftPriorityMode === 'manual') {
                  Column() {
                    if (this.draftTaskIndex === taskIndex) {
                      Text('✓').fontSize(11).fontColor(Color.White)
                    }
                  }.width(22).height(22).borderRadius(11)
                    .backgroundColor(this.draftTaskIndex === taskIndex ? '#6865D9' : '#E8E7F3')
                    .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
                    .onClick(() => { this.selectDraftTask(taskIndex); })
                }
                Column({ space: 2 }) {
                  Text(formatSubjectName(this.tasks[taskIndex].title)).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#303449')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${formatSubjectName(this.tasks[taskIndex].subject)} · ${this.tasks[taskIndex].minutes}分钟`)
                    .fontSize(10).fontColor('#898EA1')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  .onClick(() => { if (this.draftPriorityMode === 'manual') { this.selectDraftTask(taskIndex); } })
                Column({ space: 3 }) {
                  Text(this.draftSkippedTaskIds.includes(this.tasks[taskIndex].id ?? '') ? '恢复' : '今天跳过')
                    .fontSize(10).fontColor('#6D67C9').height(24).onClick(() => {
                      this.toggleDraftSkip(taskIndex);
                    })
                  Text('删除').fontSize(10).fontColor('#A6535B').height(24).onClick(() => {
                    this.deleteMessage = '';
                    this.deleteConfirmTaskId = this.tasks[taskIndex].id ?? '';
                  })
                }.alignItems(HorizontalAlign.End)
              }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .backgroundColor(this.draftTaskIndex === taskIndex ? '#F0EFFB' : '#F8F8FC').borderRadius(12)
            }, (taskIndex: number) => `adjust-task-${taskIndex}-${this.tasks[taskIndex].id}`)
            Row({ space: 8 }) {
              Text('+').width(22).height(22).textAlign(TextAlign.Center).fontSize(17).fontColor('#6865D9')
                .backgroundColor('#EAE8FA').borderRadius(11)
              Text(this.addingTemporaryTask ? '取消临时任务' : '新增今天的临时任务')
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#5F5BCB')
            }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 })
              .backgroundColor('#F8F8FC').borderRadius(12)
              .onClick(() => { this.newDraftTask(); })
          }.width('100%')
          }.width('100%').height(210).scrollBar(BarState.Auto)
          if (this.deleteMessage.length > 0) {
            Text(this.deleteMessage).fontSize(10).lineHeight(15)
              .fontColor(this.deleteMessage.includes('已删除') ? '#287C63' : '#A6535B').width('100%')
          }
          if (this.addingTemporaryTask) {
          TextInput({ text: this.draftTitle, placeholder: '今天临时要做什么？' }).width('100%').height(43)
            .fontSize(13).backgroundColor('#F3F2F9').borderRadius(12)
            .onChange((value: string) => { this.draftTitle = value; })
          TextInput({ text: formatSubjectName(this.draftSubject), placeholder: '科目或主题' }).width('100%').height(41)
            .fontSize(12).backgroundColor('#F3F2F9').borderRadius(12)
            .onChange((value: string) => { this.draftSubject = value; })
          Row({ space: 7 }) {
            ForEach([15, 25, 40, 60], (minutes: number) => {
              Text(`${minutes}分钟`).layoutWeight(1).height(34).textAlign(TextAlign.Center).fontSize(11)
                .fontColor(this.draftMinutes === minutes ? Color.White : '#6865D9')
                .backgroundColor(this.draftMinutes === minutes ? '#6865D9' : '#EFEEFA').borderRadius(11)
                .onClick(() => { this.draftMinutes = minutes; })
            }, (minutes: number) => `adjust-minutes-${minutes}`)
          }.width('100%')
          }
          if (this.draftAvailableMinutes.trim().length > 0 &&
            (!/^\d+$/.test(this.draftAvailableMinutes.trim()) || Number(this.draftAvailableMinutes) > 240)) {
            Text('请输入 0—240 分钟；超过范围不会保存').fontSize(11).fontColor('#D85353')
          }
          if (this.draftPriorityMode === 'manual' && this.draftTaskIndex >= 0 &&
            this.draftAvailableMinutes.trim() === '0') {
            Text('已选择优先待办，但接下来时间为 0；保存后不会强行开始任务。')
              .fontSize(10).lineHeight(16).fontColor('#A06A35').width('100%')
          }
          Row({ space: 9 }) {
            Button('保存今天的安排').layoutWeight(1).height(42).fontSize(12)
              .backgroundColor('#6865D9').borderRadius(13)
              .enabled(this.validAdditionalMinutes() &&
                (!this.addingTemporaryTask || this.draftTitle.trim().length > 0))
              .onClick(() => { this.saveTodayAdjust(); })
          }.width('100%')
        }.width('100%').padding(20)
        }.width('92%').height('86%').scrollBar(BarState.Auto)
          .backgroundColor('#FCFBFF').borderRadius(24)
          .shadow({ radius: 28, color: '#33252A4A', offsetX: 0, offsetY: 10 })
          .hitTestBehavior(HitTestMode.Default)
      }
      if (this.deleteConfirmTaskId.length > 0) {
        Column().width('100%').height('100%').backgroundColor('#7A0E1020').hitTestBehavior(HitTestMode.Block)
        Column({ space: 13 }) {
          Text('删除这个待办？').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#24283D').width('100%')
          Text(`「${formatSubjectName(this.deleteTaskTitle())}」删除后将不再参与后续学习安排。只是不想今天学习，可以选择“今天跳过”。`)
            .fontSize(12).lineHeight(19).fontColor('#666B80').width('100%')
          Row({ space: 9 }) {
            Button('取消').layoutWeight(1).height(40).fontSize(12).fontColor('#6865D9')
              .backgroundColor('#EFEEFA').borderRadius(13)
              .onClick(() => { this.deleteConfirmTaskId = ''; })
            Button(this.deleteBusy ? '删除中…' : '删除').layoutWeight(1).height(40).fontSize(12).fontColor(Color.White)
              .backgroundColor('#A6535B').borderRadius(13)
              .enabled(!this.deleteBusy)
              .onClick(() => { this.confirmDeleteTask(); })
          }.width('100%')
        }.width('82%').padding(20).backgroundColor('#FCFBFF').borderRadius(22)
          .shadow({ radius: 28, color: '#44252A4A', offsetX: 0, offsetY: 10 })
          .hitTestBehavior(HitTestMode.Default)
      }
      if (this.resourcePickerOpen && this.currentResourceTask() !== undefined) {
        LearningResourcePicker({
          subject: this.currentResourceTask()?.subject ?? '',
          taskTitle: this.currentResourceTask()?.title ?? '',
          onClose: () => {
            this.resourcePickerOpen = false;
            this.onBusinessOverlayChange(false);
          }
        })
      }
    }.width('100%').layoutWeight(1)
  }
}
