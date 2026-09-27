import { VideoCatalog } from '../services/VideoCatalog';
import { VideoModule } from '../models/VideoModels';
import { StudyPlanet } from '../components/StudyPlanet';
import { ScheduleImportCard } from '../components/ScheduleImportCard';
import { AcademicGoal, ScheduleItem } from '../models/StudyModels';
import { AgentDailyPlanItem, AgentDecisionEvidence, AgentDecisionReason, AgentDecisionResult } from '../services/AgentDecisionService';
import { formatSubjectName } from '../utils/SubjectDisplayName';
import { LearningResourcePicker } from '../components/LearningResourcePicker';
import { GoalPlanningService } from '../services/GoalPlanningService';

@Component
export struct LearningHubPageView {
  @State resourcePickerOpen: boolean = false;
  @Prop decision: AgentDecisionResult = {
    recommendedAction: { stage: 'plan', headline: '等待学习安排', actionTitle: '先安排', reason: '',
      completionStandard: '', nextStep: '', subject: '', minutes: 0, taskIndex: -1, topicId: '' },
    dailyPlan: [], reasonChain: [], priority: '待安排', confidenceLevel: '依据有限', evidence: [],
    status: { pendingTaskCount: 0, recentTrend: '暂无相关记录' }
  };
  @Prop now: number = Date.now();
  @Prop todayTimeText: string = '0分钟';
  @Prop completedCount: number = 0;
  @Prop setupScheduleReady: boolean = false;
  @Prop scheduleItems: ScheduleItem[] = [];
  @Prop scheduleImportStatus: string = 'idle';
  @Prop scheduleImportMessage: string = '';
  @Prop scheduleImportSource: string = '';
  @Prop scheduleDraftItems: ScheduleItem[] = [];
  @Prop academicGoals: AcademicGoal[] = [];
  onPrimaryAction: () => void = () => {};
  onOpenSchedule: () => void = () => {};
  onImportSchedule: () => void = () => {};
  onConfirmSchedule: () => void = () => {};
  onScheduleDraftItemsChange: (items: ScheduleItem[]) => void = () => {};
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
    return item === undefined ? '' : formatSubjectName(item.value);
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

  private upcomingPlan(): AgentDailyPlanItem[] {
    const currentKey: string = this.decision.recommendedAction.key ?? '';
    return this.decision.dailyPlan.filter((item: AgentDailyPlanItem) =>
      `task:${item.taskId}` !== currentKey);
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

  private visibleGoals(): AcademicGoal[] {
    return GoalPlanningService.activeGoals(this.academicGoals, this.now).slice(0, 2);
  }

  private goalDate(deadline: string): string {
    const parts: string[] = deadline.split('-');
    if (parts.length === 3) {
      const month: number = Number(parts[1]);
      const day: number = Number(parts[2]);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return `${month}月${day}日`;
      }
    }
    return deadline.trim().length > 0 ? deadline : '日期待补充';
  }

  @Builder
  FactorRow(title: string, value: string, source: string) {
    Column({ space: 4 }) {
      Row() {
        Text(title).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#5E5AB0')
        Blank()
        Text(source).fontSize(10).fontColor('#9397A9')
      }.width('100%')
      Text(formatSubjectName(value)).fontSize(13).lineHeight(19).fontColor('#353A52').width('100%')
    }.width('100%').padding(12).backgroundColor('#F5F4FC').borderRadius(13)
  }

  @Builder
  DecisionStep(reason: AgentDecisionReason, index: number) {
    Column({ space: 7 }) {
      Text(`小提醒 ${index + 1}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor('#6A64C9').width('100%')
      Text(`🌱 我发现  ·  ${formatSubjectName(reason.data)}`).fontSize(12).lineHeight(18).fontColor('#5D637A').width('100%')
      Text(`💭 我想到  ·  ${formatSubjectName(reason.judgment)}`).fontSize(12).lineHeight(18).fontColor('#5D637A').width('100%')
      Text(`✨ 我建议  ·  ${formatSubjectName(reason.recommendation)}`).fontSize(12).lineHeight(18)
        .fontWeight(FontWeight.Medium).fontColor('#514BB0').width('100%')
    }.width('100%').padding(12).backgroundColor('#F7F6FC').borderRadius(13)
  }

  @Builder
  CourseRow(item: ScheduleItem) {
    Row({ space: 12 }) {
      Text(item.startTime).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5B56BF').width(48)
      Column({ space: 2 }) {
        Text(formatSubjectName(item.course)).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#30344B').width('100%')
        if (item.location.trim().length > 0) {
          Text(item.location).fontSize(11).fontColor('#858BA1').width('100%')
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(item.endTime).fontSize(11).fontColor('#858BA1')
    }.width('100%').padding(11).backgroundColor('#F6F5FC').borderRadius(13)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 3 }) {
            Text('星球学习空间').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#292D43')
            Text('先做好眼前这一项，再慢慢往前走').fontSize(12).fontColor('#8A8FA2')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          StudyPlanet({ stage: this.planetStage, planetSize: 46 })
        }.width('100%').alignItems(VerticalAlign.Center)

        Column({ space: 13 }) {
          Text('✦  现在先做').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor('#DFD8FF').width('100%')
          Text(this.decision.recommendedAction.headline.length > 0 ?
            formatSubjectName(this.decision.recommendedAction.headline) : '暂无可执行任务')
            .fontSize(23).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
            .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.decision.recommendedAction.subject.length > 0 || this.decision.recommendedAction.minutes > 0) {
            Text(`${formatSubjectName(this.decision.recommendedAction.subject)}${this.decision.recommendedAction.minutes > 0 ?
              ` · 约${this.decision.recommendedAction.minutes}分钟` : ''}`)
              .fontSize(12).fontColor('#E0DAFF').width('100%')
          }
          Button(this.primaryActionLabel()).width('100%').height(48).fontSize(15)
            .fontWeight(FontWeight.Bold).fontColor('#443B78').backgroundColor(Color.White).borderRadius(15)
            .onClick(() => { this.onPrimaryAction(); })
          if (this.currentResourceTask() !== undefined) {
            Row({ space: 7 }) {
              Text('✨').fontSize(14)
              Text('小星球帮我找资料').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#F2EEFF')
              Text('›').fontSize(18).fontColor('#D8D0FF')
            }.width('100%').height(44).justifyContent(FlexAlign.Center)
              .backgroundColor('#554A8A').borderRadius(14)
              .border({ width: 1, color: '#7569AA' })
              .onClick(() => { this.resourcePickerOpen = true; })
          }
        }.width('100%').padding(20).backgroundColor('#443B78').borderRadius(24)

        if (this.decision.dailyPlan.length > 0) {
          Column({ space: 13 }) {
            Text('今天的学习节奏').fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor('#292D43').width('100%')
            if (this.decision.reasonChain.length > 0) {
              Column({ space: 4 }) {
                Text('小星球发现').fontSize(12).fontWeight(FontWeight.Bold)
                  .fontColor('#5D55BE').width('100%')
                Text(formatSubjectName(`${this.decision.reasonChain[0].data}；${this.decision.reasonChain[0].judgment}`))
                  .fontSize(12).lineHeight(18).fontColor('#656B80').width('100%')
              }.width('100%').padding(12).alignItems(HorizontalAlign.Start)
                .backgroundColor('#F7F6FC').borderRadius(13)
            }
            Row({ space: 12 }) {
              Text('现在').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#5D55BE')
                .padding({ left: 9, right: 9, top: 6, bottom: 6 })
                .backgroundColor('#EEECFA').borderRadius(9)
              Column({ space: 3 }) {
                Text(formatSubjectName(this.decision.recommendedAction.headline)).fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor('#30344B').width('100%')
                Text('需要先推进眼前这一项').fontSize(11).fontColor('#7772B8').width('100%')
                if (this.decision.recommendedAction.subject.length > 0 &&
                  this.decision.recommendedAction.minutes > 0) {
                  Text(`${formatSubjectName(this.decision.recommendedAction.subject)} · 约${this.decision.recommendedAction.minutes}分钟`)
                    .fontSize(11).fontColor('#858BA1').width('100%')
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').alignItems(VerticalAlign.Top)
            ForEach(this.upcomingPlan(), (item: AgentDailyPlanItem, index: number) => {
              Row({ space: 12 }) {
                Text(index === 0 ? '之后' : '稍后').fontSize(11).fontWeight(FontWeight.Medium)
                  .fontColor('#7973B9').width(48)
                Column({ space: 3 }) {
                  Text(formatSubjectName(item.title)).fontSize(13).fontWeight(FontWeight.Medium)
                    .fontColor('#41465D').width('100%')
                  Text(`${formatSubjectName(item.subject)} · 约${item.suggestedMinutes}分钟`)
                    .fontSize(11).fontColor('#858BA1').width('100%')
                  Text(index === 0 ? '可以继续完成' :
                    item.suggestedMinutes <= 20 ? '可以留给碎片时间' : '留给后面的时间')
                    .fontSize(11).fontColor('#7772B8').width('100%')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').alignItems(VerticalAlign.Top)
            }, (item: AgentDailyPlanItem) => item.taskId)
            Text(this.upcomingPlan().length > 0 ?
              '这些是今天的建议次序，完成眼前这一项后再看下一步。' :
              '还没有确认更多可安排时间，先专注眼前这一项。')
              .fontSize(11).lineHeight(17).fontColor('#858BA1').width('100%')
          }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
            .backgroundColor(Color.White).borderRadius(22)
        } else if (this.needsMoreGoals()) {
          Text('小星球还不了解你的全部安排，可以先告诉我更多学习目标。')
            .fontSize(12).lineHeight(19).fontColor('#777D94').width('100%')
            .padding(16).backgroundColor(Color.White).borderRadius(16)
        }

        Column({ space: 12 }) {
          Text('小星球想到这些').fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor('#292D43').width('100%')
          this.FactorRow('当前目标', this.evidenceValue('当前任务').length > 0 ?
            this.evidenceValue('当前任务') : '暂无当前任务记录', '已保存任务')
          this.FactorRow('时间安排', this.evidenceValue('今日目标剩余').length > 0 ?
            `现在 ${this.beijingClock()} · ${this.evidenceValue('今日目标剩余')}` :
            this.decision.recommendedAction.minutes > 0 ?
              `现在 ${this.beijingClock()} · 本轮约${this.decision.recommendedAction.minutes}分钟` :
              `现在 ${this.beijingClock()} · 暂无可安排时长记录`, '当前时间与学习记录')
          this.FactorRow('已完成情况', `已完成${this.completedCount}项任务 · 今日已投入${this.todayTimeText}`,
            '已保存任务与本机专注记录')
          if (this.evidenceValue('已确认考试日期').length > 0) {
            this.FactorRow('目标日期', this.evidenceValue('已确认考试日期'), '你确认的个人目标')
          }
          this.FactorRow('最近的学习', this.decision.status.recentTrend, '本机专注记录')
          if (this.evidenceValue('课表空档').length > 0) {
            this.FactorRow('今天的课程', this.evidenceValue('课表空档'), '已确认课表')
          } else if (!this.hasRealSchedule()) {
            this.FactorRow('今天的课程', '还没有导入真实课表', '导入后我就能参考')
          }
          if (this.decision.reasonChain.length > 0) {
            Text('小星球想到').fontSize(12).fontWeight(FontWeight.Bold)
              .fontColor('#625DC0').width('100%').margin({ top: 3 })
            ForEach(this.decision.reasonChain, (reason: AgentDecisionReason, index: number) => {
              this.DecisionStep(reason, index)
            }, (reason: AgentDecisionReason, index: number) => `${index}-${reason.data}`)
            Text(`✨ 小星球提醒 · ${formatSubjectName(this.decision.recommendedAction.headline)}`)
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#514BB0').width('100%')
          }
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 11 }) {
          Row() {
            Text('学习目标').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#292D43')
            Blank()
            Text('查看全部 ›').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#625DC0')
          }.width('100%')
          if (this.visibleGoals().length > 0) {
            ForEach(this.visibleGoals(), (goal: AcademicGoal) => {
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(`${formatSubjectName(goal.subject)} · ${this.goalDate(goal.deadline)}`)
                    .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#3D4259').width('100%')
                  Text(goal.title).fontSize(11).fontColor('#898EA1').width('100%')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text('›').fontSize(18).fontColor('#A5A1C8')
              }.width('100%')
            }, (goal: AcademicGoal) => goal.id)
          } else {
            Text('暂未设置学习目标')
              .fontSize(12).lineHeight(18).fontColor('#858BA1').width('100%')
          }
        }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
          .backgroundColor('#F7F6FC').borderRadius(18)
          .border({ width: 1, color: '#E7E4F5' })
          .onClick(() => { this.onOpen(1); })

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
              Text('演示课表不能作为今天安排的依据，请导入真实课表。')
                .fontSize(12).fontColor('#858BA1').width('100%')
            }
            ScheduleImportCard({
              setupScheduleReady: false,
              allowDemoEntry: false,
              importStatus: this.scheduleImportStatus,
              importMessage: this.scheduleImportMessage,
              importSource: this.scheduleImportSource,
              draftItems: this.scheduleDraftItems,
              onSelectImage: () => { this.onImportSchedule(); },
              onConfirm: () => { this.onConfirmSchedule(); },
              onRetry: () => { this.onImportSchedule(); },
              onDraftItemsChange: (items: ScheduleItem[]) => { this.onScheduleDraftItemsChange(items); }
            })
          }
        }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
          .backgroundColor('#F7F6FC').borderRadius(18)
          .border({ width: 1, color: '#E7E4F5' })

      }.padding({ left: 20, right: 20, top: 22, bottom: 28 })
        .width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%')
    if (this.resourcePickerOpen && this.currentResourceTask() !== undefined) {
      LearningResourcePicker({
        subject: this.currentResourceTask()?.subject ?? '',
        taskTitle: this.currentResourceTask()?.title ?? '',
        onClose: () => { this.resourcePickerOpen = false; }
      })
    }
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
