import { StudyTask } from '../models/StudyModels';

@Component
export struct HomePageView {
  @Prop profileName: string = '';
  @Prop greeting: string = '';
  @Prop profileSubject: string = '';
  @Prop examDays: number = 0;
  @Prop todayTimeText: string = '0分钟';
  @Prop completedCount: number = 0;
  @Prop tasks: StudyTask[] = [];
  @Prop recommendationTitle: string = '';
  @Prop recommendationReason: string = '';
  @Prop recommendationMinutes: number = 0;
  @Prop recommendationTaskIndex: number = 0;
  @Prop recommendationAllDone: boolean = false;
  @Prop recommendationEvidence: string[] = [];
  @Prop timelineTime: string = '';
  @Prop timelineTitle: string = '';
  @Prop timelineDetail: string = '';
  @Prop showRecommendationDetails: boolean = false;
  onStartFocus: (index: number) => void = () => {};
  onToggleRecommendationDetails: () => void = () => {};
  onToggleTask: (index: number, completed: boolean) => void = () => {};

  @Builder
  TaskRow(index: number) {
    Row({ space: 10 }) {
      Text(this.tasks[index].completed ? '✓' : '○')
        .fontSize(18).fontColor(this.tasks[index].completed ? '#22B07D' : '#4F556B')
      Column({ space: 3 }) {
        Text(this.tasks[index].title)
          .width('100%').fontSize(15)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#292C3D')
          .decoration({
            type: this.tasks[index].completed ? TextDecorationType.LineThrough : TextDecorationType.None
          })
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%').fontSize(12).fontColor('#9A9EB0')
      }
      .layoutWeight(1)
    }
    .width('100%').padding({ top: 7, bottom: 7 })
    .onClick(() => {
      this.onToggleTask(index, !this.tasks[index].completed);
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text(`${this.greeting}，${this.profileName}`)
              .fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202235')
            Text('今天从一件小事开始').fontSize(15).fontColor('#8B90A5')
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Text('🔥 11天连续')
            .fontSize(13).fontColor('#E88132').backgroundColor('#FFF1DF')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 }).borderRadius(16)
        }.width('100%')

        Column({ space: 14 }) {
          Row({ space: 8 }) {
            Text('✦').fontColor('#5B5FEF')
            Text('主动建议').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          }.width('100%')
          Text(this.recommendationAllDone ? this.recommendationTitle :
            `现在最值得做：${this.recommendationTitle}`)
            .width('100%').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#202235')
          Text(this.recommendationReason)
            .width('100%').fontSize(15).fontColor('#666C82').lineHeight(23)
          if (!this.recommendationAllDone) {
            Row({ space: 8 }) {
              Text(`⏱ ${this.recommendationMinutes}分钟`).fontSize(13).fontColor('#555A70')
              Text(`📘 ${this.profileSubject}`).fontSize(13).fontColor('#555A70')
              Text(`🎯 还有${this.examDays}天`).fontSize(13).fontColor('#555A70')
            }.width('100%')
          }
          Row({ space: 10 }) {
            Button(this.recommendationAllDone ? '今日计划已完成' : `开始 ${this.recommendationMinutes} 分钟`)
              .layoutWeight(1).height(48).fontSize(15)
              .backgroundColor(this.recommendationAllDone ? '#B8B9C8' : '#5B5FEF').borderRadius(16)
              .enabled(!this.recommendationAllDone)
              .onClick(() => {
                if (!this.recommendationAllDone) {
                  this.onStartFocus(this.recommendationTaskIndex);
                }
              })
            Button(this.showRecommendationDetails ? '收起理由' : '为什么推荐')
              .height(48).fontSize(13).fontColor('#5B5FEF').backgroundColor(Color.White).borderRadius(16)
              .onClick(() => {
                this.onToggleRecommendationDetails();
              })
          }.width('100%')
          if (this.showRecommendationDetails) {
            Column({ space: 7 }) {
              ForEach(this.recommendationEvidence, (item: string) => {
                Text(`• ${item}`).width('100%').fontSize(12).fontColor('#666C82')
              }, (item: string) => item)
            }
            .width('100%').padding(12).backgroundColor(Color.White).borderRadius(14)
          }
        }
        .width('100%').padding(20).backgroundColor('#F0EFFF').borderRadius(24)

        Row({ space: 12 }) {
          Column({ space: 7 }) {
            Text('今日学习').fontSize(13).fontColor('#8B90A5')
            Text(this.todayTimeText).fontSize(21).fontWeight(FontWeight.Bold)
          }.layoutWeight(1).padding(16).backgroundColor(Color.White).borderRadius(18)
          Column({ space: 7 }) {
            Text('任务完成').fontSize(13).fontColor('#8B90A5')
            Text(`${this.completedCount} / ${this.tasks.length}`).fontSize(21).fontWeight(FontWeight.Bold)
          }.layoutWeight(1).padding(16).backgroundColor(Color.White).borderRadius(18)
        }

        Column({ space: 12 }) {
          Row() {
            Text('主动服务时间线').fontSize(18).fontWeight(FontWeight.Bold)
            Blank()
            Text('北京时间').fontSize(11).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .padding({ left: 9, right: 9, top: 5, bottom: 5 }).borderRadius(12)
          }.width('100%')
          Row({ space: 12 }) {
            Text(this.timelineTime).width(50).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
            Column({ space: 4 }) {
              Text(this.timelineTitle).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
              Text(this.timelineDetail).width('100%').fontSize(12).fontColor('#9397A9')
            }.layoutWeight(1)
          }.width('100%').padding(14).backgroundColor('#F7F7FB').borderRadius(16)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(22)

        Column({ space: 4 }) {
          Text('今日待办').width('100%').fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 4 })
          ForEach(this.tasks, (task: StudyTask, index: number) => {
            this.TaskRow(index)
          }, (task: StudyTask, index: number) => `${index}-${task.title}`)
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
