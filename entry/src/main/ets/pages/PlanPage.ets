import { PageHeader } from '../components/PageHeader';
import { ScheduleImportCard } from '../components/ScheduleImportCard';
import { SectionSwitcher } from '../components/SectionSwitcher';
import { AcademicGoal, ScheduleItem } from '../models/StudyModels';
import { formatSubjectName } from '../utils/SubjectDisplayName';
import { ScheduleItemEditor } from '../components/ScheduleItemEditor';
import { ScheduleEditingService } from '../services/ScheduleEditingService';
import { GoalPlanningService } from '../services/GoalPlanningService';
import { GoalDatePickerField } from '../components/GoalDatePickerField';

@Component
export struct PlanPageView {
  @Prop scheduleOnly: boolean = false;
  onBack: () => void = () => {};
  @State addingGoal: boolean = false;
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
  @Prop academicGoals: AcademicGoal[] = [];
  @Prop now: number = Date.now();
  @Prop newGoalTitle: string = '';
  @Prop newGoalSubject: string = '';
  @Prop newGoalDeadline: string = '';
  @Prop newGoalEstimatedMinutes: string = '';
  onUseDemoSchedule: () => void = () => {};
  onImportSchedule: () => void = () => {};
  onConfirmSchedule: () => void = () => {};
  onScheduleDraftItemsChange: (items: ScheduleItem[]) => void = () => {};
  onSaveSchedule: (items: ScheduleItem[]) => Promise<boolean> = async () => false;
  onOpenLearning: () => void = () => {};
  onGoalFieldChange: (field: string, value: string) => void = () => {};
  onAddGoal: () => void = () => {};
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
      GoalPlanningService.normalizeDeadline(this.editGoalDeadline).length === 0 ||
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

  private deadlineStatus(goal: AcademicGoal): string {
    const days: number = GoalPlanningService.daysUntil(goal.deadline, this.now);
    if (days === 999) { return '日期待确认'; }
    if (days < 0) { return `已逾期${Math.abs(days)}天`; }
    if (days === 0) { return '今天截止'; }
    return `还有${days}天`;
  }

  private currentGoals(): AcademicGoal[] {
    return GoalPlanningService.activeGoals(this.academicGoals, this.now);
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

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('‹ 返回学习').fontSize(14).fontColor('#6865D9').width('100%').onClick(() => { this.onBack(); })
        PageHeader({ icon: '', title: this.scheduleOnly ? '课表与时间' : '学习目标', subtitle: this.scheduleOnly ? '先看课程，再安排可用时间' : '管理跨天目标，今天的学习安排请到首页“调整今天安排”' })
        if (!this.scheduleOnly) {
        Button('和小星球聊长期目标').width('100%').height(44).backgroundColor('#6865D9')
          .onClick(() => { this.onOpenLearning(); })
        Column({ space: 12 }) {
          Text('目标中心').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Text('考试、课程与项目可以同时存在；这里保存跨天提醒')
            .width('100%').fontSize(12).lineHeight(20).fontColor('#858B9E')
          if (this.currentGoals().length === 0) {
            Text('暂无进行中的学习目标').width('100%').fontSize(13).fontColor('#969CAD')
              .padding({ top: 8, bottom: 8 })
          }
          ForEach(this.currentGoals(), (goal: AcademicGoal) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(goal.title).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
                  .fontColor(goal.completed ? '#999EAC' : '#2F3448')
                Text(`${formatSubjectName(goal.subject)} · ${goal.deadline}`)
                  .width('100%').fontSize(11).fontColor('#8C92A4')
                Text(this.deadlineStatus(goal)).width('100%').fontSize(11)
                  .fontColor(GoalPlanningService.daysUntil(goal.deadline, this.now) < 0 ? '#B05C62' : '#596EA7')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text('编辑').height(32).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#625DC0')
                .onClick(() => { this.beginGoalEdit(goal); })
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
                  GoalDatePickerField({
                    value: this.editGoalDeadline,
                    fieldHeight: 42,
                    fieldBackgroundColor: Color.White,
                    onConfirm: (value: string) => { this.editGoalDeadline = value; }
                  }).layoutWeight(1)
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
          }, (goal: AcademicGoal) => `${goal.id}-${goal.title}-${goal.subject}-${goal.deadline}-${goal.estimatedMinutes}`)
          Button(this.addingGoal ? '取消新增' : '＋ 新目标').fontSize(13).backgroundColor('#EBEFF8').fontColor('#596EA7')
            .onClick(() => { this.addingGoal = !this.addingGoal; })
          if (this.addingGoal) {
          TextInput({ placeholder: '目标，例如：线代期末复习', text: this.newGoalTitle })
            .height(43).backgroundColor('#F6F7FC').onChange((value: string) => { this.onGoalFieldChange('title', value); })
          Row({ space: 8 }) {
            TextInput({ placeholder: '课程名称', text: this.newGoalSubject }).layoutWeight(1).height(43)
              .backgroundColor('#F6F7FC').onChange((value: string) => { this.onGoalFieldChange('subject', value); })
          }.width('100%')
          GoalDatePickerField({
            value: this.newGoalDeadline,
            fieldHeight: 43,
            onConfirm: (value: string) => { this.onGoalFieldChange('deadline', value); }
          })
          TextInput({ placeholder: '预计总投入（分钟，60—6000）', text: this.newGoalEstimatedMinutes })
            .height(43).backgroundColor('#F6F7FC')
            .onChange((value: string) => { this.onGoalFieldChange('minutes', value); })
          Button('添加目标').width('100%').height(44).backgroundColor('#596EA7')
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
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
