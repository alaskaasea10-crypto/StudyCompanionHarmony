import { PageHeader } from '../components/PageHeader';

@Component
export struct ProfilePageView {
  @Prop profileName: string = '';
  @Prop profileGrade: string = '';
  @Prop profileMajor: string = '';
  @Prop profileGoal: string = '';
  @Prop profileLearningStyle: string = '';
  @Prop profileDailyMinutes: number = 0;
  @Prop profilePreferredTime: string = '';
  @Prop profileSubject: string = '';
  @Prop profileExamDate: string = '';
  @Prop examDays: number = 0;
  @Prop energyState: string = '';
  @Prop todayTimeText: string = '0分钟';
  @Prop completedTaskCount: number = 0;
  @Prop totalTaskCount: number = 0;
  @Prop planProgress: number = 0;
  @Prop quizAttemptCount: number = 0;
  @Prop quizCorrectCount: number = 0;
  onEnergyChange: (value: string) => void = () => {};
  onResetProfile: () => void = () => {};

  @Builder
  EnergyButton(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.energyState === title ? Color.White : '#5F6478')
      .backgroundColor(this.energyState === title ? '#5B5FEF' : '#F0F1F6')
      .padding({ left: 14, right: 14, top: 9, bottom: 9 }).borderRadius(16)
      .onClick(() => {
        this.onEnergyChange(title);
      })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({ icon: '👤', title: '我的', subtitle: '学习画像 · 数据与隐私' })
        Row({ space: 14 }) {
          Text(this.profileName.length > 0 ? this.profileName.substring(0, 1) : '学')
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#5B5FEF').borderRadius(29)
          Column({ space: 5 }) {
            Text(this.profileName).fontSize(20).fontWeight(FontWeight.Bold)
            Text(`${this.profileGrade} · ${this.profileMajor}`).fontSize(13).fontColor('#8B90A5')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 15 }) {
          Text('学习画像').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Row() {
            Text('当前目标').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(this.profileGoal).fontSize(14).fontWeight(FontWeight.Medium)
          }.width('100%')
          Row() {
            Text('学习方式').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(this.profileLearningStyle).fontSize(14).fontWeight(FontWeight.Medium)
          }.width('100%')
          Row() {
            Text('每日可用时间').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(`${this.profileDailyMinutes}分钟 · ${this.profilePreferredTime}`)
              .fontSize(14).fontWeight(FontWeight.Medium)
          }.width('100%')
          Row() {
            Text('当前科目').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(this.profileSubject).fontSize(14).fontWeight(FontWeight.Medium)
          }.width('100%')
          Row() {
            Text('考试日期').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text(`${this.profileExamDate} · ${this.examDays}天`).fontSize(14).fontWeight(FontWeight.Medium)
          }.width('100%')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 13 }) {
          Text('学习数据').width('100%').fontSize(17).fontWeight(FontWeight.Bold)
          Row({ space: 10 }) {
            Column({ space: 5 }) {
              Text(this.todayTimeText).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
              Text('今日专注').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#F4F3FF').borderRadius(14)
            Column({ space: 5 }) {
              Text(`${this.completedTaskCount}/${this.totalTaskCount}`).fontSize(19)
                .fontWeight(FontWeight.Bold).fontColor('#22A879')
              Text(`任务完成 · ${this.planProgress}%`).fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#ECF9F4').borderRadius(14)
            Column({ space: 5 }) {
              Text(`${this.quizCorrectCount}/${this.quizAttemptCount}`).fontSize(19)
                .fontWeight(FontWeight.Bold).fontColor('#D06A48')
              Text('今日测验答对').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#FFF3EC').borderRadius(14)
          }.width('100%')
          Text('以上数据由任务、番茄钟和测验结果实时汇总，并保存在本机。')
            .width('100%').fontSize(11).fontColor('#9397A9')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 13 }) {
          Text('今天的状态').width('100%').fontSize(17).fontWeight(FontWeight.Bold)
          Row({ space: 9 }) {
            this.EnergyButton('状态不错')
            this.EnergyButton('一般')
            this.EnergyButton('有点累')
          }.width('100%')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Button('重新设置学习画像')
          .width('100%').height(46).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
          .onClick(() => {
            this.onResetProfile();
          })
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
