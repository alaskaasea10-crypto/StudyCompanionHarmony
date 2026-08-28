import { PageHeader } from '../components/PageHeader';
import { StudyTask } from '../models/StudyModels';

@Component
export struct LearningPageView {
  @Prop profileGrade: string = '';
  @Prop profileLearningStyle: string = '';
  @Prop profileDailyMinutes: number = 0;
  @Prop profileSubject: string = '';
  @Prop profileExamDate: string = '';
  @Prop examDays: number = 0;
  @Prop agentInput: string = '';
  @Prop agentGenerated: boolean = false;
  @Prop tasks: StudyTask[] = [];
  @Prop planProgress: number = 0;
  @Prop quizChoice: string = '';
  @Prop quizSubmitted: boolean = false;
  @Prop quizAttemptCount: number = 0;
  @Prop quizCorrectCount: number = 0;
  onAgentInputChange: (value: string) => void = () => {};
  onGeneratePlan: () => void = () => {};
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
        PageHeader({ icon: '📚', title: '智能学习', subtitle: '自然语言规划 · 自适应计划 · 小测反馈' })
        Column({ space: 13 }) {
          Row() {
            Text('✦ 和 Agent 理清今天要做的事').fontSize(17).fontWeight(FontWeight.Bold)
            Blank()
            Text('读取学习画像').fontSize(11).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .padding({ left: 9, right: 9, top: 5, bottom: 5 }).borderRadius(12)
          }.width('100%')
          Text(`已读取：${this.profileGrade} · ${this.profileLearningStyle} · 每天${this.profileDailyMinutes}分钟`)
            .width('100%').fontSize(12).fontColor('#9397A9')
          TextArea({
            placeholder: '例如：下周线代考试，矩阵不太熟，而且今晚有点累。',
            text: this.agentInput
          })
            .width('100%').height(90).backgroundColor('#F6F7FB').borderRadius(14)
            .onChange((value: string) => {
              this.onAgentInputChange(value);
            })
          Button('交给 Agent').width('100%').height(44).backgroundColor('#5B5FEF').borderRadius(15)
            .onClick(() => {
              this.onGeneratePlan();
            })
          if (this.agentGenerated) {
            Column({ space: 8 }) {
              Text(`今日行动清单 · ${this.tasks.length}项`).width('100%').fontSize(14)
                .fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
              ForEach(this.tasks, (task: StudyTask, index: number) => {
                Row() {
                  Text(`${index + 1}. ${task.title}`).layoutWeight(1).fontSize(13)
                  Text(`${task.minutes}分钟`).fontSize(12).fontColor('#9397A9')
                }.width('100%').padding(10).backgroundColor(Color.White).borderRadius(12)
              }, (task: StudyTask, index: number) => `agent-${index}-${task.title}`)
              Text('已同步：首页建议、今日待办、考试科目与番茄钟')
                .width('100%').fontSize(12).fontColor('#218764')
            }
            .width('100%').padding(12).backgroundColor('#E8F8F2').borderRadius(14)
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 13 }) {
          Row() {
            Text('自适应学习计划').fontSize(18).fontWeight(FontWeight.Bold)
            Blank()
            Text(`${this.planProgress}%`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          }.width('100%')
          Text(`${this.profileSubject} · 距考试${this.examDays}天 · ${this.profileExamDate}`)
            .width('100%').fontSize(13).fontColor('#777C90')
          Row({ space: 8 }) {
            Text('Day 1').fontSize(12).fontColor(Color.White).backgroundColor('#5B5FEF')
              .padding({ left: 10, right: 10, top: 7, bottom: 7 }).borderRadius(12)
            Text('基础梳理').fontSize(13)
            Text('→').fontSize(13).fontColor('#A1A5B5')
            Text('针对练习').fontSize(13)
            Text('→').fontSize(13).fontColor('#A1A5B5')
            Text('即时小测').fontSize(13)
          }.width('100%')
          Text('任务完成后自动更新完成率；小测结果将决定下一轮复习重点。')
            .width('100%').fontSize(12).fontColor('#9397A9')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 12 }) {
          Row() {
            Text('AI 小测 · 学 → 测 → 补').fontSize(18).fontWeight(FontWeight.Bold)
            Blank()
            Text(this.quizAttemptCount === 0 ? '今日暂未测验' :
              `今日答对 ${this.quizCorrectCount}/${this.quizAttemptCount}`)
              .fontSize(11).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .padding({ left: 9, right: 9, top: 5, bottom: 5 }).borderRadius(12)
          }.width('100%')
          Text('若矩阵 A 可逆，下列结论正确的是？').width('100%').fontSize(15).fontWeight(FontWeight.Medium)
          this.QuizOption('A', 'det(A)=0')
          this.QuizOption('B', 'A 的列向量线性无关')
          this.QuizOption('C', 'A 没有逆矩阵')
          this.QuizOption('D', 'A 的秩小于列数')
          Button('提交答案').width('100%').height(42).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.onSubmitQuiz();
            })
          if (this.quizSubmitted) {
            Text(this.quizChoice === 'B' ? '回答正确：可逆矩阵满秩，列向量线性无关。' :
              '还差一点。建议回顾“可逆矩阵与秩”的关系，随后再测一次。')
              .width('100%').fontSize(13)
              .fontColor(this.quizChoice === 'B' ? '#218764' : '#C2623A')
              .backgroundColor(this.quizChoice === 'B' ? '#E8F8F2' : '#FFF2E8')
              .padding(12).borderRadius(12)
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 12 }) {
          Text('大学学习路线图').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Text(`${this.profileSubject}章节导航`).width('100%').fontSize(13).fontColor('#9397A9')
          Row({ space: 7 }) {
            Text('基础概念').fontSize(12).padding(9).backgroundColor('#ECEBFF').borderRadius(12)
            Text('→').fontSize(12)
            Text('核心方法').fontSize(12).padding(9).backgroundColor('#ECEBFF').borderRadius(12)
            Text('→').fontSize(12)
            Text('真题应用').fontSize(12).padding(9).backgroundColor('#ECEBFF').borderRadius(12)
          }.width('100%')
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
