import { ScheduleItem } from '../models/StudyModels';
import { formatSubjectName } from '../utils/SubjectDisplayName';
import { ScheduleItemEditor } from './ScheduleItemEditor';
import { ScheduleEditingService } from '../services/ScheduleEditingService';

@Component
export struct ScheduleImportCard {
  @State correcting: boolean = false;
  @State pendingDeleteId: string = '';
  @Prop setupScheduleReady: boolean = false;
  @Prop allowDemoEntry: boolean = true;
  @Prop importStatus: string = 'idle';
  @Prop importMessage: string = '';
  @Prop importSource: string = '';
  @Prop draftItems: ScheduleItem[] = [];
  onScanDocument: () => void = () => {};
  onSelectImage: () => void = () => {};
  onConfirm: () => void = () => {};
  onRetry: () => void = () => {};
  onUseDemo: () => void = () => {};
  onDraftItemsChange: (items: ScheduleItem[]) => void = () => {};

  private replaceDraft(item: ScheduleItem): void {
    this.onDraftItemsChange(ScheduleEditingService.replace(this.draftItems, item));
  }

  private addDraft(): void {
    this.onDraftItemsChange(ScheduleEditingService.add(this.draftItems));
  }

  private deleteDraft(id: string): void {
    this.onDraftItemsChange(ScheduleEditingService.remove(this.draftItems, id));
    this.pendingDeleteId = '';
  }

  private weekdayLabel(weekday: number): string {
    const labels: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[Math.min(7, Math.max(0, weekday))];
  }

  @Builder
  DraftRow(item: ScheduleItem) {
    Row({ space: 10 }) {
      Text(this.weekdayLabel(item.weekday))
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
        .backgroundColor('#ECEBFF').padding({ left: 9, right: 9, top: 6, bottom: 6 }).borderRadius(12)
      Column({ space: 2 }) {
        Text(formatSubjectName(item.course)).width('100%').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#25283A')
        Text(`${item.startTime}-${item.endTime} · ${item.location}`)
          .width('100%').fontSize(11).fontColor('#9397A9')
      }.layoutWeight(1)
    }.width('100%')
  }

  build() {
    Column({ space: 12 }) {
      if (this.importStatus === 'recognizing') {
        Row({ space: 12 }) {
          LoadingProgress().width(28).height(28).color('#5B5FEF')
          Column({ space: 3 }) {
            Text('正在读取课表').width('100%').fontSize(15).fontWeight(FontWeight.Bold)
            Text(this.importMessage.length > 0 ? this.importMessage : '正在识别星期、课程时间和教室…')
              .width('100%').fontSize(12).fontColor('#9397A9')
          }.layoutWeight(1)
        }.width('100%')
      } else if (this.importStatus === 'reviewing') {
        Text(`识别出 ${this.draftItems.length} 门课程，请确认`)
          .width('100%').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#25283A')
        Row() {
          Text(this.correcting ? '正在纠正识别结果' : '请核对课程、时间和地点。')
            .fontSize(12).fontColor('#9397A9').layoutWeight(1)
          Text(this.correcting ? '完成纠错' : '纠正识别结果').height(36).fontSize(12).fontWeight(FontWeight.Bold)
            .fontColor('#5B5FEF').onClick(() => { this.correcting = !this.correcting; this.pendingDeleteId = ''; })
        }.width('100%').alignItems(VerticalAlign.Center)
        if (this.correcting) {
          ForEach(this.draftItems, (item: ScheduleItem) => {
            ScheduleItemEditor({
              item: item,
              deletePending: this.pendingDeleteId === item.id,
              allowDelete: this.draftItems.length > 1,
              onChange: (changed: ScheduleItem) => { this.replaceDraft(changed); },
              onRequestDelete: () => { this.pendingDeleteId = item.id; },
              onConfirmDelete: () => { this.deleteDraft(item.id); },
              onCancelDelete: () => { this.pendingDeleteId = ''; }
            })
          }, (item: ScheduleItem) => `${item.id}-${item.weekday}`)
          Button('＋ 添加课程').width('100%').height(38).fontSize(12).fontColor('#5B5FEF')
            .backgroundColor('#ECEBFF').onClick(() => { this.addDraft(); })
        } else {
          ForEach(this.draftItems.slice(0, 6), (item: ScheduleItem) => {
            this.DraftRow(item)
          }, (item: ScheduleItem) => item.id)
          if (this.draftItems.length > 6) {
            Text(`另有 ${this.draftItems.length - 6} 门课程，纠错时可以逐项查看`)
              .width('100%').fontSize(11).fontColor('#9397A9')
          }
        }
        if (this.importMessage.length > 0 && !this.importMessage.startsWith('已识别')) {
          Text(this.importMessage).width('100%').fontSize(11).fontColor('#C75656')
        }
        Row({ space: 10 }) {
          Button('重新选择').layoutWeight(1).height(42).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
            .onClick(() => {
              this.onRetry();
            })
          Button('确认导入').layoutWeight(1).height(42).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.onConfirm();
            })
        }.width('100%')
      } else {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(this.setupScheduleReady ? '课表已导入' : '导入课表')
              .width('100%').fontSize(15).fontWeight(FontWeight.Bold)
            Text(this.importStatus === 'error' ? this.importMessage :
              (this.setupScheduleReady ? `可重新导入${this.importSource.length > 0 ? ` · ${this.importSource}` : ''}` :
                '选择课表截图'))
              .width('100%').fontSize(12)
              .fontColor(this.importStatus === 'error' ? '#D34F4F' : '#9397A9')
          }.layoutWeight(1)
          Button(this.setupScheduleReady ? '重新扫描' : '智能扫描')
            .height(40).fontSize(12).fontColor(Color.White).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.onScanDocument();
            })
        }.width('100%')
        Button('直接选择课表截图')
          .width('100%').height(36).fontSize(12).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
          .onClick(() => {
            this.onSelectImage();
          })
        if (!this.setupScheduleReady && this.allowDemoEntry) {
          Button('体验演示课表')
            .width('100%').height(38).fontSize(12).fontColor('#777C90').backgroundColor('#F0F1F6')
            .onClick(() => {
              this.onUseDemo();
            })
        }
      }
    }
    .width('100%').padding(14).backgroundColor('#F6F7FB').borderRadius(16)
  }
}
