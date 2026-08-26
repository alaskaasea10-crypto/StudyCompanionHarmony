import { PageHeader } from '../components/PageHeader';

@Component
export struct GrowthPageView {
  @Prop profileSubject: string = '';
  @Prop todayTimeText: string = '0分钟';
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
              Text(`${this.profileSubject}互助小队`).width('100%').fontSize(18).fontWeight(FontWeight.Bold)
              Text('4人小队 · 目标一致 · 轻度竞争').width('100%').fontSize(12).fontColor('#9397A9')
            }.layoutWeight(1)
            Text('Lv.2').fontSize(12).fontColor('#A85D22').backgroundColor('#FFF1DF')
              .padding({ left: 10, right: 10, top: 7, bottom: 7 }).borderRadius(13)
          }.width('100%')
          Text(`🎯 30天完成${this.profileSubject}复习`).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
          Row() {
            Text('你 · 队长').layoutWeight(1).fontSize(13)
            Text('70% · 已完成今日任务').fontSize(12).fontColor('#5B5FEF')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row() {
            Text('小明 · 氛围官').layoutWeight(1).fontSize(13)
            Text('55% · 正在专注').fontSize(12).fontColor('#35A982')
          }.width('100%').padding(10).backgroundColor('#F6F7FB').borderRadius(12)
          Row() {
            Text('小红 · 分享者').layoutWeight(1).fontSize(13)
            Text('40% · 还有3个任务').fontSize(12).fontColor('#D26B72')
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
