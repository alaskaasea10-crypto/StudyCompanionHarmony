import { StudyTask } from '../models/StudyModels';
import { UserAvatar } from '../components/UserAvatar';
import { StudyPlanet } from '../components/StudyPlanet';
import { BankLearningEvidence } from '../models/QuestionBankModels';
import { AgentDecisionEvidence, AgentDecisionReason, AgentDecisionResult } from '../services/AgentDecisionService';

@Component
export struct HomePageView {
  @Prop courseHint: string = '导入课表，安排学习时间';
  onOpenSchedule: () => void = () => {};
  @State detailsOpen: boolean = false;
  @State adjustOpen: boolean = false;
  @State draftTaskIndex: number = -1;
  @State draftTitle: string = '';
  @State draftSubject: string = '';
  @State draftMinutes: number = 25;
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
    reasonChain: [], priority: '待安排', confidenceLevel: '依据有限', evidence: [],
    status: { pendingTaskCount: 0, recentTrend: '暂无相关记录' }
  };
  onPrimaryAction: () => void = () => {};
  onAdjustToday: (taskIndex: number, title: string, subject: string, minutes: number) => void = () => {};
  onManageToday: () => void = () => {};
  onStartFocus: (index: number) => void = () => {};
  onToggleRecommendationDetails: () => void = () => {};
  onToggleTask: (index: number, completed: boolean) => void = () => {};

  private availableTaskIndices(): number[] {
    const indices: number[] = [];
    this.tasks.forEach((task: StudyTask, index: number) => {
      if (!task.completed && indices.length < 4) { indices.push(index); }
    });
    return indices;
  }

  private selectDraftTask(index: number): void {
    const task: StudyTask | undefined = this.tasks[index];
    if (task === undefined || task.completed) { return; }
    this.draftTaskIndex = index;
    this.draftTitle = task.title;
    this.draftSubject = task.subject;
    this.draftMinutes = task.minutes;
  }

  private openTodayAdjust(): void {
    const actionIndex: number = this.decision.recommendedAction.taskIndex;
    const initialIndex: number = actionIndex >= 0 && actionIndex < this.tasks.length &&
      !this.tasks[actionIndex].completed ? actionIndex : this.availableTaskIndices()[0] ?? -1;
    if (initialIndex >= 0) {
      this.selectDraftTask(initialIndex);
    } else {
      this.draftTaskIndex = -1;
      this.draftTitle = '';
      this.draftSubject = this.profileSubject;
      this.draftMinutes = 25;
    }
    this.adjustOpen = true;
  }

  private newDraftTask(): void {
    this.draftTaskIndex = -1;
    this.draftTitle = '';
    this.draftSubject = this.profileSubject;
    this.draftMinutes = 25;
  }

  private saveTodayAdjust(): void {
    if (this.draftTitle.trim().length === 0) { return; }
    this.onAdjustToday(this.draftTaskIndex, this.draftTitle, this.draftSubject, this.draftMinutes);
    this.adjustOpen = false;
    this.detailsOpen = false;
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
            Text(this.activeGoalTitle.length > 0 ? this.activeGoalTitle : this.profileSubject)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#363B53')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.activeGoalReason.length > 0) {
              Text(this.activeGoalReason).fontSize(12).fontColor('#858B9D')
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          StudyPlanet({ stage: this.planetStage, planetSize: 48 })
        }.width('100%').alignItems(VerticalAlign.Center)
        Row({ space: 8 }) {
          Text('今日课程').fontSize(12).fontColor('#6865D9')
          Text(this.courseHint).fontSize(12).fontColor('#72798E').layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('›').fontSize(18).fontColor('#969BB0')
        }.width('100%').height(40).padding({ left: 12, right: 12 })
          .backgroundColor('#EFEEF8').borderRadius(12).onClick(() => { this.onOpenSchedule(); })
        Column({ space: 15 }) {
          Row() {
            Text('今日AI决策').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#5450B8')
            Blank()
            Text('调整今天').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#5F5BCB')
              .padding({ left: 11, right: 11, top: 7, bottom: 7 })
              .backgroundColor('#EFEEFA').borderRadius(14)
              .onClick(() => { this.openTodayAdjust(); })
          }.width('100%').alignItems(VerticalAlign.Center)
          Row({ space: 7 }) {
            Text(this.decision.priority).fontSize(11).fontWeight(FontWeight.Medium).fontColor('#5C55BA')
              .padding({ left: 9, right: 9, top: 5, bottom: 5 })
              .backgroundColor('#F0EEFB').borderRadius(10)
            Text(this.decision.confidenceLevel).fontSize(11).fontColor('#777D90')
          }.width('100%')
          Text(this.decision.recommendedAction.headline).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#24283D').width('100%')
            .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.decision.recommendedAction.minutes > 0) {
            Text('约 ' + this.decision.recommendedAction.minutes + ' 分钟 · ' + this.decision.recommendedAction.subject)
              .fontSize(13).fontColor('#6865B5').width('100%')
          }
          Column({ space: 4 }) {
            Text('推荐原因').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#52586E').width('100%')
            Text(this.decision.reasonChain.length > 0 ? this.decision.reasonChain[0].judgment : '暂无相关记录')
              .fontSize(13).lineHeight(19).fontColor('#686E82').width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)
          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('今日目标剩余').fontSize(11).fontColor('#8990A2')
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
          if (this.decision.recommendedAction.stage !== 'resume' &&
            this.decision.recommendedAction.stage !== 'wait' && this.decision.recommendedAction.stage !== 'done') {
            Row() {
              Text('30 分钟后').fontSize(13).fontColor('#7C8296').height(44).layoutWeight(1)
                .textAlign(TextAlign.Center).onClick(() => { this.detailsOpen = false; this.onDefer('later'); })
              Text('今天跳过').fontSize(13).fontColor('#7C8296').height(44).layoutWeight(1)
                .textAlign(TextAlign.Center).onClick(() => { this.detailsOpen = false; this.onDefer('skip'); })
            }.width('100%')
          }
          Text(this.detailsOpen ? '收起决策依据 ⌃' : '查看数据 → 判断 → 推荐 ⌄').fontSize(12).fontColor('#777D94')
            .height(36).onClick(() => { this.detailsOpen = !this.detailsOpen; })
          if (this.detailsOpen) {
            ForEach(this.decision.reasonChain, (reason: AgentDecisionReason, index: number) => {
              Column({ space: 4 }) {
                Text('数据 · ' + reason.data).fontSize(12).fontColor('#656B80').width('100%')
                Text('判断 · ' + reason.judgment).fontSize(12).fontColor('#656B80').width('100%')
                Text('推荐 · ' + reason.recommendation).fontSize(12).fontWeight(FontWeight.Medium)
                  .fontColor('#5551B5').width('100%')
              }.width('100%').padding(11).backgroundColor('#F7F6FC').borderRadius(12)
            }, (reason: AgentDecisionReason, index: number) => `${index}-${reason.data}`)
            Text('数据依据').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#52586E').width('100%')
            ForEach(this.decision.evidence, (item: AgentDecisionEvidence, index: number) => {
              Text(`${item.label}：${item.value} · ${item.source}`)
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
          Text('任务完成  ' + this.completedCount + '/' + this.tasks.length).fontSize(13).fontColor('#858B9D')
        }.width('100%').padding({ top: 8, bottom: 8 })
        }.width('100%').padding({ left: 24, right: 24, top: 20, bottom: 24 })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').scrollBar(BarState.Off)
      if (this.adjustOpen) {
        Column().width('100%').height('100%').backgroundColor('#660E1020')
          .hitTestBehavior(HitTestMode.Block).onClick(() => { this.adjustOpen = false; })
        Column({ space: 14 }) {
          Row() {
            Column({ space: 3 }) {
              Text('调整今天').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#24283D')
              Text('你决定现在做什么，星球负责陪你完成').fontSize(11).fontColor('#858B9D')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('×').width(34).height(34).textAlign(TextAlign.Center).fontSize(24).fontColor('#777D90')
              .onClick(() => { this.adjustOpen = false; })
          }.width('100%')
          Text('选择已有待办').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#666B80').width('100%')
          Column({ space: 7 }) {
            ForEach(this.availableTaskIndices(), (taskIndex: number) => {
              Row({ space: 9 }) {
                Column() {
                  if (this.draftTaskIndex === taskIndex) {
                    Text('✓').fontSize(11).fontColor(Color.White)
                  }
                }.width(22).height(22).borderRadius(11)
                  .backgroundColor(this.draftTaskIndex === taskIndex ? '#6865D9' : '#E8E7F3')
                  .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
                Column({ space: 2 }) {
                  Text(this.tasks[taskIndex].title).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#303449')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${this.tasks[taskIndex].subject} · ${this.tasks[taskIndex].minutes}分钟`)
                    .fontSize(10).fontColor('#898EA1')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
                .backgroundColor(this.draftTaskIndex === taskIndex ? '#F0EFFB' : '#F8F8FC').borderRadius(12)
                .onClick(() => { this.selectDraftTask(taskIndex); })
            }, (taskIndex: number) => `adjust-task-${taskIndex}-${this.tasks[taskIndex].id}`)
            Row({ space: 8 }) {
              Text('+').width(22).height(22).textAlign(TextAlign.Center).fontSize(17).fontColor('#6865D9')
                .backgroundColor('#EAE8FA').borderRadius(11)
              Text('新建一项').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#5F5BCB')
            }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 })
              .backgroundColor(this.draftTaskIndex < 0 ? '#F0EFFB' : '#F8F8FC').borderRadius(12)
              .onClick(() => { this.newDraftTask(); })
          }.width('100%')
          TextInput({ text: this.draftTitle, placeholder: '现在要做什么？' }).width('100%').height(43)
            .fontSize(13).backgroundColor('#F3F2F9').borderRadius(12)
            .onChange((value: string) => { this.draftTitle = value; })
          TextInput({ text: this.draftSubject, placeholder: '科目或主题' }).width('100%').height(41)
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
          Row({ space: 9 }) {
            Button('管理全部待办').layoutWeight(1).height(42).fontSize(12).fontColor('#6865D9')
              .backgroundColor('#EFEEFA').borderRadius(13).onClick(() => {
                this.adjustOpen = false; this.onManageToday();
              })
            Button('保存并设为当前').layoutWeight(1).height(42).fontSize(12)
              .backgroundColor('#6865D9').borderRadius(13).enabled(this.draftTitle.trim().length > 0)
              .opacity(this.draftTitle.trim().length > 0 ? 1 : 0.45)
              .onClick(() => { this.saveTodayAdjust(); })
          }.width('100%')
        }.width('92%').padding(20).backgroundColor('#FCFBFF').borderRadius(24)
          .shadow({ radius: 28, color: '#33252A4A', offsetX: 0, offsetY: 10 })
          .hitTestBehavior(HitTestMode.Default)
      }
    }.width('100%').layoutWeight(1)
  }
}
