import { AgentConversationMessage, AgentGeneratedTask } from '../models/AgentModels';
import { StudyPlanet } from './StudyPlanet';

@Component
export struct FloatingAgent {
  @Prop open: boolean = false;
  @Prop mode: string = 'planning';
  @Prop input: string = '';
  @Prop messages: AgentConversationMessage[] = [];
  @Prop busy: boolean = false;
  @Prop error: string = '';
  @Prop planReady: boolean = false;
  @Prop planSummary: string = '';
  @Prop planTasks: AgentGeneratedTask[] = [];
  @Prop acceptedMessage: string = '';
  @Prop planSource: string = '';
  @Prop supportSource: string = '';
  @Prop planetStage: number = 1;
  onToggle: () => void = () => {};
  onClose: () => void = () => {};
  onModeChange: (mode: string) => void = () => {};
  onInputChange: (value: string) => void = () => {};
  onSend: () => void = () => {};
  onAcceptPlan: () => void = () => {};
  onViewTasks: () => void = () => {};
  @State private areaWidth: number = 360;
  @State private areaHeight: number = 800;
  @State private planetX: number = -1;
  @State private planetY: number = -1;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private dragged: boolean = false;

  private visibleMessages(): AgentConversationMessage[] {
    return this.messages.filter((message: AgentConversationMessage) => message.mode === this.mode);
  }

  private clampPlanet(): void {
    if (this.planetX < 0 || this.planetY < 0) {
      this.planetX = Math.max(8, this.areaWidth - 72);
      this.planetY = Math.max(20, this.areaHeight - 142);
      return;
    }
    this.planetX = Math.max(8, Math.min(this.areaWidth - 64, this.planetX));
    this.planetY = Math.max(16, Math.min(this.areaHeight - 120, this.planetY));
  }

  @Builder
  MessageBubble(message: AgentConversationMessage) {
    Row() {
      if (message.role === 'user') { Blank() }
      Text(message.text).fontSize(13).lineHeight(20)
        .fontColor(message.role === 'user' ? Color.White : '#3D4055')
        .backgroundColor(message.role === 'user' ? '#6661CF' : '#F4F3FA')
        .padding({ left: 12, right: 12, top: 9, bottom: 9 }).borderRadius(15)
        .constraintSize({ maxWidth: '84%' })
      if (message.role !== 'user') { Blank() }
    }.width('100%')
  }

  @Builder
  PlanPreview() {
    Column({ space: 8 }) {
      Row() {
        Text(this.planSource === 'openpangu' ? '盘古 · 在线生成' : '本地方案')
          .fontSize(9).fontWeight(FontWeight.Medium)
          .fontColor(this.planSource === 'openpangu' ? '#287C63' : '#8A6A35')
          .backgroundColor(this.planSource === 'openpangu' ? '#E2F6EE' : '#FFF2D9')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(9)
      }.width('100%')
      Text(this.planSummary).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#42465B').width('100%')
      ForEach(this.planTasks, (task: AgentGeneratedTask, index: number) => {
        Row({ space: 8 }) {
          Text(`${index + 1}`).width(22).height(22).textAlign(TextAlign.Center).fontSize(10)
            .fontColor('#625CC8').backgroundColor('#E9E6FA').borderRadius(11)
          Column({ space: 2 }) {
            Text(task.title).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#303347').maxLines(2)
            Text(`${task.subject} · ${task.minutes}分钟`).fontSize(10).fontColor('#85899E')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
      }, (task: AgentGeneratedTask, index: number) =>
        `floating-plan-${index}-${task.title}-${task.minutes}`)
      Button(this.busy ? '正在加入…' : '接受并加入今日待办').width('100%').height(38)
        .fontSize(12).backgroundColor('#6661CF').borderRadius(12).enabled(!this.busy)
        .onClick(() => { this.onAcceptPlan(); })
    }.width('100%').padding(12).backgroundColor('#F0EFFA').borderRadius(16)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.open) {
        Column().width('100%').height('100%').backgroundColor('#33090C18')
          .hitTestBehavior(HitTestMode.Block).onClick(() => { this.onClose(); })
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            StudyPlanet({ stage: this.planetStage, planetSize: 36, wink: true })
            Column({ space: 2 }) {
              Text('小星球助手').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#292D43')
              Text(this.mode === 'planning' ? '把想法变成今天能完成的行动' :
                (this.supportSource === 'openpangu' ? '盘古在线 · 对话不会进入学习画像' : '这里的对话不会进入学习画像'))
                .fontSize(9).fontColor('#8C90A2')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('×').width(32).height(32).textAlign(TextAlign.Center).fontSize(23).fontColor('#777B90')
              .onClick(() => { this.onClose(); })
          }.width('100%')
          Row({ space: 7 }) {
            Button('帮我安排学习').layoutWeight(1).height(33).fontSize(11)
              .fontColor(this.mode === 'planning' ? Color.White : '#6661CF')
              .backgroundColor(this.mode === 'planning' ? '#6661CF' : '#EFEEFA').borderRadius(12)
              .onClick(() => { this.onModeChange('planning'); })
            Button('陪我聊聊').layoutWeight(1).height(33).fontSize(11)
              .fontColor(this.mode === 'support' ? Color.White : '#6661CF')
              .backgroundColor(this.mode === 'support' ? '#6661CF' : '#EFEEFA').borderRadius(12)
              .onClick(() => { this.onModeChange('support'); })
          }.width('100%')
          Scroll() {
            Column({ space: 9 }) {
              if (this.visibleMessages().length === 0) {
                Text(this.mode === 'planning' ?
                  '告诉我①想完成的结果 ②什么时候要用 ③现在有多久。没写全也没关系，我会先给出可执行方案。' :
                  '我在。你可以先说说此刻最压着你的那件事。')
                  .fontSize(12).lineHeight(19).fontColor('#656A80').width('100%')
                  .padding(12).backgroundColor('#F4F3FA').borderRadius(15)
                if (this.mode === 'planning') {
                  Row({ space: 6 }) {
                    Text('25分钟推进').fontSize(10).fontColor('#625CC8')
                      .padding({ left: 9, right: 9, top: 7, bottom: 7 }).backgroundColor('#ECEAFA').borderRadius(12)
                      .onClick(() => { this.onInputChange('我现在有25分钟，请帮我安排一个能明确完成的学习结果'); })
                    Text('按考试优先').fontSize(10).fontColor('#625CC8')
                      .padding({ left: 9, right: 9, top: 7, bottom: 7 }).backgroundColor('#ECEAFA').borderRadius(12)
                      .onClick(() => { this.onInputChange('请按考试截止时间和重要性，安排我现在最该做的学习任务'); })
                  }.width('100%')
                }
              }
              ForEach(this.visibleMessages(), (message: AgentConversationMessage) => {
                this.MessageBubble(message)
              }, (message: AgentConversationMessage) => message.id)
              if (this.mode === 'planning' && this.planReady) { this.PlanPreview() }
              if (this.acceptedMessage.length > 0 && this.mode === 'planning') {
                Row() {
                  Text(`✓ ${this.acceptedMessage}`).layoutWeight(1).fontSize(11).fontColor('#258064')
                  Text('查看待办 ›').fontSize(11).fontColor('#625CC8').onClick(() => { this.onViewTasks(); })
                }.width('100%').padding(10).backgroundColor('#E8F8F2').borderRadius(12)
              }
              if (this.busy) { Text('星球正在回应…').fontSize(11).fontColor('#8C90A2').width('100%') }
            }.width('100%')
          }.layoutWeight(1).scrollBar(BarState.Off)
          if (this.error.length > 0) {
            Text(this.error).fontSize(10).fontColor('#A45D24').width('100%').maxLines(2)
          }
          Row({ space: 8 }) {
            TextInput({ text: this.input, placeholder: this.mode === 'planning' ?
              '例如：今晚用40分钟复习高数' : '现在心里是什么感觉？' })
              .layoutWeight(1).height(42).fontSize(12).backgroundColor('#F4F3FA').borderRadius(13)
              .focusable(true).focusOnTouch(true)
              .onChange((value: string) => { this.onInputChange(value); })
            Button('发送').width(58).height(42).fontSize(11).backgroundColor('#6661CF').borderRadius(13)
              .enabled(!this.busy && this.input.trim().length > 0).onClick(() => { this.onSend(); })
          }.width('100%')
          if (this.mode === 'support') {
            Text('小星球不能替代医生或心理咨询师；如有紧急危险，请立即联系可信任的人或专业机构。')
              .fontSize(8).lineHeight(12).fontColor('#9A8FA6').width('100%')
          }
        }.width(Math.max(280, this.areaWidth - 30)).height(Math.min(560, this.areaHeight - 96))
          .padding(16).backgroundColor('#FAF9FE').borderRadius(24)
          .shadow({ radius: 28, color: '#33252A4A', offsetX: 0, offsetY: 10 })
          .position({ x: 15, y: Math.max(18, (this.areaHeight - Math.min(560, this.areaHeight - 96)) / 2) })
          // Default 允许弹窗及其 TextInput 子节点接收触摸；Block 会把子节点一并禁用。
          .hitTestBehavior(HitTestMode.Default)
      }
      Stack() {
        StudyPlanet({ stage: this.planetStage, planetSize: 58, wink: this.open })
        Text('✦').fontSize(13).fontColor('#F3DDAF').position({ x: 40, y: 5 })
      }.width(62).height(62).position({ x: this.planetX, y: this.planetY })
        .scale({ x: this.open ? 1.1 : 1, y: this.open ? 1.1 : 1 })
        .animation({ duration: 220, curve: Curve.EaseOut })
        .onClick(() => { if (!this.dragged) { this.onToggle(); } })
        .gesture(PanGesture({ direction: PanDirection.All, distance: 5 })
          .onActionStart(() => {
            this.dragStartX = this.planetX; this.dragStartY = this.planetY; this.dragged = false;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.dragged = true;
            this.planetX = Math.max(8, Math.min(this.areaWidth - 64, this.dragStartX + event.offsetX));
            this.planetY = Math.max(16, Math.min(this.areaHeight - 120, this.dragStartY + event.offsetY));
          })
          .onActionEnd(() => { setTimeout(() => { this.dragged = false; }, 120); }))
        .hitTestBehavior(HitTestMode.Block)
    }.width('100%').height('100%')
      .hitTestBehavior(this.open ? HitTestMode.Default : HitTestMode.Transparent)
      .onAreaChange((_old: Area, area: Area) => {
        const width: number = Number(area.width);
        const height: number = Number(area.height);
        if (width !== this.areaWidth || height !== this.areaHeight || this.planetX < 0 || this.planetY < 0) {
          this.areaWidth = width;
          this.areaHeight = height;
          this.clampPlanet();
        }
      })
  }
}
