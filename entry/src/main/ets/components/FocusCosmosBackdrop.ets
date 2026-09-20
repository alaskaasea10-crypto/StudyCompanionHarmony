import { FocusFieldService } from '../services/FocusFieldService';

// 静态背景只在尺寸或累计时长改变时绘制，不增加逐帧刷新。
@Component
export struct FocusCosmosBackdrop {
  @Prop immersive: boolean = false;
  @Prop @Watch('paint') collectiveMinutes: number = 0;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasWidth: number = 360;
  private canvasHeight: number = 800;
  private ready: boolean = false;

  private noise(seed: number): number {
    const n: number = Math.sin(seed * 127.1 + 74.7) * 43758.5453;
    return n - Math.floor(n);
  }

  private paintImmersiveStars(): void {
    const c: CanvasRenderingContext2D = this.context;
    const richness: number = FocusFieldService.starProfile(this.collectiveMinutes).richness;
    const count: number = Math.min(720, Math.floor(this.canvasWidth * this.canvasHeight / 1250)) *
      (0.7 + richness * 0.6);
    for (let i: number = 0; i < Math.ceil(count); i++) {
      const x: number = this.noise(i + 800) * this.canvasWidth;
      const y: number = this.noise(i + 1700) * this.canvasHeight;
      const depth: number = this.noise(i + 2900);
      // 两翼明晰，中间轻淡过渡，与主星域融合而不形成矩形边界。
      const side: number = Math.min(1, Math.abs(x - this.canvasWidth / 2) / (this.canvasHeight * 0.5));
      const alpha: number = (0.16 + depth * 0.55) * (0.25 + side * 0.75) *
        (0.7 + richness * 0.3) * Math.min(1, count - i);
      const tint: string = i % 17 === 0 ? '235,215,181' : '201,217,250';
      c.beginPath(); c.arc(x, y, depth > 0.96 ? 1.15 : 0.3 + depth * 0.55, 0, Math.PI * 2);
      c.fillStyle = `rgba(${tint},${alpha})`; c.fill();
      if (depth > 0.94) {
        const halo: CanvasGradient = c.createRadialGradient(x, y, 0, x, y, 7);
        halo.addColorStop(0, `rgba(${tint},${alpha * 0.3})`);
        halo.addColorStop(1, `rgba(${tint},0)`);
        c.fillStyle = halo; c.fillRect(x - 7, y - 7, 14, 14);
      }
    }
  }

  private paint(): void {
    if (!this.ready) { return; }
    const c: CanvasRenderingContext2D = this.context;
    c.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    const nebula: CanvasGradient = c.createRadialGradient(this.canvasWidth * 0.1, this.canvasHeight * 0.18,
      0, this.canvasWidth * 0.1, this.canvasHeight * 0.18, this.canvasWidth * 0.85);
    nebula.addColorStop(0, 'rgba(92,76,144,0.17)');
    nebula.addColorStop(1, 'rgba(26,29,51,0)');
    c.fillStyle = nebula; c.fillRect(0, 0, this.canvasWidth, this.canvasHeight);
    const blue: CanvasGradient = c.createRadialGradient(this.canvasWidth, this.canvasHeight * 0.74,
      0, this.canvasWidth, this.canvasHeight * 0.74, this.canvasWidth * 0.8);
    blue.addColorStop(0, 'rgba(56,94,135,0.14)');
    blue.addColorStop(1, 'rgba(20,27,44,0)');
    c.fillStyle = blue; c.fillRect(0, 0, this.canvasWidth, this.canvasHeight);
    if (this.immersive) { this.paintImmersiveStars(); return; }
    for (let i: number = 0; i < 65; i++) {
      const x: number = ((i * 137.51 + 17) % 359) / 360 * this.canvasWidth;
      const y: number = ((i * 213.73 + 41) % 797) / 800 * this.canvasHeight;
      c.beginPath(); c.arc(x, y, i % 9 === 0 ? 0.9 : 0.45, 0, Math.PI * 2);
      c.fillStyle = i % 9 === 0 ? 'rgba(213,216,240,0.28)' : 'rgba(175,190,224,0.15)'; c.fill();
    }
  }

  build() {
    Canvas(this.context).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      .onReady(() => { this.ready = true; this.paint(); })
      .onAreaChange((_previous: Area, area: Area) => {
        this.canvasWidth = Number(area.width); this.canvasHeight = Number(area.height); this.paint();
      })
  }
}
