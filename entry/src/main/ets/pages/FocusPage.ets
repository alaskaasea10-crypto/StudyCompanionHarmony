@Component
export struct FocusPageView {
  @Prop currentTaskTitle: string = '';
  @Prop currentTaskCompleted: boolean = false;
  @Prop remainingSeconds: number = 0;
  @Prop isRunning: boolean = false;
  @Prop shadowPulse: number = 1;
  @Prop todayTimeText: string = '0分钟';
  onPause: () => void = () => {};
  onContinue: () => void = () => {};
  onRestart: () => void = () => {};
  onReset: () => void = () => {};
  onFinish: () => void = () => {};

  private formatTime(seconds: number): string {
    const minute: number = Math.floor(seconds / 60);
    const second: number = seconds % 60;
    return `${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}`;
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 5 }) {
          Text('正在做').fontSize(13).fontColor('#B9B6DA')
          Text(this.currentTaskTitle)
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White).textAlign(TextAlign.Center)
        }
        .width('100%')
        Stack() {
          Column()
            .width(230).height(230).borderRadius(115).backgroundColor('#37336C').opacity(0.6)
            .scale({ x: this.shadowPulse, y: this.shadowPulse })
          Column()
            .width(180).height(180).borderRadius(90).backgroundColor('#625AF5')
            .opacity(this.isRunning ? 0.82 : 0.48)
          Column({ space: 7 }) {
            Text(this.formatTime(this.remainingSeconds))
              .fontSize(45).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text(this.isRunning ? '学习影子正在生长' :
              (this.remainingSeconds <= 0 ? '本轮专注已完成' : '本轮专注已暂停'))
              .fontSize(13).fontColor('#D8D6F0')
          }
        }
        .width('100%').height(250)
        Row({ space: 10 }) {
          Button(this.isRunning ? '暂停' : (this.remainingSeconds <= 0 ? '再次专注' : '继续'))
            .layoutWeight(1).height(46).backgroundColor('#625AF5')
            .onClick(() => {
              if (this.isRunning) {
                this.onPause();
              } else if (this.remainingSeconds <= 0) {
                this.onRestart();
              } else {
                this.onContinue();
              }
            })
          Button('重置')
            .layoutWeight(1).height(46).backgroundColor('#343154')
            .onClick(() => {
              this.onReset();
            })
        }
        .width('100%')
        Button(this.currentTaskCompleted ? '✓ 本轮任务已完成' : '完成本轮专注')
          .width('100%').height(46).fontColor('#24213F')
          .backgroundColor(this.currentTaskCompleted ? '#CAC7E8' : '#E5E2FF')
          .enabled(!this.currentTaskCompleted)
          .onClick(() => {
            this.onFinish();
          })
        Row() {
          Column({ space: 5 }) {
            Text('今日累计').fontSize(12).fontColor('#AAA6CB')
            Text(this.todayTimeText).fontSize(19).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
          Column({ space: 5 }) {
            Text('共同专注').fontSize(12).fontColor('#AAA6CB')
            Text('3个学习影子').fontSize(19).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
        }
        .width('100%').padding(18).backgroundColor('#282548').borderRadius(18)
      }
      .width('100%').padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .layoutWeight(1).backgroundColor('#17152F')
  }
}
