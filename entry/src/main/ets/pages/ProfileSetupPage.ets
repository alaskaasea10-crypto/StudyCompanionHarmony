@Component
export struct ProfileSetupPageView {
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
  onTextChange: (field: string, value: string) => void = () => {};
  onChoiceChange: (group: string, value: string) => void = () => {};
  onUseDemoSchedule: () => void = () => {};
  onSaveProfile: () => void = () => {};

  private choiceValue(group: string): string {
    if (group === 'grade') {
      return this.profileGrade;
    }
    if (group === 'goal') {
      return this.profileGoal;
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
    return this.profileDailyMinutes.toString();
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
        Column({ space: 7 }) {
          Text('✦ 第一次见面').width('100%').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          Text('先让学伴认识你').width('100%').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#202235')
          Text('这些信息只保存在本机，用来生成符合你真实情况的建议。以后可以在“我的”里重新设置。')
            .width('100%').fontSize(14).fontColor('#777C90').lineHeight(22)
        }.width('100%').padding({ top: 10, bottom: 4 })

        Column({ space: 14 }) {
          this.SetupSection('1', '基本信息', '称呼、年级与专业')
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
          Row() {
            Column({ space: 4 }) {
              Text(this.setupScheduleReady ? '演示课表已就绪' : '暂未导入课表')
                .width('100%').fontSize(15).fontWeight(FontWeight.Bold)
              Text(this.setupScheduleReady ? '周一至周五课程已加入时间感知' : '现在可先使用演示课表，之后再接入 OCR')
                .width('100%').fontSize(12).fontColor('#9397A9')
            }.layoutWeight(1)
            Button(this.setupScheduleReady ? '已导入' : '使用演示课表')
              .height(38).fontSize(12)
              .fontColor(this.setupScheduleReady ? '#218764' : Color.White)
              .backgroundColor(this.setupScheduleReady ? '#E5F7F0' : '#5B5FEF')
              .onClick(() => {
                this.onUseDemoSchedule();
              })
          }.width('100%').padding(14).backgroundColor('#F6F7FB').borderRadius(16)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 14 }) {
          this.SetupSection('3', '最近目标', '科目、考试日期与目标类型')
          Row({ space: 8 }) {
            this.ChoiceChip('goal', '期末复习', '期末复习')
            this.ChoiceChip('goal', '考研准备', '考研准备')
            this.ChoiceChip('goal', '能力提升', '能力提升')
          }.width('100%')
          TextInput({ placeholder: '当前最重要的科目', text: this.profileSubject })
            .width('100%').height(48).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.onTextChange('subject', value);
            })
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
            this.ChoiceChip('minutes', '30', '30分钟')
            this.ChoiceChip('minutes', '60', '60分钟')
            this.ChoiceChip('minutes', '90', '90分钟')
            this.ChoiceChip('minutes', '120', '120分钟')
          }.width('100%')
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
