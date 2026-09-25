import { ScheduleItem } from '../models/StudyModels';

@Component
export struct ScheduleItemEditor {
  @Prop item: ScheduleItem = { id: '', weekday: 1, startTime: '09:00', endTime: '10:00',
    course: '', location: '' };
  @Prop deletePending: boolean = false;
  @Prop allowDelete: boolean = true;
  onChange: (item: ScheduleItem) => void = () => {};
  onRequestDelete: () => void = () => {};
  onConfirmDelete: () => void = () => {};
  onCancelDelete: () => void = () => {};

  private changed(field: string, value: string): void {
    this.onChange({
      id: this.item.id,
      weekday: field === 'weekday' ? Number(value) : this.item.weekday,
      startTime: field === 'startTime' ? value : this.item.startTime,
      endTime: field === 'endTime' ? value : this.item.endTime,
      course: field === 'course' ? value : this.item.course,
      location: field === 'location' ? value : this.item.location
    });
  }

  private weekdayLabel(weekday: number): string {
    const labels: string[] = ['', '一', '二', '三', '四', '五', '六', '日'];
    return labels[Math.min(7, Math.max(1, weekday))];
  }

  build() {
    Column({ space: 10 }) {
      TextInput({ text: this.item.course, placeholder: '课程名称' }).width('100%').height(42)
        .fontSize(13).backgroundColor(Color.White).borderRadius(11)
        .onChange((value: string) => { this.changed('course', value); })
      Text('星期').fontSize(11).fontColor('#858BA1').width('100%')
      Row({ space: 4 }) {
        ForEach([1, 2, 3, 4, 5, 6, 7], (weekday: number) => {
          Text(this.weekdayLabel(weekday)).layoutWeight(1).height(32).textAlign(TextAlign.Center).fontSize(10)
            .fontWeight(this.item.weekday === weekday ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.item.weekday === weekday ? Color.White : '#696F84')
            .backgroundColor(this.item.weekday === weekday ? '#6865D9' : '#EDECF6').borderRadius(9)
            .onClick(() => { this.changed('weekday', `${weekday}`); })
        }, (weekday: number) => `schedule-weekday-${this.item.id}-${weekday}`)
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.item.startTime, placeholder: '开始 HH:mm' }).layoutWeight(1).height(40)
          .fontSize(12).backgroundColor(Color.White).borderRadius(11)
          .onChange((value: string) => { this.changed('startTime', value); })
        Text('至').fontSize(11).fontColor('#858BA1')
        TextInput({ text: this.item.endTime, placeholder: '结束 HH:mm' }).layoutWeight(1).height(40)
          .fontSize(12).backgroundColor(Color.White).borderRadius(11)
          .onChange((value: string) => { this.changed('endTime', value); })
      }.width('100%').alignItems(VerticalAlign.Center)
      TextInput({ text: this.item.location, placeholder: '教室或地点（可不填）' }).width('100%').height(40)
        .fontSize(12).backgroundColor(Color.White).borderRadius(11)
        .onChange((value: string) => { this.changed('location', value); })
      if (this.allowDelete) {
        if (this.deletePending) {
          Row({ space: 8 }) {
            Text('只删除这一门课程，确定吗？').fontSize(11).fontColor('#B65353').layoutWeight(1)
            Button('取消').height(34).fontSize(11).fontColor('#666B80').backgroundColor('#EDECF3')
              .onClick(() => { this.onCancelDelete(); })
            Button('确认删除').height(34).fontSize(11).backgroundColor('#C75656')
              .onClick(() => { this.onConfirmDelete(); })
          }.width('100%')
        } else {
          Text('删除这门课程').height(36).fontSize(11).fontColor('#B65353').width('100%')
            .textAlign(TextAlign.End).onClick(() => { this.onRequestDelete(); })
        }
      }
    }.width('100%').padding(13).alignItems(HorizontalAlign.Start)
      .backgroundColor('#F5F4FB').borderRadius(15).border({ width: 1, color: '#E5E3F2' })
  }
}
