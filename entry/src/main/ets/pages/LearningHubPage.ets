import { VideoCatalog } from '../services/VideoCatalog';
import { VideoModule } from '../models/VideoModels';
import { StudyPlanet } from '../components/StudyPlanet';
import { ScheduleImportCard } from '../components/ScheduleImportCard';
import { ScheduleItem } from '../models/StudyModels';
import { AgentDecisionEvidence, AgentDecisionReason, AgentDecisionResult } from '../services/AgentDecisionService';

@Component
export struct LearningHubPageView {
  @Prop decision: AgentDecisionResult = {
    recommendedAction: { stage: 'plan', headline: '等待学习安排', actionTitle: '先安排', reason: '',
      completionStandard: '', nextStep: '', subject: '', minutes: 0, taskIndex: -1, topicId: '' },
    reasonChain: [], priority: '待安排', confidenceLevel: '依据有限', evidence: [],
    status: { pendingTaskCount: 0, recentTrend: '暂无相关记录' }
  };
  @Prop now: number = Date.now();
  @Prop setupScheduleReady: boolean = false;
  @Prop scheduleItems: ScheduleItem[] = [];
  @Prop scheduleImportStatus: string = 'idle';
  @Prop scheduleImportMessage: string = '';
  @Prop scheduleImportSource: string = '';
  @Prop scheduleDraftItems: ScheduleItem[] = [];
  onPrimaryAction: () => void = () => {};
  onOpenSchedule: () => void = () => {};
  onScanSchedule: () => void = () => {};
  onImportSchedule: () => void = () => {};
  onConfirmSchedule: () => void = () => {};
  @Prop planetStage: number = 1;
  onOpen: (destination: number) => void = () => {};

  private hasRealSchedule(): boolean {
    return this.setupScheduleReady && this.scheduleItems.length > 0 &&
      this.scheduleItems.every((item: ScheduleItem) => !item.id.startsWith('demo-'));
  }

  private beijingClock(): string {
    const date: Date = new Date(this.now + 8 * 3600000);
    const hour: string = `${date.getUTCHours()}`.padStart(2, '0');
    const minute: string = `${date.getUTCMinutes()}`.padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private todayCourses(): ScheduleItem[] {
    if (!this.hasRealSchedule()) { return []; }
    const weekday: number = new Date(this.now + 8 * 3600000).getUTCDay() || 7;
    return this.scheduleItems.filter((item: ScheduleItem) => item.weekday === weekday)
      .sort((left: ScheduleItem, right: ScheduleItem) => left.startTime.localeCompare(right.startTime));
  }

  private evidenceValue(label: string): string {
    const item: AgentDecisionEvidence | undefined = this.decision.evidence.find(
      (evidence: AgentDecisionEvidence) => evidence.label === label);
    return item === undefined ? '' : item.value;
  }

  private taskFactor(): string {
    const current: string = this.evidenceValue('当前任务');
    return current.length > 0 ?
      `${this.decision.status.pendingTaskCount} 项未完成 · 当前 ${current}` :
      `${this.decision.status.pendingTaskCount} 项未完成安排`;
  }

  private primaryActionLabel(): string {
    const stage: string = this.decision.recommendedAction.stage;
    if (stage === 'execute') { return '开始学习'; }
    if (stage === 'resume') { return '继续专注'; }
    if (stage === 'verify') { return '记录收获'; }
    return '先安排';
  }

  @Builder
  FactorRow(title: string, value: string, source: string) {
    Column({ space: 4 }) {
      Row() {
        Text(title).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#5E5AB0')
        Blank()
        Text(source).fontSize(10).fontColor('#9397A9')
      }.width('100%')
      Text(value).fontSize(13).lineHeight(19).fontColor('#353A52').width('100%')
    }.width('100%').padding(12).backgroundColor('#F5F4FC').borderRadius(13)
  }

  @Builder
  DecisionStep(reason: AgentDecisionReason, index: number) {
    Column({ space: 7 }) {
      Text(`依据 ${index + 1}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor('#6A64C9').width('100%')
      Text(`数据因素  ·  ${reason.data}`).fontSize(12).lineHeight(18).fontColor('#5D637A').width('100%')
      Text(`判断  ·  ${reason.judgment}`).fontSize(12).lineHeight(18).fontColor('#5D637A').width('100%')
      Text(`推荐  ·  ${reason.recommendation}`).fontSize(12).lineHeight(18)
        .fontWeight(FontWeight.Medium).fontColor('#514BB0').width('100%')
    }.width('100%').padding(12).backgroundColor('#F7F6FC').borderRadius(13)
  }

  @Builder
  CourseRow(item: ScheduleItem) {
    Row({ space: 12 }) {
      Text(item.startTime).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5B56BF').width(48)
      Column({ space: 2 }) {
        Text(item.course).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#30344B').width('100%')
        if (item.location.trim().length > 0) {
          Text(item.location).fontSize(11).fontColor('#858BA1').width('100%')
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(item.endTime).fontSize(11).fontColor('#858BA1')
    }.width('100%').padding(11).backgroundColor('#F6F5FC').borderRadius(13)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 3 }) {
            Text('AI学习空间').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#292D43')
            Text('看清原因，再完成眼前这一项').fontSize(12).fontColor('#8A8FA2')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          StudyPlanet({ stage: this.planetStage, planetSize: 46 })
        }.width('100%').alignItems(VerticalAlign.Center)

        Column({ space: 13 }) {
          Text('✦  当前AI推荐行动').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor('#DFD8FF').width('100%')
          Text(this.decision.recommendedAction.headline.length > 0 ?
            this.decision.recommendedAction.headline : '暂无可执行任务')
            .fontSize(23).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
            .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.decision.recommendedAction.subject.length > 0 || this.decision.recommendedAction.minutes > 0) {
            Text(`${this.decision.recommendedAction.subject}${this.decision.recommendedAction.minutes > 0 ?
              ` · 约${this.decision.recommendedAction.minutes}分钟` : ''}`)
              .fontSize(12).fontColor('#E0DAFF').width('100%')
          }
          Text(this.decision.reasonChain.length > 0 ? this.decision.reasonChain[0].judgment : '依据有限，暂无相关记录')
            .fontSize(13).lineHeight(20).fontColor('#F4F0FF').width('100%')
          Button(this.primaryActionLabel()).width('100%').height(48).fontSize(15)
            .fontWeight(FontWeight.Bold).fontColor('#443B78').backgroundColor(Color.White).borderRadius(15)
            .onClick(() => { this.onPrimaryAction(); })
        }.width('100%').padding(20).backgroundColor('#443B78').borderRadius(24)

        Column({ space: 12 }) {
          Text('为什么现在学习？').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor('#292D43').width('100%')
          this.FactorRow('时间因素', `现在 ${this.beijingClock()} · ${this.evidenceValue('今日目标剩余').length > 0 ?
            `今日目标剩余 ${this.evidenceValue('今日目标剩余')}` : '暂无今日目标记录'}`,
            this.evidenceValue('今日目标剩余').length > 0 ? '当前时间 / 目标与专注记录' : '当前时间')
          this.FactorRow('任务因素', this.taskFactor(), '已保存任务')
          if (this.evidenceValue('已确认考试日期').length > 0) {
            this.FactorRow('截止因素', this.evidenceValue('已确认考试日期'), '你确认的个人目标')
          }
          this.FactorRow('学习状态因素', this.decision.status.recentTrend, '本机专注记录')
          if (this.evidenceValue('课表空档').length > 0) {
            this.FactorRow('课表因素', this.evidenceValue('课表空档'), '已确认课表')
          } else if (!this.hasRealSchedule()) {
            this.FactorRow('课表因素', '暂无真实课表依据', '未参与本次决策')
          }
          Text('数据因素  →  判断  →  推荐').fontSize(12).fontWeight(FontWeight.Bold)
            .fontColor('#625DC0').width('100%').margin({ top: 3 })
          ForEach(this.decision.reasonChain, (reason: AgentDecisionReason, index: number) => {
            this.DecisionStep(reason, index)
          }, (reason: AgentDecisionReason, index: number) => `${index}-${reason.data}`)
          Text(`因此推荐：${this.decision.recommendedAction.headline}`)
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#514BB0').width('100%')
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 12 }) {
          Row() {
            Text('今日课程与安排').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#292D43')
            Blank()
            if (this.hasRealSchedule()) {
              Text('查看课表 ›').fontSize(12).fontColor('#5B56BF').onClick(() => { this.onOpenSchedule(); })
            }
          }.width('100%')
          if (this.hasRealSchedule()) {
            Text(`今天 ${this.todayCourses().length} 节课 · 已导入真实课表`)
              .fontSize(12).fontColor('#777D94').width('100%')
            if (this.todayCourses().length > 0) {
              ForEach(this.todayCourses().slice(0, 2), (item: ScheduleItem) => {
                this.CourseRow(item)
              }, (item: ScheduleItem) => item.id)
              if (this.todayCourses().length > 2) {
                Text(`还有 ${this.todayCourses().length - 2} 节，前往课表查看`)
                  .fontSize(11).fontColor('#777D94').onClick(() => { this.onOpenSchedule(); })
              }
            } else {
              Text('今天没有课程记录').fontSize(13).fontColor('#777D94').width('100%')
            }
          } else {
            Text('暂未导入课表').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#353A52').width('100%')
            if (this.setupScheduleReady) {
              Text('演示课表不会参与AI决策，请导入真实课表。')
                .fontSize(12).fontColor('#858BA1').width('100%')
            }
            ScheduleImportCard({
              setupScheduleReady: false,
              allowDemoEntry: false,
              importStatus: this.scheduleImportStatus,
              importMessage: this.scheduleImportMessage,
              importSource: this.scheduleImportSource,
              draftItems: this.scheduleDraftItems,
              onScanDocument: () => { this.onScanSchedule(); },
              onSelectImage: () => { this.onImportSchedule(); },
              onConfirm: () => { this.onConfirmSchedule(); },
              onRetry: () => { this.onImportSchedule(); }
            })
          }
        }.width('100%').padding(18).backgroundColor('#EEEDFA').borderRadius(22)

        Row({ space: 18 }) {
          Text('目标与计划 ›').fontSize(12).fontColor('#858BA1').height(44)
            .onClick(() => { this.onOpen(1); })
          Text('学习资料 ›').fontSize(12).fontColor('#858BA1').height(44)
            .onClick(() => { this.onOpen(9); })
        }.width('100%').justifyContent(FlexAlign.Center)
      }.padding({ left: 20, right: 20, top: 22, bottom: 28 })
        .width('100%').alignItems(HorizontalAlign.Start)
    }.layoutWeight(1)
  }
}

@Component
export struct LearningResourcesPageView {
  onBack: () => void = () => {};
  onSelect: (moduleId: string) => void = () => {};
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text('‹ 返回学习').fontSize(14).fontColor('#6865D9').onClick(() => { this.onBack(); })
        Text('学习资料').fontSize(27).fontWeight(FontWeight.Bold)
        Text('选择专题，查看视频与资料').fontSize(14).fontColor('#7C8296')
        ForEach(VideoCatalog.modules().filter((item: VideoModule) => item.id === 'matrix'), (item: VideoModule) => {
          Column({ space: 8 }) {
            Text(`${item.title}  ›`).fontSize(19).fontWeight(FontWeight.Bold)
            Text(item.subtitle).fontSize(13).fontColor('#7C8296')
          }.width('100%').padding(22).alignItems(HorizontalAlign.Start).backgroundColor(Color.White)
            .borderRadius(20).onClick(() => { this.onSelect(item.id); })
        }, (item: VideoModule) => item.id)
      }.padding(24).width('100%').alignItems(HorizontalAlign.Start)
    }.layoutWeight(1)
  }
}
