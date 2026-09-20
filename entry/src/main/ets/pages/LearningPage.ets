import { PageHeader } from '../components/PageHeader';
import { SectionSwitcher } from '../components/SectionSwitcher';
import { AgentGeneratedTask } from '../models/AgentModels';
import { BankLearningEvidence } from '../models/QuestionBankModels';

@Component
export struct LearningPageView {
  @State showPlanningContext: boolean = false;
  @State showPlanReasons: boolean = false;
  @Prop bankEvidence: BankLearningEvidence[] = [];
  @Prop bankPlanMode: boolean = false;
  @Prop agentCommitBusy: boolean = false;
  @Prop profileGrade: string = '';
  @Prop profileLearningStyle: string = '';
  @Prop profileDailyMinutes: number = 0;
  @Prop availableMinutesToday: number = 0;
  @Prop profileSubject: string = '';
  @Prop profileExamDate: string = '';
  @Prop examDays: number = 0;
  @Prop agentInput: string = '';
  @Prop agentGenerated: boolean = false;
  @Prop agentLoading: boolean = false;
  @Prop agentError: string = '';
  @Prop agentPlanSource: string = '';
  @Prop agentPlanSummary: string = '';
  @Prop agentPreviewTasks: AgentGeneratedTask[] = [];
  @Prop agentRecommendationReasons: string[] = [];
  @Prop agentAcceptedMessage: string = '';
  @Prop agentFeedbackMode: boolean = false;
  @Prop planProgress: number = 0;
  @Prop quizChoice: string = '';
  @Prop quizSubmitted: boolean = false;
  @Prop quizAttemptCount: number = 0;
  @Prop quizCorrectCount: number = 0;
  @Prop quizPrompt: string = '';
  @Prop quizOptionA: string = '';
  @Prop quizOptionB: string = '';
  @Prop quizOptionC: string = '';
  @Prop quizOptionD: string = '';
  @Prop quizCorrect: boolean = false;
  @Prop quizFeedbackMessage: string = '';
  @Prop masteryPoint: string = '';
  @Prop masteryScore: number = 0;
  @Prop masteryStatus: string = '';
  onAgentInputChange: (value: string) => void = () => {};
  onOpenPlan: () => void = () => {};
  onOpenQuestionBank: () => void = () => {};
  onGeneratePlan: () => void = () => {};
  onAcceptAgentPlan: () => void = () => {};
  onQuizChoiceChange: (value: string) => void = () => {};
  onSubmitQuiz: () => void = () => {};

  @Builder
  QuizOption(value: string, text: string) {
    Row({ space: 10 }) {
      Text(value)
        .width(30).height(30).textAlign(TextAlign.Center).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(this.quizChoice === value ? Color.White : '#5B5FEF')
        .backgroundColor(this.quizChoice === value ? '#5B5FEF' : '#ECEBFF').borderRadius(15)
      Text(text).layoutWeight(1).fontSize(14).fontColor('#34374A')
    }
    .width('100%').padding(12).backgroundColor('#F7F7FB').borderRadius(14)
    .onClick(() => {
      this.onQuizChoiceChange(value);
    })
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('‹ 返回目标与计划').fontSize(14).fontColor('#6865D9').width('100%').onClick(() => { this.onOpenPlan(); })
        PageHeader({ icon: '', title: '和 Agent 聊聊', subtitle: '说说薄弱点，确认后开始补学' })
        Column({ space: 13 }) {
          Row() {
            Text('✦ 你想补上哪里？').fontSize(17).fontWeight(FontWeight.Bold)
            Blank()
            Text('结合目标与时间').fontSize(11).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .padding({ left: 9, right: 9, top: 5, bottom: 5 }).borderRadius(12)
          }.width('100%')
          Text(this.showPlanningContext ? '收起规划依据 ⌃' : '查看规划依据 ›')
            .fontSize(12).fontColor('#7971B2').width('100%')
            .onClick(() => { this.showPlanningContext = !this.showPlanningContext; })
          if (this.showPlanningContext) {
          Text(`已读取：${this.profileGrade} · ${this.profileLearningStyle} · 每天${this.profileDailyMinutes}分钟`)
            .width('100%').fontSize(12).fontColor('#9397A9')
          }
          Column({ space: 7 }) {
            Text(`今天剩余可规划：${this.availableMinutesToday}分钟`)
              .width('100%').fontSize(11).fontColor('#218764')
          }
          .width('100%').padding(11).backgroundColor('#F3F2FF').borderRadius(13)
          TextArea({
            placeholder: '例如：下周线代考试，矩阵不太熟，而且今晚有点累。',
            text: this.agentInput
          })
            .width('100%').height(90).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.onAgentInputChange(value);
            })
          Button(this.agentLoading ? 'Agent 正在读取上下文…' : '交给 Agent')
            .width('100%').height(44).backgroundColor('#5B5FEF').borderRadius(15)
            .enabled(!this.agentLoading).opacity(this.agentLoading ? 0.65 : 1)
            .onClick(() => {
              this.onGeneratePlan();
              this.showPlanReasons = false;
            })
          if (this.agentError.length > 0) {
            Text(this.agentError).width('100%').fontSize(12).fontColor('#A45D24')
              .backgroundColor('#FFF4E8').padding(11).borderRadius(12)
          }
          if (this.agentGenerated) {
            Column({ space: 8 }) {
              Row() {
                Text(`${this.agentFeedbackMode ? '测验后调整方案' : '今日行动清单'} · ${this.agentPreviewTasks.length}项`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
                Blank()
                Text(this.agentPlanSource === 'openpangu' ? 'openPangu 生成' : '离线规则')
                  .fontSize(10)
                  .fontColor(this.agentPlanSource === 'openpangu' ? '#218764' : '#A45D24')
                  .backgroundColor(this.agentPlanSource === 'openpangu' ? '#DFF5EC' : '#FFF0DE')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(10)
              }.width('100%')
              Text(this.agentPlanSummary).width('100%').fontSize(13).fontColor('#555A70')
              ForEach(this.agentPreviewTasks, (task: AgentGeneratedTask, index: number) => {
                Column({ space: 5 }) {
                  Row() {
                    Text(`${index + 1}. ${task.title}`).layoutWeight(1).fontSize(13)
                      .fontWeight(FontWeight.Medium)
                    Text(`${task.minutes}分钟`).fontSize(12).fontColor('#5B5FEF')
                  }.width('100%')
                  Text(task.subject).width('100%').fontSize(11).fontColor('#9397A9')
                  if (this.showPlanReasons) {
                    Text(task.reason).width('100%').fontSize(11).fontColor('#9397A9')
                  }
                }.width('100%').padding(10).backgroundColor(Color.White).borderRadius(12)
              }, (task: AgentGeneratedTask, index: number) =>
                `agent-preview-${index}-${task.subject}-${task.title}-${task.minutes}`)
              Text(this.showPlanReasons ? '收起原因 ⌃' : '为什么这样安排 ›')
                .fontSize(12).fontColor('#7971B2').width('100%')
                .onClick(() => { this.showPlanReasons = !this.showPlanReasons; })
              if (this.showPlanReasons && this.agentRecommendationReasons.length > 0) {
                Text(`推荐依据：${this.agentRecommendationReasons.join('；')}`)
                  .width('100%').fontSize(11).fontColor('#73788C')
              }
              Row({ space: 10 }) {
                Button(this.agentCommitBusy ? '正在保存…' : this.bankPlanMode ? '确认追加补学任务' : this.agentFeedbackMode ? '接受调整' : '接受并同步')
                  .layoutWeight(1).height(40).backgroundColor('#5B5FEF').borderRadius(13)
                  .enabled(!this.agentCommitBusy)
                  .onClick(() => {
                    this.onAcceptAgentPlan();
                  })
                Button('重新生成').layoutWeight(1).height(40).fontColor('#5B5FEF')
                  .backgroundColor('#ECEBFF').borderRadius(13)
                  .enabled(!this.agentCommitBusy)
                  .onClick(() => {
                    this.onGeneratePlan();
                  })
              }.width('100%')
            }
            .width('100%').padding(12).backgroundColor('#E8F8F2').borderRadius(14)
          }
          if (this.agentAcceptedMessage.length > 0) {
            Text(`✓ ${this.agentAcceptedMessage}`).width('100%').fontSize(12).fontColor('#218764')
              .backgroundColor('#E8F8F2').padding(11).borderRadius(12)
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
