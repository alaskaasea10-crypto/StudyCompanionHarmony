import { SquadMember } from '../models/StudyModels';
import { FocusFieldService } from '../services/FocusFieldService';

interface FieldMeteor {
  born: number;
  x: number;
  y: number;
  travel: number;
  slope: number;
  duration: number;
  tail: number;
  warm: boolean;
}

// 360vp 设计坐标；画布与公转状态局限在光场组件，不刷新页面计时器和表单。
@Component
export struct OrbitField {
  @Prop members: SquadMember[] = [];
  @Prop isRunning: boolean = false;
  @Prop collectiveMinutes: number = 0;
  @Prop selfProgress: number = 0;
  @Prop immersive: boolean = false;
  @State private fieldWidth: number = 320;
  @State private orbitPhase: number = 0;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private motionTimer: number = -1;
  private time: number = 0;
  private ready: boolean = false;
  private visible: boolean = false;
  private lastFrameAt: number = 0;
  private richness: number = -1;
  private meteors: FieldMeteor[] = [];
  private nextMeteorAt: number = 1.5;
  private meteorSerial: number = 0;

  aboutToDisappear(): void { this.stopMotion(); }

  private startMotion(): void {
    if (!this.ready || !this.visible || this.motionTimer >= 0) { return; }
    this.lastFrameAt = Date.now();
    this.draw();
    this.motionTimer = setInterval(() => {
      const now: number = Date.now();
      const delta: number = Math.min(0.08, (now - this.lastFrameAt) / 1000);
      this.time += delta;
      this.orbitPhase = (this.time * 360 / 55) % 360;
      this.lastFrameAt = now;
      this.draw();
    }, 50);
  }

  private stopMotion(): void {
    if (this.motionTimer >= 0) {
      clearInterval(this.motionTimer);
      this.motionTimer = -1;
    }
  }

  private companions(): SquadMember[] {
    return this.members.filter((member: SquadMember) => !member.isSelf).slice(0, 3);
  }

  private noise(seed: number): number {
    const n: number = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
    return n - Math.floor(n);
  }

  private dot(x: number, y: number, radius: number, color: string): void {
    const c: CanvasRenderingContext2D = this.context;
    c.beginPath(); c.arc(x, y, radius, 0, Math.PI * 2);
    c.fillStyle = color; c.fill();
  }

  private glow(x: number, y: number, rx: number, ry: number, color: string): void {
    const c: CanvasRenderingContext2D = this.context;
    c.save(); c.translate(x, y); c.scale(1, ry / rx);
    const light: CanvasGradient = c.createRadialGradient(0, 0, 0, 0, 0, rx);
    light.addColorStop(0, color); light.addColorStop(1, 'rgba(20,16,50,0)');
    c.beginPath(); c.arc(0, 0, rx, 0, Math.PI * 2);
    c.fillStyle = light; c.fill(); c.restore();
  }

  private ringPoint(angle: number, radius: number = 130): number[] {
    const x: number = Math.cos(angle) * radius;
    const y: number = Math.sin(angle) * radius * 0.39;
    return [180 + x * 0.94 + y * 0.342, 163 - x * 0.342 + y * 0.94];
  }

  private companionPoint(index: number): number[] {
    // 同方向、同周期沿椭圆公转，每 55 秒一圈；角度跨零时坐标连续。
    const angle: number = [3.45, 0.3, 1.7][index % 3] + this.orbitPhase * Math.PI / 180;
    return this.ringPoint(angle, index === 2 ? 146 : 130);
  }

  private companionLabelPoint(index: number): number[] {
    const point: number[] = this.companionPoint(index);
    const dx: number = point[0] - 180;
    const dy: number = point[1] - 163;
    const distance: number = Math.sqrt(dx * dx + dy * dy);
    // 标注放在小星球朝外的一侧，连续跟随径向位置，绝不翻转文字或跨中线跳边。
    const labelX: number = point[0] * this.fieldWidth / 360 + dx / distance * 39;
    const left: number = this.immersive ? labelX - 26 :
      Math.max(4, Math.min(this.fieldWidth - 56, labelX - 26));
    // 窄屏边缘把被收束的水平距离平滑移到纵向，不让文字压到自己的小星球。
    const edgeOffset: number = Math.abs(left + 26 - labelX) * dy / Math.sqrt(dy * dy + 900) * 1.2;
    const labelY: number = point[1] * this.fieldWidth / 360 + dy / distance * 33 + edgeOffset;
    return [left, labelY - 12];
  }

  private drawStars(): void {
    const c: CanvasRenderingContext2D = this.context;
    const count: number = 76 + this.richness * 224;
    const brightness: number = 0.58 + this.richness * 0.42;
    for (let i: number = 0; i < Math.ceil(count); i++) {
      const depth: number = this.noise(i + 420);
      // 远星均匀分散，部分新星自然聚成疏密有别的星尘带。
      const x: number = 14 + this.noise(i + 1) * 332;
      const y: number = i > 75 && i % 3 === 0 ?
        218 - x * 0.36 + (this.noise(i + 260) - 0.5) * 62 :
        30 + this.noise(i + 260) * 254;
      const separation: number = Math.sqrt((x - 180) * (x - 180) + (y - 163) * (y - 163));
      const space: number = separation < 65 ? 0.35 : 1;
      const arrival: number = Math.min(1, Math.max(0, count - i));
      const twinkle: number = 0.84 + Math.sin(this.time * (0.35 + depth * 0.45) + i * 1.9) * 0.16;
      const alpha: number = (0.2 + depth * 0.67) * brightness * twinkle * arrival * space;
      const radius: number = depth > 0.94 ? 1.15 : 0.28 + depth * 0.48;
      const warm: boolean = i % 13 === 0;
      this.dot(x, y, radius, warm ? `rgba(237,221,194,${alpha})` : `rgba(214,225,255,${alpha})`);
      if (depth > 0.92 && space === 1) {
        this.glow(x, y, 5 + depth * 3, 5 + depth * 3,
          warm ? `rgba(227,201,161,${alpha * 0.25})` : `rgba(152,181,243,${alpha * 0.29})`);
      }
      // 极少数近星拥有柔细衍射光芒，其余只保留点光，避免满屏符号。
      if (depth > 0.98 && i % 2 === 0 && space === 1) {
        const ray: CanvasGradient = c.createLinearGradient(x - 5, y, x + 5, y);
        ray.addColorStop(0, 'rgba(226,234,255,0)');
        ray.addColorStop(0.5, `rgba(226,234,255,${alpha * 0.55})`);
        ray.addColorStop(1, 'rgba(226,234,255,0)');
        c.strokeStyle = ray; c.lineWidth = 0.45;
        c.beginPath(); c.moveTo(x - 5, y); c.lineTo(x + 5, y); c.stroke();
      }
    }
  }

  private drawAtmosphere(): void {
    // 冷银与紫蓝只作散射底光，清晰的远近感交给真实绘制的星点。
    this.glow(127, 142, 144, 103, 'rgba(78,68,140,0.20)');
    this.glow(248, 175, 117, 86, 'rgba(40,74,120,0.19)');
    this.glow(184, 156, 84, 76, `rgba(130,133,185,${0.08 + this.richness * 0.06})`);
    this.glow(246, 139, 65, 41, `rgba(202,187,162,${0.035 + this.richness * 0.04})`);
  }

  private drawRing(front: boolean): void {
    const c: CanvasRenderingContext2D = this.context;
    c.save(); c.translate(180, 163); c.rotate(-0.349);
    const begin: number = front ? 0 : Math.PI;
    const end: number = front ? Math.PI : Math.PI * 2;
    for (let j: number = 0; j < 6; j++) {
      c.beginPath(); c.ellipse(0, 0, 120 + j * 3.2, 46.8 + j * 1.25, 0, begin, end);
      c.strokeStyle = `rgba(181,166,227,${front ? 0.045 + j * 0.013 : 0.025 + j * 0.006})`;
      c.lineWidth = j === 3 ? 1 : 0.45; c.stroke();
    }
    c.beginPath(); c.ellipse(0, 0, 151, 59, 0, begin, end);
    c.strokeStyle = 'rgba(126,151,203,0.12)'; c.lineWidth = 0.5; c.stroke(); c.restore();
    for (let i: number = 0; i < 320; i++) {
      const angle: number = (this.noise(i + 900) * Math.PI * 2 + this.time * 0.018) % (Math.PI * 2);
      if ((angle < Math.PI) !== front) { continue; }
      const p: number[] = this.ringPoint(angle, 121 + this.noise(i + 1200) * 16);
      const bright: number = this.noise(i + 1500);
      this.dot(p[0], p[1], 0.3 + bright * 0.6,
        `rgba(211,198,255,${(front ? 0.2 : 0.1) + bright * 0.4})`);
    }
    const angle: number = (this.time * 0.12 + 0.4) % (Math.PI * 2);
    if ((angle < Math.PI) === front) {
      for (let k: number = 0; k < 24; k++) {
        const p: number[] = this.ringPoint(angle - k * 0.007);
        this.dot(p[0], p[1], 0.8, `rgba(224,216,255,${(1 - k / 24) * 0.7})`);
      }
    }
  }

  private drawPlanet(): void {
    const c: CanvasRenderingContext2D = this.context;
    this.glow(180, 161, 70, 70, 'rgba(146,131,219,0.24)');
    this.glow(161, 141, 49, 49, 'rgba(168,176,252,0.13)');
    const sphere: CanvasGradient = c.createRadialGradient(160, 137, 2, 193, 180, 70);
    sphere.addColorStop(0, '#F0E7FF'); sphere.addColorStop(0.19, '#CBC6F1');
    sphere.addColorStop(0.43, '#8885BD'); sphere.addColorStop(0.7, '#3B3B67');
    sphere.addColorStop(1, '#0B1022');
    c.beginPath(); c.arc(180, 163, 43, 0, Math.PI * 2); c.fillStyle = sphere; c.fill();
    c.save(); c.clip();
    for (let i: number = 0; i < 21; i++) {
      const y: number = 119 + i * 4.8;
      c.beginPath(); c.moveTo(128, y); c.bezierCurveTo(161, y + 16, 183, y - 13, 231, y + 10);
      c.strokeStyle = i % 3 === 0 ? 'rgba(229,212,255,0.09)' : 'rgba(34,39,87,0.07)';
      c.lineWidth = 1 + this.noise(i + 55) * 2.5; c.stroke();
    }
    const shade: CanvasGradient = c.createLinearGradient(151, 136, 210, 190);
    shade.addColorStop(0, 'rgba(7,12,29,0)'); shade.addColorStop(0.54, 'rgba(7,12,29,0.05)');
    shade.addColorStop(1, 'rgba(7,12,29,0.88)');
    c.fillStyle = shade; c.fillRect(134, 117, 92, 92); c.restore();
    c.beginPath(); c.arc(180, 163, 43.4, Math.PI * 0.94, Math.PI * 1.88);
    c.strokeStyle = 'rgba(220,217,255,0.68)'; c.lineWidth = 0.8; c.stroke();
    c.beginPath(); c.arc(180, 163, 48, -Math.PI / 2,
      -Math.PI / 2 + Math.PI * 2 * FocusFieldService.progress(this.selfProgress) / 100);
    c.strokeStyle = 'rgba(222,208,255,0.72)'; c.lineWidth = 1.2; c.stroke();
  }

  private drawMeteor(): void {
    const c: CanvasRenderingContext2D = this.context;
    this.meteors = this.meteors.filter((meteor: FieldMeteor) => this.time - meteor.born < meteor.duration);
    if (this.time >= this.nextMeteorAt && this.meteors.length < 3) {
      const seed: number = ++this.meteorSerial;
      this.meteors.push({
        born: this.time,
        x: 12 + this.noise(seed + 3100) * 100,
        y: 36 + this.noise(seed + 3200) * 77,
        travel: 186 + this.noise(seed + 3300) * 48,
        slope: 0.23 + this.noise(seed + 3400) * 0.15,
        duration: 2.7 + this.noise(seed + 3500) * 1.3,
        tail: 53 + this.noise(seed + 3600) * 29,
        warm: seed % 5 === 0
      });
      // 改变的是下一颗的出现间隔，不会让正在飞行的流星突然跳位。
      this.nextMeteorAt = this.time + (24 - this.richness * 20) * (0.8 + this.noise(seed + 3700) * 0.4);
    }
    for (let i: number = 0; i < this.meteors.length; i++) {
      const meteor: FieldMeteor = this.meteors[i];
      const p: number = (this.time - meteor.born) / meteor.duration;
      const visibility: number = Math.sin(p * Math.PI) * (0.65 + this.richness * 0.25);
      const x: number = meteor.x + p * meteor.travel;
      const y: number = meteor.y + p * meteor.travel * meteor.slope;
      const tailX: number = x - meteor.tail;
      const tailY: number = y - meteor.tail * meteor.slope;
      const tint: string = meteor.warm ? '246,226,196' : '201,219,255';
      const tail: CanvasGradient = c.createLinearGradient(tailX, tailY, x, y);
      tail.addColorStop(0, `rgba(${tint},0)`);
      tail.addColorStop(0.45, `rgba(${tint},${visibility * 0.09})`);
      tail.addColorStop(0.85, `rgba(${tint},${visibility * 0.45})`);
      tail.addColorStop(1, `rgba(249,247,255,${visibility})`);
      c.fillStyle = tail; c.beginPath(); c.moveTo(tailX, tailY);
      c.lineTo(x, y - 0.8); c.lineTo(x + 1.2, y); c.lineTo(x, y + 0.8);
      c.closePath(); c.fill();
      this.glow(x, y, 7, 7, `rgba(${tint},${visibility * 0.32})`);
      this.dot(x, y, 1.05, `rgba(253,250,255,${visibility})`);
    }
  }

  private draw(): void {
    if (!this.ready || this.fieldWidth <= 0) { return; }
    const target: number = FocusFieldService.starProfile(this.collectiveMinutes).richness;
    this.richness = this.richness < 0 ? target : this.richness + (target - this.richness) * 0.035;
    const c: CanvasRenderingContext2D = this.context;
    const scale: number = this.fieldWidth / 360;
    c.clearRect(0, 0, this.fieldWidth, this.fieldWidth);
    c.save(); c.scale(scale, scale);
    this.drawAtmosphere(); this.drawStars(); this.drawMeteor();
    this.drawRing(false);
    c.save(); c.translate(180, 163); c.rotate(this.time * 0.018); c.translate(-180, -163);
    this.drawPlanet(); c.restore(); this.drawRing(true);
    c.restore();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context).width('100%').height(this.fieldWidth)
        .onReady(() => { this.ready = true; this.draw(); this.startMotion(); })
      if (!this.immersive) {
      Row({ space: 6 }) {
        Text('✦').fontSize(10).fontColor('#D5C4F2')
        Text('同频星域').fontSize(10).letterSpacing(2).fontColor('#B8B5D2')
      }.position({ x: 16, y: 12 })
      Text('LIVE ORBIT').fontSize(8).letterSpacing(1.6).fontColor('#747F9E')
        .position({ x: this.fieldWidth - 88, y: 14 })
      }
      ForEach(this.companions(), (member: SquadMember, index: number) => {
          Stack() {
            Progress({ value: FocusFieldService.memberProgress(member), total: 100, type: ProgressType.Ring })
              .width(30).height(30).color(index === 1 ? '#9AC7E9' : '#CBB9F2')
              .backgroundColor('#283046').style({ strokeWidth: 1.5 })
            Column().width(17).height(17).borderRadius(9)
              .radialGradient({ center: ['28%', '22%'], radius: 19,
                colors: [[index === 1 ? '#DEEFFC' : '#EDE2FF', 0],
                  [index === 1 ? '#7FA3C7' : '#A598CF', 0.4], ['#25304C', 1]] })
              .shadow({ radius: 12, color: '#605970A8', offsetX: 0, offsetY: 0 })
          }.width(32).height(32)
            .position({ x: this.companionPoint(index)[0] * this.fieldWidth / 360 - 16,
              y: this.companionPoint(index)[1] * this.fieldWidth / 360 - 16 })
          Column({ space: 2 }) {
            Text(member.name).fontSize(9).lineHeight(12).fontWeight(FontWeight.Medium)
              .fontColor('#CDCDE1').maxLines(1)
            Text(member.status).fontSize(7).lineHeight(10).fontWeight(FontWeight.Regular)
              .fontColor('#8E9BB7').maxLines(1)
          }.width(52).height(24)
            .position({ x: this.companionLabelPoint(index)[0], y: this.companionLabelPoint(index)[1] })
      }, (member: SquadMember) => member.id)
      if (!this.immersive) {
      Column({ space: 5 }) {
        Text(this.isRunning ? '我的星球 · 正在发光' : '我的星球 · 等待启程')
          .fontSize(10).letterSpacing(1).fontColor('#D0C7E3')
      }.width('100%').position({ x: 0, y: this.fieldWidth * (this.companions().length >= 3 ? 0.90 : 0.83) })
      }
    }.width('100%').height(this.fieldWidth * (this.companions().length >= 3 ? 1.0 : 0.90))
      .clip(!this.immersive).borderRadius(this.immersive ? 0 : 24)
      .linearGradient({ angle: 155, colors: [[this.immersive ? '#00141827' : '#141827', 0],
        [this.immersive ? '#00101423' : '#101423', 0.48], [this.immersive ? '#00171A28' : '#171A28', 1]] })
      .border({ width: this.immersive ? 0 : 0.6, color: '#303444' })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const width: number = Number(newArea.width);
        if (width > 0 && Math.abs(width - this.fieldWidth) > 1) {
          this.fieldWidth = width; this.draw();
        }
      })
      .onVisibleAreaChange([0], (_isVisible: boolean, ratio: number) => {
        this.visible = ratio > 0;
        if (this.visible) { this.startMotion(); } else { this.stopMotion(); }
      })
  }
}
