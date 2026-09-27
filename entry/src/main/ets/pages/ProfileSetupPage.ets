import { ScheduleImportCard } from '../components/ScheduleImportCard';
import { UserAvatar } from '../components/UserAvatar';
import { StudyPlanet } from '../components/StudyPlanet';
import { ScheduleItem } from '../models/StudyModels';
import { formatSubjectName } from '../utils/SubjectDisplayName';

@Component
export struct ProfileSetupPageView {
  @Prop profileAvatarUri: string = '';
  @Prop avatarStatus: string = '';
  @Prop profileName: string = '';
  @Prop profileGrade: string = '';
  @Prop profileMajor: string = '';
  @Prop profileGoal: string = '';
  @Prop profileSubject: string = '';
  @Prop profileExamDate: string = '';
  @Prop profileDailyMinutes: number = 0;
  @Prop profilePreferredTime: string = '';
  @Prop profileLearningStyle: string = '';
  @Prop profileSupportStyle: string = '';
  @Prop setupScheduleReady: boolean = false;
  @Prop scheduleImportStatus: string = 'idle';
  @Prop scheduleImportMessage: string = '';
  @Prop scheduleImportSource: string = '';
  @Prop scheduleDraftItems: ScheduleItem[] = [];
  onTextChange: (field: string, value: string) => void = () => {};
  onChoiceChange: (group: string, value: string) => void = () => {};
  onUseDemoSchedule: () => void = () => {};
  onImportSchedule: () => void = () => {};
  onConfirmSchedule: () => void = () => {};
  onScheduleDraftItemsChange: (items: ScheduleItem[]) => void = () => {};
  onSaveProfile: () => void = () => {};
  onSelectAvatar: () => void = () => {};

  private choiceValue(group: string): string {
    if (group === 'grade') {
      return this.profileGrade;
    }
    if (group === 'goal') {
      return this.profileGoal;
    }
    if (group === 'subject') {
      return this.profileSubject;
    }
    if (group === 'time') {
      return this.profilePreferredTime;
    }
    if (group === 'style') {
      return this.profileLearningStyle;
    }
    if (group === 'support') {
      return this.profileSupportStyle;
    }
    if (group === 'minutes') {
      return this.profileDailyMinutes.toString();
    }
    // 目标区或未来新增的选择组不得意外读取“每日分钟数”。
    return '';
  }

  private supportedSubject(): boolean {
    return this.profileSubject === '高等数学' || this.profileSubject === '线性代数' ||
      this.profileSubject === '大学英语';
  }

  private supportedDailyMinutes(): boolean {
    return [60, 120, 180, 240, 300].includes(this.profileDailyMinutes);
  }

  @Builder
  ChoiceChip(group: string, value: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.choiceValue(group) === value ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.choiceValue(group) === value ? Color.White : '#5F6478')
      .backgroundColor(this.choiceValue(group) === value ? '#5B5FEF' : '#F0F1F6')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 }).borderRadius(18)
      .onClick(() => {
        this.onChoiceChange(group, value);
      })
  }

  @Builder
  SetupSection(number: string, title: string, subtitle: string) {
    Row({ space: 12 }) {
      Text(number)
        .width(32).height(32).textAlign(TextAlign.Center)
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .backgroundColor('#5B5FEF').borderRadius(16)
      Column({ space: 3 }) {
        Text(title).width('100%').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#25283A')
        Text(subtitle).width('100%').fontSize(12).fontColor('#9397A9')
      }.layoutWeight(1)
    }.width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 14 }) {
          StudyPlanet({ stage: 1, planetSize: 58 })
          Column({ space: 7 }) {
            Text('第一次见面').width('100%').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
            Text('先让星球认识你').width('100%').fontSize(27).fontWeight(FontWeight.Bold).fontColor('#202235')
            Text('这些信息只保存在本机，用来生成符合你真实情况的建议。')
              .width('100%').fontSize(13).fontColor('#777C90').lineHeight(20)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').padding({ top: 10, bottom: 4 }).alignItems(VerticalAlign.Center)

        Column({ space: 14 }) {
          this.SetupSection('1', '基本信息', '头像、称呼、年级与专业')
          Row({ space: 15 }) {
            UserAvatar({
              avatarUri: this.profileAvatarUri,
              profileName: this.profileName,
              avatarSize: 72
            })
            Column({ space: 7 }) {
              Button(this.profileAvatarUri.length > 0 ? '更换头像' : '从图库选择头像')
                .height(38).fontSize(13).fontColor('#5B5FEF')
                .backgroundColor('#F0EFFF').borderRadius(13)
                .onClick(() => {
                  this.onSelectAvatar();
                })
              Text(this.avatarStatus).fontSize(11).fontColor('#9397A9')
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          TextInput({ placeholder: '希望学伴怎么称呼你', text: this.profileName })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.onTextChange('name', value);
            })
          Row({ space: 8 }) {
            this.ChoiceChip('grade', '大一', '大一')
            this.ChoiceChip('grade', '大二', '大二')
            this.ChoiceChip('grade', '大三', '大三')
            this.ChoiceChip('grade', '大四', '大四')
          }.width('100%')
          TextInput({ placeholder: '例如：计算机科学与技术', text: this.profileMajor })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.onTextChange('major', value);
            })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('2', '导入课表', '让 Agent 找到真正可用的学习时间')
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
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('3', '最近目标', '科目、考试日期与目标类型')
          Row({ space: 8 }) {
            this.ChoiceChip('goal', '期末复习', '期末复习')
            this.ChoiceChip('goal', '考研准备', '考研准备')
            this.ChoiceChip('goal', '能力提升', '能力提升')
          }.width('100%')
          Text('当前最重要的科目').width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            this.ChoiceChip('subject', '高等数学', '高等数学')
            this.ChoiceChip('subject', '线性代数', '线性代数')
          }.width('100%')
          Row({ space: 8 }) {
            this.ChoiceChip('subject', '大学英语', '大学英语')
          }.width('100%')
          if (!this.supportedSubject() && this.profileSubject.trim().length > 0) {
            Text(`当前保存的科目：${formatSubjectName(this.profileSubject)}。选择上方科目后才会更新。`)
              .width('100%').fontSize(11).lineHeight(17).fontColor('#8B90A5')
          }
          Text('考试/目标日期').width('100%').fontSize(13).fontColor('#777C90')
          TextInput({ placeholder: '考试日期，例如 2026-09-07', text: this.profileExamDate })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.onTextChange('examDate', value);
            })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('4', '学习节奏', '每天能学多久、什么时候更舒服')
          Row({ space: 8 }) {
            this.ChoiceChip('minutes', '60', '1小时')
            this.ChoiceChip('minutes', '120', '2小时')
            this.ChoiceChip('minutes', '180', '3小时')
          }.width('100%')
          Row({ space: 8 }) {
            this.ChoiceChip('minutes', '240', '4小时')
            this.ChoiceChip('minutes', '300', '5小时')
          }.width('100%')
          if (!this.supportedDailyMinutes()) {
            Text(`当前保存为${this.profileDailyMinutes}分钟。选择上方时长后才会更新。`)
              .width('100%').fontSize(11).lineHeight(17).fontColor('#8B90A5')
          }
          Row({ space: 8 }) {
            this.ChoiceChip('time', '清晨', '清晨')
            this.ChoiceChip('time', '午后', '午后')
            this.ChoiceChip('time', '晚间', '晚间')
            this.ChoiceChip('time', '不固定', '不固定')
          }.width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('5', '学习偏好', '决定 Agent 如何安排和陪伴你')
          Text('计划方式').width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            this.ChoiceChip('style', '练习驱动', '练习驱动')
            this.ChoiceChip('style', '理解优先', '理解优先')
            this.ChoiceChip('style', '稳步推进', '稳步推进')
          }.width('100%')
          Text('陪伴方式').width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            this.ChoiceChip('support', '温和陪伴', '温和陪伴')
            this.ChoiceChip('support', '直接督促', '直接督促')
            this.ChoiceChip('support', '只在需要时提醒', '低打扰')
          }.width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Button('生成我的第一条主动建议')
          .width('100%').height(52).fontSize(16).fontWeight(FontWeight.Bold)
          .backgroundColor('#5B5FEF').borderRadius(18)
          .onClick(() => {
            this.onSaveProfile();
          })
        Text('你可以随时在“我的 → 重新设置学习画像”中修改')
          .width('100%').textAlign(TextAlign.Center).fontSize(12).fontColor('#A1A5B5')
      }
      .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 32 })
    }
    .width('100%').height('100%').backgroundColor('#F6F7FC')
  }
}
