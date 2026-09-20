import { PageHeader } from '../components/PageHeader';
import { ScheduleImportCard } from '../components/ScheduleImportCard';
import { SectionSwitcher } from '../components/SectionSwitcher';
import { AcademicGoal, GoalMilestone, ScheduleItem, StudyTask } from '../models/StudyModels';

@Component
export struct PlanPageView {
  @Prop scheduleOnly: boolean = false;
  onBack: () => void = () => {};
  @State addingGoal: boolean = false;
  @State expandedGoal: string = '';
  @State selectedWeekday: number = 1;
  @Prop setupScheduleReady: boolean = false;
  @Prop scheduleItems: ScheduleItem[] = [];
  @Prop scheduleImportStatus: string = 'idle';
  @Prop scheduleImportMessage: string = '';
  @Prop scheduleImportSource: string = '';
  @Prop scheduleDraftItems: ScheduleItem[] = [];
  @Prop newTaskTitle: string = '';
  @Prop profileSubject: string = '';
  @Prop profileExamDate: string = '';
  @Prop examDays: number = 0;
  @Prop tasks: StudyTask[] = [];
  @Prop academicGoals: AcademicGoal[] = [];
  @Prop newGoalTitle: string = '';
  @Prop newGoalSubject: string = '';
  @Prop newGoalDeadline: string = '';
  onUseDemoSchedule: () => void = () => {};
  onScanSchedule: () => void = () => {};
  onImportSchedule: () => void = () => {};
  onConfirmSchedule: () => void = () => {};
  onOpenLearning: () => void = () => {};
  onNewTaskTitleChange: (value: string) => void = () => {};
  onAddTask: () => void = () => {};
  onStartTask: (index: number) => void = () => {};
  onGoalFieldChange: (field: string, value: string) => void = () => {};
  onAddGoal: () => void = () => {};
  onToggleGoal: (id: string) => void = () => {};

  aboutToAppear(): void {
    this.selectedWeekday = this.beijingWeekday();
  }

  private beijingWeekday(): number {
    const beijingClock: Date = new Date(Date.now() + 8 * 60 * 60 * 1000);
    const weekday: number = beijingClock.getUTCDay();
    return weekday === 0 ? 7 : weekday;
  }

  private weekdayLabel(weekday: number): string {
    const labels: string[] = ['', '一', '二', '三', '四', '五', '六', '日'];
    return labels[Math.min(7, Math.max(1, weekday))];
  }

  private scheduleCount(weekday: number): number {
    return this.scheduleItems.filter((item: ScheduleItem) => item.weekday === weekday).length;
  }

  private selectedScheduleItems(): ScheduleItem[] {
    return this.scheduleItems
      .filter((item: ScheduleItem) => item.weekday === this.selectedWeekday)
      .sort((first: ScheduleItem, second: ScheduleItem) => first.startTime.localeCompare(second.startTime));
  }

  @Builder
  WeekdayButton(weekday: number) {
    Column({ space: 3 }) {
      Text(`周${this.weekdayLabel(weekday)}`)
        .fontSize(12)
        .fontWeight(this.selectedWeekday === weekday ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedWeekday === weekday ? Color.White : '#666C82')
      Text(`${this.scheduleCount(weekday)}节`)
        .fontSize(10)
        .fontColor(this.selectedWeekday === weekday ? '#E9E8FF' : '#A2A6B6')
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedWeekday === weekday ? '#5B5FEF' : '#F3F4F8')
    .borderRadius(13)
    .onClick(() => {
      this.selectedWeekday = weekday;
    })
  }

  @Builder
  ScheduleRow(item: ScheduleItem) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(item.startTime).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
        Text(item.endTime).fontSize(11).fontColor('#A2A6B6')
      }.width(48).alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) {
        Text(item.course).width('100%').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#25283A')
        Text(item.location.length > 0 ? item.location : '地点待补充')
          .width('100%').fontSize(12).fontColor('#9397A9')
      }.layoutWeight(1)
    }
    .width('100%').padding({ top: 11, bottom: 11, left: 12, right: 12 })
    .backgroundColor('#F8F8FC').borderRadius(14)
  }

  @Builder
  TaskCard(index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.tasks[index].title)
          .width('100%').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#25283A')
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%').fontSize(12).fontColor('#9A9EB0')
      }.layoutWeight(1)
      if (this.tasks[index].completed) {
        Text(this.tasks[index].outcome === 'verified' ? '验证通过' :
          this.tasks[index].outcome === 'submitted' ? '已自查' : '已完成').fontSize(13).fontColor('#22B07D').backgroundColor('#E8F8F2')
          .padding({ left: 11, right: 11, top: 7, bottom: 7 }).borderRadius(14)
      } else {
        Button(this.tasks[index].outcome === 'focused' || this.tasks[index].outcome === 'submitted' ? '交结果' : '开始')
          .fontSize(13).height(36).backgroundColor('#5B5FEF')
          .onClick(() => {
            this.onStartTask(index);
          })
      }
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('‹ 返回学习').fontSize(14).fontColor('#6865D9').width('100%').onClick(() => { this.onBack(); })
        PageHeader({ icon: '', title: this.scheduleOnly ? '课表与时间' : '目标与计划', subtitle: this.scheduleOnly ? '先看课程，再安排可用时间' : '明确目标，把下一步落到行动上' })
        if (!this.scheduleOnly) {
        Button('调整计划').width('100%').height(44).backgroundColor('#6865D9')
          .onClick(() => { this.onOpenLearning(); })
        Column({ space: 12 }) {
          Text('目标中心').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Text('考试、作业、项目，选一件先推进')
            .width('100%').fontSize(12).lineHeight(20).fontColor('#858B9E')
          ForEach(this.academicGoals, (goal: AcademicGoal) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(goal.title).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
                  .fontColor(goal.completed ? '#999EAC' : '#2F3448')
                Text(`${goal.subject} · 截止 ${goal.deadline}`)
                  .width('100%').fontSize(11).fontColor('#8C92A4')
                Text(`阶段 ${(goal.milestones ?? []).filter((item: GoalMilestone) => item.completed).length} / ${(goal.milestones ?? []).length}`)
                  .width('100%').fontSize(11).fontColor('#596EA7')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(goal.completed ? '阶段已完成' : '按阶段推进').fontSize(11).fontColor('#596EA7')
            }.width('100%').padding(13).backgroundColor('#F6F7FC').borderRadius(14)
            Text(this.expandedGoal === goal.id ? '收起阶段 ⌃' : '查看阶段 ›').fontSize(12).fontColor('#596EA7').width('100%')
              .onClick(() => { this.expandedGoal = this.expandedGoal === goal.id ? '' : goal.id; })
            if (this.expandedGoal === goal.id) {
            ForEach(goal.milestones ?? [], (milestone: GoalMilestone, index: number) => {
              Row({ space: 8 }) {
                Text(milestone.completed ? '✓' : `${index + 1}`)
                  .width(22).height(22).textAlign(TextAlign.Center).fontSize(11)
                  .fontColor(milestone.completed ? Color.White : '#596EA7')
                  .backgroundColor(milestone.completed ? '#35B58A' : '#EBEFF8').borderRadius(11)
                Column({ space: 2 }) {
                  Text(milestone.title).width('100%').fontSize(12).fontColor('#4A5065')
                  Text(`计划 ${milestone.dueDate} 前完成`).width('100%').fontSize(10).fontColor('#969CAD')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding({ left: 12, right: 12 })
            }, (milestone: GoalMilestone) => milestone.id)
            }
          }, (goal: AcademicGoal) => goal.id)
          Button(this.addingGoal ? '取消新增' : '＋ 新目标').fontSize(13).backgroundColor('#EBEFF8').fontColor('#596EA7')
            .onClick(() => { this.addingGoal = !this.addingGoal; })
          if (this.addingGoal) {
          TextInput({ placeholder: '目标，例如：线代期末复习', text: this.newGoalTitle })
            .height(43).backgroundColor('#F6F7FC').onChange((value: string) => { this.onGoalFieldChange('title', value); })
          Row({ space: 8 }) {
            TextInput({ placeholder: '课程名称', text: this.newGoalSubject }).layoutWeight(1).height(43)
              .backgroundColor('#F6F7FC').onChange((value: string) => { this.onGoalFieldChange('subject', value); })
            TextInput({ placeholder: '截止日期 YYYY-MM-DD', text: this.newGoalDeadline }).layoutWeight(1).height(43)
              .backgroundColor('#F6F7FC').onChange((value: string) => { this.onGoalFieldChange('deadline', value); })
          }.width('100%')
          Button('添加目标并生成第一步').width('100%').height(44).backgroundColor('#596EA7')
            .onClick(() => { this.onAddGoal(); })
          }
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        }
        if (this.scheduleOnly) {
        Column({ space: 12 }) {
          Row() {
            Column({ space: 3 }) {
              Text('一周课表').fontSize(18).fontWeight(FontWeight.Bold)
              Text(`${this.setupScheduleReady ? this.scheduleItems.length : 0} 节课`)
                .fontSize(11).fontColor('#9397A9')
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Text(this.setupScheduleReady ? '已同步' : '待导入').fontSize(12)
              .fontColor(this.setupScheduleReady ? '#218764' : '#A26B4E')
          }.width('100%')
          if (this.setupScheduleReady) {
            Row({ space: 5 }) {
              ForEach([1, 2, 3, 4, 5, 6, 7], (weekday: number) => {
                this.WeekdayButton(weekday)
              })
            }.width('100%')
            Row() {
              Text(`周${this.weekdayLabel(this.selectedWeekday)}课程`)
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#25283A')
              if (this.selectedWeekday === this.beijingWeekday()) {
                Text('今天').fontSize(10).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(10)
                  .margin({ left: 7 })
              }
            }.width('100%')
            if (this.selectedScheduleItems().length > 0) {
              ForEach(this.selectedScheduleItems(), (item: ScheduleItem) => {
                this.ScheduleRow(item)
              }, (item: ScheduleItem) => item.id)
            } else {
              Column({ space: 5 }) {
                Text('☕').fontSize(24)
                Text('这一天暂时没有课程').fontSize(13).fontColor('#777C90')
              }
              .width('100%').height(82).justifyContent(FlexAlign.Center)
              .backgroundColor('#F8F8FC').borderRadius(14)
            }
          }
          ScheduleImportCard({
            setupScheduleReady: this.setupScheduleReady,
            importStatus: this.scheduleImportStatus,
            importMessage: this.scheduleImportMessage,
            importSource: this.scheduleImportSource,
            draftItems: this.scheduleDraftItems,
            onScanDocument: () => {
              this.onScanSchedule();
            },
            onSelectImage: () => {
              this.onImportSchedule();
            },
            onConfirm: () => {
              this.onConfirmSchedule();
            },
            onRetry: () => {
              this.onImportSchedule();
            },
            onUseDemo: () => {
              this.onUseDemoSchedule();
            }
          })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        }
        if (!this.scheduleOnly) {
        Row({ space: 10 }) {
          TextInput({ placeholder: '添加今天要完成的任务', text: this.newTaskTitle })
            .layoutWeight(1).height(46).backgroundColor(Color.White).borderRadius(14)
            .onChange((value: string) => {
              this.onNewTaskTitleChange(value);
            })
          Button('添加').height(46).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.onAddTask();
            })
        }.width('100%')
        ForEach(this.tasks, (task: StudyTask, index: number) => {
          this.TaskCard(index)
        }, (task: StudyTask, index: number) => `${index}-${task.title}`)
        }
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
