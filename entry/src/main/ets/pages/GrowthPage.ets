import { PageHeader } from '../components/PageHeader';

@Component
export struct GrowthPageView {
  @Prop profileName: string = '';
  @Prop profileSubject: string = '';
  @Prop profileGoal: string = '';
  @Prop todayTimeText: string = '0分钟';
  @Prop completedTaskCount: number = 0;
  @Prop totalTaskCount: number = 0;
  @Prop planProgress: number = 0;
  @Prop todayFocusSessionCount: number = 0;
  @Prop quizAttemptCount: number = 0;
  @Prop quizCorrectCount: number = 0;
  @Prop isRunning: boolean = false;
  @Prop squadMessage: string = '';
  onEnterShadow: () => void = () => {};
  onSquadMessageChange: (message: string) => void = () => {};

  build() {
    Scroll() {
      Column({ space: 16 }) {
        PageHeader({ icon: '🌱', title: '成长与小队', subtitle: '学习影子 · 非打扰共学 · 校园成长服务' })
        Column({ space: 14 }) {
          Row({ space: 14 }) {
            Stack() {
              Column().width(70).height(70).backgroundColor('#D8F8EE').borderRadius(35)
              Text('✦').fontSize(34).fontColor('#35C99A')
            }.width(76).height(76)
            Column({ space: 5 }) {
              Text('你的学习影子 · 微光').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
              Text(`今日专注 ${this.todayTimeText} · 随专注时长生长`)
                .width('100%').fontSize(12).fontColor('#9397A9')
              Text(this.isRunning ? '正在发光，队友能感受到你在学习' : '开始番茄钟后，影子会进入共学空间')
                .width('100%').fontSize(12).fontColor('#35A982')
            }.layoutWeight(1)
          }.width('100%')
          Button(this.isRunning ? '进入学习影子空间' : '开始专注并进入影子空间')
            .width('100%').height(44).backgroundColor('#24213F')
            .onClick(() => {
              this.onEnterShadow();
            })
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 13 }) {
          Row() {
            Column({ space: 3 }) {
              Text(`${this.profileSubject}学习成长`).width('100%').fontSize(18).fontWeight(FontWeight.Bold)
              Text('数据来自今日任务、番茄钟和测验记录').width('100%').fontSize(12).fontColor('#9397A9')
            }.layoutWeight(1)
            Text(`${this.planProgress}%`).fontSize(12).fontColor('#A85D22').backgroundColor('#FFF1DF')
              .padding({ left: 10, right: 10, top: 7, bottom: 7 }).borderRadius(13)
          }.width('100%')
          Text(`🎯 ${this.profileGoal} · ${this.profileSubject}`).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
          Row() {
            Text(`${this.profileName} · 今日任务`).layoutWeight(1).fontSize(13)
            Text(`${this.completedTaskCount}/${this.totalTaskCount} · ${this.planProgress}%`)
              .fontSize(12).fontColor('#5B5FEF')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row() {
            Text('🍅 今日专注').layoutWeight(1).fontSize(13)
            Text(`${this.todayFocusSessionCount}轮 · ${this.todayTimeText}`).fontSize(12).fontColor('#35A982')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row() {
            Text('📝 今日测验').layoutWeight(1).fontSize(13)
            Text(this.quizAttemptCount === 0 ? '暂未测验' :
              `${this.quizCorrectCount}/${this.quizAttemptCount}次答对`).fontSize(12).fontColor('#D26B72')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row({ space: 8 }) {
            Button('鼓励队友').layoutWeight(1).height(39).fontSize(12).backgroundColor('#5B5FEF')
              .onClick(() => {
                this.onSquadMessageChange('已送出一束微光，既鼓励又不打扰');
              })
            Button('发起挑战').layoutWeight(1).height(39).fontSize(12)
              .fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .onClick(() => {
                this.onSquadMessageChange('已创建“共同专注25分钟”挑战');
              })
          }.width('100%')
          Text(this.squadMessage).width('100%').fontSize(12).fontColor('#777C90')
          Text('多人实时数据将在接入共学服务后显示；当前不使用虚构队友进度。')
            .width('100%').fontSize(11).fontColor('#A0A4B4')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 13 }) {
          Text('校园与职业助手').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Row({ space: 10 }) {
            Column({ space: 5 }) {
              Text('🏠').fontSize(24)
              Text('租房避坑').fontSize(13).fontWeight(FontWeight.Bold)
              Text('合同与押金检查').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#FFF4EA').borderRadius(15)
            Column({ space: 5 }) {
              Text('💼').fontSize(24)
              Text('职业规划').fontSize(13).fontWeight(FontWeight.Bold)
              Text('能力画像与路线').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#EEF3FF').borderRadius(15)
          }.width('100%')
          Row({ space: 10 }) {
            Column({ space: 5 }) {
              Text('🏥').fontSize(24)
              Text('医保报销').fontSize(13).fontWeight(FontWeight.Bold)
              Text('流程与材料清单').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#EAF8F3').borderRadius(15)
            Column({ space: 5 }) {
              Text('📄').fontSize(24)
              Text('合同检查').fontSize(13).fontWeight(FontWeight.Bold)
              Text('识别常见风险项').fontSize(11).fontColor('#9397A9')
            }.layoutWeight(1).padding(13).backgroundColor('#F6EEFF').borderRadius(15)
          }.width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
