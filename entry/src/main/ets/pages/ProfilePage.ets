import { PageHeader } from '../components/PageHeader';
import { UserAvatar } from '../components/UserAvatar';

@Component
export struct ProfilePageView {
  @Prop profileAvatarUri: string = '';
  @Prop avatarStatus: string = '';
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
  @Prop notificationEnabled: boolean = false;
  @Prop notificationClassEnabled: boolean = true;
  @Prop notificationReviewEnabled: boolean = true;
  @Prop notificationTaskEnabled: boolean = true;
  @Prop notificationQuietHoursEnabled: boolean = true;
  @Prop notificationQuietStart: string = '22:30';
  @Prop notificationQuietEnd: string = '07:30';
  @Prop notificationStatus: string = '';
  onEnergyChange: (value: string) => void = () => {};
  onNotificationEnabledChange: (enabled: boolean) => void = () => {};
  onNotificationOptionChange: (option: string, enabled: boolean) => void = () => {};
  onSendTestNotification: () => void = () => {};
  onResetProfile: () => void = () => {};
  onSelectAvatar: () => void = () => {};

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

  @Builder
  ReminderToggle(title: string, detail: string, option: string, enabled: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#282A3C')
        Text(detail).fontSize(11).fontColor('#9296A8')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor('#5B5FEF')
        .onChange((isOn: boolean) => {
          this.onNotificationOptionChange(option, isOn);
        })
    }.width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({ icon: '👤', title: '我的', subtitle: '学习画像 · 数据与隐私' })
        Row({ space: 14 }) {
          UserAvatar({
            avatarUri: this.profileAvatarUri,
            profileName: this.profileName,
            avatarSize: 64
          })
          Column({ space: 5 }) {
            Text(this.profileName).fontSize(20).fontWeight(FontWeight.Bold)
            Text(`${this.profileGrade} · ${this.profileMajor}`).fontSize(13).fontColor('#8B90A5')
            Button(this.profileAvatarUri.length > 0 ? '更换头像' : '设置头像')
              .height(32).fontSize(12).fontColor('#5B5FEF')
              .backgroundColor('#F0EFFF').borderRadius(11)
              .onClick(() => {
                this.onSelectAvatar();
              })
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        if (this.avatarStatus.length > 0) {
          Text(this.avatarStatus).width('100%').fontSize(11).fontColor('#8B90A5')
            .padding({ left: 4, right: 4 })
        }
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
          }.width('100%')
          Text('以上数据由真实专注记录和任务完成状态实时汇总，并保存在本机。')
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
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Row({ space: 7 }) {
                Text('✦').fontSize(14).fontColor('#5B5FEF')
                Text('主动服务通知').fontSize(17).fontWeight(FontWeight.Bold)
                Text('HarmonyOS').fontSize(10).fontColor('#5B5FEF')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor('#ECEBFF').borderRadius(10)
              }
              Text('课表、任务和学习状态共同决定是否提醒')
                .fontSize(11).fontColor('#9296A8')
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
            Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
              .selectedColor('#5B5FEF')
              .onChange((isOn: boolean) => {
                this.onNotificationEnabledChange(isOn);
              })
          }.width('100%')
          if (this.notificationEnabled) {
            Divider().color('#ECEEF4')
            this.ReminderToggle('课前提醒', '课程开始前30分钟内优先提醒', 'class',
              this.notificationClassEnabled)
            this.ReminderToggle('课后复习', '下课后两小时内安排短复习', 'review',
              this.notificationReviewEnabled)
            this.ReminderToggle('任务督促', '从未完成任务中推荐下一步', 'task',
              this.notificationTaskEnabled)
            this.ReminderToggle('静默时段', `${this.notificationQuietStart}—${this.notificationQuietEnd} 不打扰`,
              'quiet', this.notificationQuietHoursEnabled)
            Button('发送测试通知')
              .width('100%').height(42).fontSize(14).fontColor('#5B5FEF')
              .backgroundColor('#F0EFFF').borderRadius(14)
              .onClick(() => {
                this.onSendTestNotification();
              })
          }
          Text(this.notificationStatus)
            .width('100%').fontSize(11).fontColor(this.notificationEnabled ? '#218764' : '#9296A8')
            .lineHeight(17)
          Text('当前版本在应用切换到后台时进行一次智能判断；系统级定时提醒将在开放能力获批后启用。')
            .width('100%').fontSize(10).fontColor('#A0A4B5').lineHeight(16)
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
