// 动画只刷新这枚小图标；离屏和组件销毁时停止计时。
@Component
export struct StudyPlanet {
  @Prop stage: number = 1;
  @Prop planetSize: number = 64;
  @Prop wink: boolean = false;
  @State private phase: number = 0;
  private timer: number = -1;

  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }

  aboutToDisappear(): void { this.stop(); }

  private start(): void {
    if (this.timer >= 0) { return; }
    this.timer = setInterval(() => { this.phase = (this.phase + 0.08) % (Math.PI * 2); }, 80);
  }

  build() {
    Stack() {
      Circle().width(this.planetSize * 0.8125).height(this.planetSize * 0.8125).fill(this.stage >= 3 ? '#E6DBFF' : '#F0ECFF')
        .opacity(0.4 + Math.sin(this.phase) * 0.12)
        .scale({ x: 1 + Math.sin(this.phase) * 0.04, y: 1 + Math.sin(this.phase) * 0.04 })
      Image(this.wink ? $r('app.media.study_planet_wink') : $r('app.media.study_planet'))
        .width(this.planetSize).height(this.planetSize * 0.90625).objectFit(ImageFit.Contain)
        .translate({ y: Math.sin(this.phase) * this.planetSize / 32 })
      if (this.stage >= 2) {
        Text('✧').fontSize(this.planetSize * 0.1875).fontColor('#C0A1EC').position({ x: this.planetSize / 32, y: this.planetSize * 0.6875 })
          .opacity(0.65 + Math.sin(this.phase) * 0.2)
      }
      if (this.stage >= 3) {
        Text('✦').fontSize(this.planetSize * 0.15625).fontColor('#EAC071').position({ x: this.planetSize * 0.8125, y: this.planetSize / 16 })
          .opacity(0.7 - Math.sin(this.phase) * 0.2)
      }
    }.width(this.planetSize).height(this.planetSize)
      .accessibilityText('星球，' + (this.stage === 3 ? '星光形态' : this.stage === 2 ? '微光形态' : '初生形态'))
      .onVisibleAreaChange([0, 1], (visible: boolean) => {
        if (visible) { this.start(); } else { this.stop(); }
      })
  }
}
