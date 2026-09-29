import { GoalPlanningService } from '../services/GoalPlanningService';

@Component
export struct GoalDatePickerField {
  @Prop value: string = '';
  @Prop fieldHeight: number = 48;
  @Prop fieldBackgroundColor: ResourceColor = '#F6F7FB';
  onConfirm: (deadline: string) => void = () => {};

  private openCalendar(): void {
    const today: Date = GoalPlanningService.pickerDate('');
    const selected: Date = GoalPlanningService.pickerDate(this.value);
    CalendarPickerDialog.show({
      selected: selected,
      start: today,
      end: new Date(today.getFullYear() + 10, 11, 31),
      markToday: true,
      backgroundColor: Color.White,
      acceptButtonStyle: {
        fontColor: '#5B5FEF', fontWeight: FontWeight.Bold, backgroundColor: '#ECEBFF', borderRadius: 14
      },
      cancelButtonStyle: {
        fontColor: '#676C80', backgroundColor: '#F0F1F6', borderRadius: 14
      },
      onAccept: (date: Date) => {
        const deadline: string = GoalPlanningService.deadlineFromDate(date);
        if (deadline.length > 0) { this.onConfirm(deadline); }
      },
      onCancel: () => {
        // CalendarPickerDialog owns its draft; cancellation intentionally leaves value unchanged.
      }
    });
  }

  build() {
    Row({ space: 10 }) {
      Text(GoalPlanningService.displayDeadline(this.value))
        .layoutWeight(1).fontSize(14)
        .fontColor(this.value.length > 0 ? '#303448' : '#999EAE')
      Text('选择日期  ›').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
    }
    .width('100%').height(this.fieldHeight).padding({ left: 14, right: 14 })
    .backgroundColor(this.fieldBackgroundColor).borderRadius(12)
    .border({ width: 1, color: '#E7E4F5' })
    .onClick(() => { this.openCalendar(); })
  }
}
