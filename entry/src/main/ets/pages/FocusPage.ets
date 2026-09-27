import { SquadMember } from '../models/StudyModels';
import { OrbitField } from '../components/OrbitField';
import { FocusCosmosBackdrop } from '../components/FocusCosmosBackdrop';
import { formatSubjectName } from '../utils/SubjectDisplayName';

@Component
export struct FocusPageView {
  @Prop resultPending: boolean = false;
  @Prop resultKind: string = 'self';
  @Prop resultNote: string = '';
  @Prop resultChecked: boolean = false;
  @Prop resultExperience: string = '';
  onResultNote: (value: string) => void = () => {};
  onResultChecked: (value: boolean) => void = () => {};
  onResultExperience: (value: string) => void = () => {};
  onSubmitResult: () => void = () => {};
  onOpenResult: () => void = () => {};
  onNextAction: () => void = () => {};
  @Prop currentTaskTitle: string = '';
  @Prop currentTaskCompleted: boolean = false;
  @Prop remainingSeconds: number = 0;
  @Prop isRunning: boolean = false;
  @Prop todayTimeText: string = '0分钟';
  @Prop todayFocusSessionCount: number = 0;
  @Prop quizPending: boolean = false;
  @Prop quizPrompt: string = '';
  @Prop quizOptionA: string = '';
  @Prop quizOptionB: string = '';
  @Prop quizOptionC: string = '';
  @Prop quizOptionD: string = '';
  @Prop quizChoice: string = '';
  @Prop quizSubmitted: boolean = false;
  @Prop quizFeedbackMessage: string = '';
  @Prop masteryPoint: string = '';
  @Prop masteryScore: number = 0;
  @Prop masteryStatus: string = '';
  @Prop agentLoading: boolean = false;
  @Prop agentPlanReady: boolean = false;
  @Prop agentError: string = '';
  @Prop squadMembers: SquadMember[] = [];
  @Prop selfTaskProgress: number = 0;
  @Prop collectiveFocusMinutes: number = 0;
  @Prop videoTask: boolean = false;
  @State private selectedQuietMemberId: string = '';
  @State private quietSignalMessage: string = '';
  onOpenVideo: () => void = () => {};
  onPause: () => void = () => {};
  onContinue: () => void = () => {};
  onRestart: () => void = () => {};
  onReset: () => void = () => {};
  onFinish: () => void = () => {};
  onOpenGrowth: () => void = () => {};
  onQuizChoiceChange: (value: string) => void = () => {};
  onSubmitQuiz: () => void = () => {};
  onOpenAdjustment: () => void = () => {};
  onQuietSignal: (memberId: string, signal: string) => void = () => {};
  onEnterImmersive: () => void = () => {};
  onVisibilityChange: (visible: boolean) => void = () => {};

  aboutToDisappear(): void { this.onVisibilityChange(false); }

  private formatTime(seconds: number): string {
    const minute: number = Math.floor(seconds / 60);
    const second: number = seconds % 60;
    return `${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}`;
  }

  private companions(): SquadMember[] {
    return this.squadMembers.filter((member: SquadMember) => !member.isSelf).slice(0, 3);
  }

  private quietTarget(): SquadMember | undefined {
    const selected: SquadMember | undefined = this.companions().find(
      (member: SquadMember) => member.id === this.selectedQuietMemberId
    );
    if (selected !== undefined) {
      return selected;
    }
    return this.companions().find((member: SquadMember) => member.status === '专注中') ?? this.companions()[0];
  }

  private skipResultNote(): void {
    this.onResultNote('');
  }

  private isQuietTarget(memberId: string): boolean {
    const target: SquadMember | undefined = this.quietTarget();
    return target !== undefined && target.id === memberId;
  }

  private sendQuietSignal(signal: string): void {
    const target: SquadMember | undefined = this.quietTarget();
    if (target === undefined) {
      return;
    }
    this.selectedQuietMemberId = target.id;
    this.quietSignalMessage = `已悄悄送给${target.name}`;
    this.onQuietSignal(target.id, signal);
  }

  @Builder
  QuizOption(value: string, text: string) {
    Row({ space: 10 }) {
      Text(value)
        .width(28).height(28).textAlign(TextAlign.Center).fontSize(12).fontWeight(FontWeight.Medium)
        .fontColor(this.quizChoice === value ? '#151620' : '#D8D6F0')
        .backgroundColor(this.quizChoice === value ? '#CCBFDF' : '#30303E').borderRadius(14)
      Text(text).layoutWeight(1).fontSize(13).fontWeight(FontWeight.Medium).lineHeight(21).fontColor('#E3DFEA')
    }
    .width('100%').padding(12).backgroundColor(this.quizChoice === value ? '#302C3D' : '#242430')
    .border({ width: 1, color: this.quizChoice === value ? '#88779F' : '#32313F' }).borderRadius(14)
    .opacity(this.quizSubmitted ? 0.72 : 1)
    .onClick(() => {
      if (!this.quizSubmitted) {
        this.onQuizChoiceChange(value);
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
    FocusCosmosBackdrop()
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 9 }) {
          Text('FOCUS  /  A SHARED UNIVERSE').fontSize(8).fontWeight(FontWeight.Medium).letterSpacing(1.6).fontColor('#8E9AB9')
          Text('共学光场').width('100%').fontSize(27).fontWeight(FontWeight.Bold)
            .letterSpacing(2).fontColor('#ECE9F3')
        }.width('100%').alignItems(HorizontalAlign.Start)
        Row({ space: 4 }) {
          Text('专注空间').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#E5DFF0')
            .layoutWeight(1).height(40).textAlign(TextAlign.Center)
            .backgroundColor('#6759A9').borderRadius(12)
            .border({ width: 1, color: '#8B7BC6' })
            .onClick(() => {})
          Text('成长与小队').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#C5BED4')
            .layoutWeight(1).height(40).textAlign(TextAlign.Center)
            .backgroundColor('#20283B').borderRadius(12)
            .border({ width: 1, color: '#3A4660' })
            .onClick(() => { this.onOpenGrowth(); })
        }.width('100%').height(50).padding(5).backgroundColor('#12192A').borderRadius(16)
          .border({ width: 1, color: '#29344C' })
        if (this.resultPending) {
          Column({ space: 14 }) {
            Row() {
              Text('这次学到了什么？').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ECE9F3')
              Blank()
              Button('跳过').height(32).fontSize(12).fontWeight(FontWeight.Medium)
                .fontColor('#D6CAE7').backgroundColor('#32303E').borderRadius(12)
                .onClick(() => { this.skipResultNote(); })
            }.width('100%').alignItems(VerticalAlign.Center)
              Text(formatSubjectName(this.currentTaskTitle)).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#C1BACF').width('100%')
              TextArea({ text: this.resultNote, placeholder: '一句话记录收获，或仍不明白的地方' })
                .fontColor('#FFFFFF').placeholderColor('#8E879A')
                .height(90).maxLength(160).onChange((value: string) => { this.onResultNote(value); })
              Text('这次学起来怎么样？').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#C1BACF').width('100%')
              Row({ space: 8 }) {
                Button('很顺利').layoutWeight(1).height(36).fontSize(11)
                  .backgroundColor(this.resultExperience === 'smooth' ? '#D6CAE7' : '#32303E')
                  .fontColor(this.resultExperience === 'smooth' ? '#282332' : '#D6CAE7')
                  .onClick(() => { this.onResultExperience('smooth'); })
                Button('一般').layoutWeight(1).height(36).fontSize(11)
                  .backgroundColor(this.resultExperience === 'normal' ? '#D6CAE7' : '#32303E')
                  .fontColor(this.resultExperience === 'normal' ? '#282332' : '#D6CAE7')
                  .onClick(() => { this.onResultExperience('normal'); })
                Button('有点吃力').layoutWeight(1).height(36).fontSize(11)
                  .backgroundColor(this.resultExperience === 'struggling' ? '#D6CAE7' : '#32303E')
                  .fontColor(this.resultExperience === 'struggling' ? '#282332' : '#D6CAE7')
                  .onClick(() => { this.onResultExperience('struggling'); })
              }.width('100%')
              Row({ space: 8 }) {
                Checkbox().select(this.resultChecked).onChange((value: boolean) => { this.onResultChecked(value); })
                Text('我已按任务要求检查产出').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#D6CAE7')
              }
              Button('完成反馈，继续下一步').width('100%').height(46).backgroundColor('#D6CAE7').fontColor('#282332')
                .enabled(this.resultChecked && this.resultExperience.length > 0)
                .onClick(() => { this.onSubmitResult(); })
              Text('记录为自查完成，不计为知识掌握。').fontSize(11).fontWeight(FontWeight.Medium).fontColor('#ACA5BA')
              Button('还有不明白的，问 Agent').width('100%').height(40)
                .backgroundColor(Color.Transparent).fontColor('#D6CAE7')
                .onClick(() => { this.onOpenAdjustment(); })
          }.width('100%').padding(20).backgroundColor('#242430').borderRadius(18)
        }
        if (!this.resultPending) {
        OrbitField({
          members: this.squadMembers,
          isRunning: this.isRunning,
          collectiveMinutes: this.collectiveFocusMinutes,
          selfProgress: this.selfTaskProgress
        }).onClick(() => { this.onEnterImmersive(); })
        Column({ space: 8 }) {
          Text(formatSubjectName(this.currentTaskTitle)).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#C1BACF').maxLines(2)
            .textAlign(TextAlign.Center).lineHeight(21).padding({ left: 12, right: 12 })
          Text(this.formatTime(this.remainingSeconds))
            .fontSize(56).fontWeight(FontWeight.Medium).letterSpacing(3).lineHeight(68).fontColor('#EEEAF5')
          Text(this.isRunning ? '专注中 · 让注意力慢慢沉下来' :
            (this.remainingSeconds <= 0 ? '投入已记录 · 结果另行确认' : '已暂停 · 休息片刻也很好'))
            .fontSize(11).fontWeight(FontWeight.Medium).lineHeight(18).fontColor('#ACA5BA')
          if (this.videoTask) {
            Button('查看视频与学习记录 ›').height(40).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#D6CAE7')
              .backgroundColor('#292633').onClick(() => { this.onOpenVideo(); })
            Text('计时仅记录专注；看完后请在视频列表手动标记。')
              .fontSize(10).fontWeight(FontWeight.Medium).lineHeight(17).fontColor('#ACA5BA').textAlign(TextAlign.Center)
          }
        }.width('100%')
        Row({ space: 10 }) {
          Button(this.isRunning ? '暂停' : (this.remainingSeconds <= 0 ? '再次专注' : '继续'))
            .layoutWeight(1).height(46).fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor('#282332').backgroundColor('#D6CAE7').borderRadius(15)
            .onClick(() => {
              if (this.isRunning) {
                this.onPause();
              } else if (this.remainingSeconds <= 0) {
                this.onRestart();
              } else {
                this.onContinue();
              }
            })
          Button(this.currentTaskCompleted ? '本轮已完成' : '完成专注')
            .layoutWeight(1).height(46).fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.currentTaskCompleted ? '#8E879F' : '#D9D1E5')
            .backgroundColor('#24232F').borderRadius(15)
            .border({ width: 1, color: '#3A3549' }).enabled(!this.currentTaskCompleted)
            .onClick(() => { this.onFinish(); })
        }
        .width('100%')
        Button('重新计时')
          .height(44).padding({ left: 22, right: 22 }).fontSize(11).fontWeight(FontWeight.Medium)
          .fontColor('#AFA6BF').backgroundColor(Color.Transparent).margin({ top: -14, bottom: -10 })
          .onClick(() => { this.onReset(); })
        if (this.companions().length > 0) {
          Column({ space: 10 }) {
            Row() {
              Text('安静敲肩').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#E7E1ED')
              Blank()
              Text('仅发送信号').fontSize(9).fontWeight(FontWeight.Medium).fontColor('#81798D')
            }.width('100%')
            Row({ space: 7 }) {
              ForEach(this.companions(), (member: SquadMember) => {
                Button(member.name).layoutWeight(1).height(31).fontSize(10).fontWeight(FontWeight.Medium)
                  .fontColor(this.isQuietTarget(member.id) ? '#241F2A' : '#BFB7CA')
                  .backgroundColor(this.isQuietTarget(member.id) ? '#D6CAE7' : '#292833').borderRadius(11)
                  .onClick(() => { this.selectedQuietMemberId = member.id; })
              }, (member: SquadMember) => `${member.id}-${member.status}`)
            }.width('100%')
            Row({ space: 7 }) {
              Button('加油').layoutWeight(1).height(36).fontSize(11).fontWeight(FontWeight.Medium).backgroundColor('#32303E').borderRadius(12)
                .onClick(() => { this.sendQuietSignal('加油'); })
              Button('稳住').layoutWeight(1).height(36).fontSize(11).fontWeight(FontWeight.Medium).backgroundColor('#32303E').borderRadius(12)
                .onClick(() => { this.sendQuietSignal('稳住'); })
              Button('休息一下').layoutWeight(1).height(36).fontSize(11).fontWeight(FontWeight.Medium).backgroundColor('#32303E').borderRadius(12)
                .onClick(() => { this.sendQuietSignal('休息一下'); })
            }.width('100%')
            if (this.quietSignalMessage.length > 0) {
              Text(this.quietSignalMessage).fontSize(10).fontWeight(FontWeight.Medium).fontColor('#86CDBB').width('100%')
            }
          }.width('100%').padding(13).backgroundColor('#151D30').borderRadius(16)
        }
        }
        if (this.currentTaskCompleted) {
          Button('查看下一步').width('100%').height(46).backgroundColor('#D6CAE7').fontColor('#282332')
            .onClick(() => { this.onNextAction(); })
        }
        Row() {
          Column({ space: 8 }) {
            Text('今日累计').fontSize(11).fontWeight(FontWeight.Medium).fontColor('#A69EB5')
            Text(this.todayTimeText).fontSize(20).fontWeight(FontWeight.Medium).fontColor('#DED7E9').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          Column().width(1).height(30).backgroundColor('#393442')
          Column({ space: 8 }) {
            Text('完成轮次').fontSize(11).fontWeight(FontWeight.Medium).fontColor('#A69EB5')
            Text(`${this.todayFocusSessionCount} 轮`).fontSize(20).fontWeight(FontWeight.Medium).fontColor('#DED7E9')
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
        }
        .width('100%').padding({ top: 20, bottom: 20 }).backgroundColor('#151D30').borderRadius(18)
      }
      .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 28 })
    }
    .width('100%').height('100%')
    }.layoutWeight(1).backgroundColor('#0D1220')
      .onVisibleAreaChange([0], (visible: boolean) => { this.onVisibilityChange(visible); })
  }
}
