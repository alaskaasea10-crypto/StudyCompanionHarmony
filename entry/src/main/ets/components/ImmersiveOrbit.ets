import { SquadMember } from '../models/StudyModels';
import { OrbitField } from './OrbitField';
import { FocusCosmosBackdrop } from './FocusCosmosBackdrop';

@Component
export struct ImmersiveOrbit {
  @Prop members: SquadMember[] = [];
  @Prop isRunning: boolean = false;
  @Prop remainingSeconds: number = 0;
  @Prop collectiveMinutes: number = 0;
  @Prop selfProgress: number = 0;
  onExit: () => void = () => {};
  @State private sceneSize: number = 400;

  private countdownText(): string {
    const seconds: number = Number.isFinite(this.remainingSeconds) ? Math.max(0, Math.floor(this.remainingSeconds)) : 0;
    return `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
  }

  build() {
    Stack() {
      FocusCosmosBackdrop({ immersive: true, collectiveMinutes: this.collectiveMinutes })
      Column() {
        Stack() {
          OrbitField({ members: this.members, isRunning: this.isRunning,
            collectiveMinutes: this.collectiveMinutes, selfProgress: this.selfProgress, immersive: true })
            .width(this.sceneSize)
        }.width('100%').layoutWeight(1)
        Column({ space: 3 }) {
          Text(this.countdownText()).fontSize(26).fontWeight(FontWeight.Medium)
            .fontFamily('monospace').letterSpacing(3).fontColor('#DAD8E9').lineHeight(32)
          if (!this.isRunning) {
            Text(this.remainingSeconds > 0 ? '已暂停' : '已结束')
              .fontSize(9).fontColor('#8E9BB7').lineHeight(12)
          }
        }.width('100%').height(48).margin({ bottom: 16 }).hitTestBehavior(HitTestMode.None)
      }.width('100%').height('100%')
    }.width('100%').height('100%').backgroundColor('#0C1020')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onAreaChange((_old: Area, area: Area) => {
        this.sceneSize = Math.min(Number(area.width), Math.max(120, Number(area.height) - 64) * 1.08);
      })
      .gesture(TapGesture({ count: 2 }).onAction(() => { this.onExit(); }))
  }
}
