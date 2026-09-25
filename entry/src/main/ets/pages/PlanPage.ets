import { PageHeader } from '../components/PageHeader';
import { ScheduleImportCard } from '../components/ScheduleImportCard';
import { SectionSwitcher } from '../components/SectionSwitcher';
import { AcademicGoal, GoalMilestone, ScheduleItem, StudyTask } from '../models/StudyModels';
import { formatSubjectName } from '../utils/SubjectDisplayName';
import { ScheduleItemEditor } from '../components/ScheduleItemEditor';
import { ScheduleEditingService } from '../services/ScheduleEditingService';

@Component
export struct PlanPageView {
  @Prop scheduleOnly: boolean = false;
  onBack: () => void = () => {};
  @State addingGoal: boolean = false;
  @State expandedGoal: string = '';
  @State selectedWeekday: number = 1;
  @State editingSchedule: boolean = false;
  @State editingScheduleItems: ScheduleItem[] = [];
  @State scheduleDeleteId: string = '';
  @State scheduleEditError: string = '';
  @State scheduleSaving: boolean = false;
  @State editingGoalId: string = '';
  @State editGoalTitle: string = '';
  @State editGoalSubject: string = '';
  @State editGoalDeadline: string = '';
  @State editGoalMinutes: string = '';
  @State goalEditError: string = '';
  @State goalSaving: boolean = false;
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
  @Prop newGoalEstimatedMinutes: string = '';
  onUseDemoSchedule: () => void = () => {};
  onScanSchedule: () => void = () => {};
  onImportSchedule: () => void = () => {};
  onConfirmSchedule: () => void = () => {};
  onScheduleDraftItemsChange: (items: ScheduleItem[]) => void = () => {};
  onSaveSchedule: (items: ScheduleItem[]) => Promise<boolean> = async () => false;
  onOpenLearning: () => void = () => {};
  onNewTaskTitleChange: (value: string) => void = () => {};
  onAddTask: () => void = () => {};
  onStartTask: (index: number) => void = () => {};
  onGoalFieldChange: (field: string, value: string) => void = () => {};
  onAddGoal: () => void = () => {};
  onToggleGoal: (id: string) => void = () => {};
  onUpdateGoal: (id: string, title: string, subject: string, deadline: string,
    estimatedMinutes: number) => Promise<boolean> = async () => false;

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

  private hasRealSchedule(): boolean {
    return this.setupScheduleReady && this.scheduleItems.length > 0 &&
      this.scheduleItems.every((item: ScheduleItem) => !item.id.startsWith('demo-'));
  }

  private beginScheduleEdit(): void {
    this.editingScheduleItems = ScheduleEditingService.copy(this.scheduleItems);
    this.scheduleDeleteId = '';
    this.scheduleEditError = '';
    this.editingSchedule = true;
  }

  private replaceScheduleItem(item: ScheduleItem): void {
    this.editingScheduleItems = ScheduleEditingService.replace(this.editingScheduleItems, item);
  }

  private deleteScheduleItem(id: string): void {
    this.editingScheduleItems = ScheduleEditingService.remove(this.editingScheduleItems, id);
    this.scheduleDeleteId = '';
  }

  private async saveScheduleEdit(): Promise<void> {
    const error: string = ScheduleEditingService.validationError(this.editingScheduleItems);
    if (error.length > 0) { this.scheduleEditError = error; return; }
    this.scheduleSaving = true;
    const saved: boolean = await this.onSaveSchedule(this.editingScheduleItems);
    this.scheduleSaving = false;
    if (saved) {
      this.editingSchedule = false;
      this.scheduleEditError = '';
      return;
    }
    this.scheduleEditError = '保存失败，原课表没有改变，请重试。';
  }

  private beginGoalEdit(goal: AcademicGoal): void {
    this.editingGoalId = goal.id;
    this.editGoalTitle = goal.title;
    this.editGoalSubject = goal.subject;
    this.editGoalDeadline = goal.deadline;
    this.editGoalMinutes = `${goal.estimatedMinutes}`;
    this.goalEditError = '';
  }

  private async saveGoalEdit(): Promise<void> {
    const minutes: number = Number(this.editGoalMinutes.trim());
    if (this.editGoalTitle.trim().length === 0 || this.editGoalSubject.trim().length === 0 ||
      !/^\d{4}-\d{2}-\d{2}$/.test(this.editGoalDeadline.trim()) ||
      !/^\d+$/.test(this.editGoalMinutes.trim()) || minutes < 60 || minutes > 6000) {
      this.goalEditError = '请填写目标名称、学科、有效日期和 60—6000 分钟投入。';
      return;
    }
    this.goalSaving = true;
    const saved: boolean = await this.onUpdateGoal(this.editingGoalId, this.editGoalTitle,
      this.editGoalSubject, this.editGoalDeadline, minutes);
    this.goalSaving = false;
    if (saved) {
      this.editingGoalId = '';
      this.goalEditError = '';
      return;
    }
    this.goalEditError = '保存失败，原目标没有改变，请重试。';
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
        Text(formatSubjectName(item.course)).width('100%').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#25283A')
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
        Text(formatSubjectName(this.tasks[index].title))
          .width('100%').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#25283A')
        Text(`${formatSubjectName(this.tasks[index].subject)} · ${this.tasks[index].minutes}分钟`)
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
        PageHeader({ icon: '', title: this.scheduleOnly ? '课表与时间' : '学习目标', subtitle: this.scheduleOnly ? '先看课程，再安排可用时间' : '管理跨天目标；今天的变化请到首页“调整今天安排”' })
        if (!this.scheduleOnly) {
        Button('和小星球聊长期目标').width('100%').height(44).backgroundColor('#6865D9')
          .onClick(() => { this.onOpenLearning(); })
        Column({ space: 12 }) {
          Text('目标中心').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Text('考试、课程与项目可以同时存在；这里保存跨天目标')
            .width('100%').fontSize(12).lineHeight(20).fontColor('#858B9E')
          ForEach(this.academicGoals, (goal: AcademicGoal) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(goal.title).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
                  .fontColor(goal.completed ? '#999EAC' : '#2F3448')
                Text(`${formatSubjectName(goal.subject)} · 截止 ${goal.deadline}`)
                  .width('100%').fontSize(11).fontColor('#8C92A4')
                Text(`阶段 ${(goal.milestones ?? []).filter((item: GoalMilestone) => item.completed).length} / ${(goal.milestones ?? []).length}`)
                  .width('100%').fontSize(11).fontColor('#596EA7')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column({ space: 5 }) {
                Text('编辑').height(32).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#625DC0')
                  .onClick(() => { this.beginGoalEdit(goal); })
                Text(goal.completed ? '阶段已完成' : '按阶段推进').fontSize(10).fontColor('#8B90A1')
              }.alignItems(HorizontalAlign.End)
            }.width('100%').padding(13).backgroundColor('#F6F7FC').borderRadius(14)
            if (this.editingGoalId === goal.id) {
              Column({ space: 9 }) {
                Row({ space: 7 }) {
                  TextInput({ text: this.editGoalTitle, placeholder: '目标名称' }).layoutWeight(1).height(42)
                    .backgroundColor(Color.White).borderRadius(11)
                    .onChange((value: string) => { this.editGoalTitle = value; })
                  Text('清空').height(40).padding({ left: 10, right: 10 }).fontSize(11).fontColor('#756FC9')
                    .textAlign(TextAlign.Center).onClick(() => { this.editGoalTitle = ''; })
                }.width('100%')
                TextInput({ text: this.editGoalSubject, placeholder: '学科' }).width('100%').height(42)
                  .backgroundColor(Color.White).borderRadius(11)
                  .onChange((value: string) => { this.editGoalSubject = value; })
                Row({ space: 8 }) {
                  TextInput({ text: this.editGoalDeadline, placeholder: '截止日期 YYYY-MM-DD' })
                    .layoutWeight(1).height(42).backgroundColor(Color.White).borderRadius(11)
                    .onChange((value: string) => { this.editGoalDeadline = value; })
                  TextInput({ text: this.editGoalMinutes, placeholder: '总分钟' }).width(112).height(42)
                    .backgroundColor(Color.White).borderRadius(11)
                    .onChange((value: string) => { this.editGoalMinutes = value; })
                }.width('100%')
                if (this.goalEditError.length > 0) {
                  Text(this.goalEditError).fontSize(11).fontColor('#C75656').width('100%')
                }
                Row({ space: 8 }) {
                  Button('取消').layoutWeight(1).height(40).fontSize(12).fontColor('#676C80')
                    .backgroundColor('#E9EAF0').onClick(() => { this.editingGoalId = ''; this.goalEditError = ''; })
                  Button(this.goalSaving ? '保存中…' : '保存目标').layoutWeight(1).height(40).fontSize(12)
                    .backgroundColor('#6865D9').enabled(!this.goalSaving)
                    .onClick(() => { this.saveGoalEdit(); })
                }.width('100%')
              }.width('100%').padding(13).alignItems(HorizontalAlign.Start)
                .backgroundColor('#F0EFFA').borderRadius(14)
            }
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
                  Text(formatSubjectName(milestone.title)).width('100%').fontSize(12).fontColor('#4A5065')
                  Text(`计划 ${milestone.dueDate} 前完成`).width('100%').fontSize(10).fontColor('#969CAD')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding({ left: 12, right: 12 })
            }, (milestone: GoalMilestone) => milestone.id)
            }
          }, (goal: AcademicGoal) => `${goal.id}-${goal.title}-${goal.subject}-${goal.deadline}-${goal.estimatedMinutes}`)
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
          TextInput({ placeholder: '预计总投入（分钟，60—6000）', text: this.newGoalEstimatedMinutes })
            .height(43).backgroundColor('#F6F7FC')
            .onChange((value: string) => { this.onGoalFieldChange('minutes', value); })
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
            if (this.hasRealSchedule() && !this.editingSchedule) {
              Text('编辑课表').height(40).padding({ left: 13, right: 13 }).fontSize(12)
                .fontWeight(FontWeight.Bold).fontColor('#5B5FEF').textAlign(TextAlign.Center)
                .backgroundColor('#ECEBFF').borderRadius(13)
                .onClick(() => { this.beginScheduleEdit(); })
            } else {
              Text(this.setupScheduleReady ? '已同步' : '待导入').fontSize(12)
                .fontColor(this.setupScheduleReady ? '#218764' : '#A26B4E')
            }
          }.width('100%')
          if (this.editingSchedule) {
            Text('编辑状态 · 修改后点击“保存修改”，首页和小星球会读取同一份新课表。')
              .fontSize(11).lineHeight(17).fontColor('#6F7490').width('100%')
            ForEach(this.editingScheduleItems, (item: ScheduleItem) => {
              ScheduleItemEditor({
                item: item,
                deletePending: this.scheduleDeleteId === item.id,
                allowDelete: this.editingScheduleItems.length > 1,
                onChange: (changed: ScheduleItem) => { this.replaceScheduleItem(changed); },
                onRequestDelete: () => { this.scheduleDeleteId = item.id; },
                onConfirmDelete: () => { this.deleteScheduleItem(item.id); },
                onCancelDelete: () => { this.scheduleDeleteId = ''; }
              })
            }, (item: ScheduleItem) => `${item.id}-${item.weekday}`)
            Button('＋ 添加课程').width('100%').height(40).fontSize(12).fontColor('#5B5FEF')
              .backgroundColor('#ECEBFF').onClick(() => {
                this.editingScheduleItems = ScheduleEditingService.add(this.editingScheduleItems);
              })
            if (this.scheduleEditError.length > 0) {
              Text(this.scheduleEditError).fontSize(11).fontColor('#C75656').width('100%')
            }
            Row({ space: 9 }) {
              Button('取消').layoutWeight(1).height(42).fontSize(12).fontColor('#666B80')
                .backgroundColor('#E9EAF0').onClick(() => {
                  this.editingSchedule = false; this.scheduleEditError = ''; this.scheduleDeleteId = '';
                })
              Button(this.scheduleSaving ? '保存中…' : '保存修改').layoutWeight(1).height(42).fontSize(12)
                .backgroundColor('#6865D9').enabled(!this.scheduleSaving)
                .onClick(() => { this.saveScheduleEdit(); })
            }.width('100%')
          } else if (this.setupScheduleReady) {
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
            },
            onDraftItemsChange: (items: ScheduleItem[]) => { this.onScheduleDraftItemsChange(items); }
          })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        }
        if (!this.scheduleOnly) {
        Text('目标关联的学习任务').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
        Text('今天的临时任务、可学习时间和优先项，请在首页调整今天安排。')
          .fontSize(12).fontColor('#858B9D').width('100%')
        ForEach(this.tasks, (task: StudyTask, index: number) => {
          if (task.source !== 'today-temporary') { this.TaskCard(index) }
        }, (task: StudyTask, index: number) => `${index}-${task.title}`)
        }
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
