import { PageHeader } from '../components/PageHeader';
import { ScheduleItem, StudyTask } from '../models/StudyModels';

@Component
export struct PlanPageView {
  @Prop setupScheduleReady: boolean = false;
  @Prop scheduleItems: ScheduleItem[] = [];
  @Prop newTaskTitle: string = '';
  @Prop profileSubject: string = '';
  @Prop profileExamDate: string = '';
  @Prop examDays: number = 0;
  @Prop tasks: StudyTask[] = [];
  onUseDemoSchedule: () => void = () => {};
  onNewTaskTitleChange: (value: string) => void = () => {};
  onAddTask: () => void = () => {};
  onStartTask: (index: number) => void = () => {};

  @Builder
  TaskCard(index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.tasks[index].title)
          .width('100%').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#25283A')
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%').fontSize(12).fontColor('#9A9EB0')
      }.layoutWeight(1)
      if (this.tasks[index].completed) {
        Text('已完成').fontSize(13).fontColor('#22B07D').backgroundColor('#E8F8F2')
          .padding({ left: 11, right: 11, top: 7, bottom: 7 }).borderRadius(14)
      } else {
        Button('开始').fontSize(13).height(36).backgroundColor('#5B5FEF')
          .onClick(() => {
            this.onStartTask(index);
          })
      }
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        PageHeader({ icon: '📋', title: '计划', subtitle: '今日行动清单 · 根据考试目标动态调整' })
        Column({ space: 12 }) {
          Row() {
            Text('今日课表').fontSize(18).fontWeight(FontWeight.Bold)
            Blank()
            Text(this.setupScheduleReady ? '已同步' : '待导入').fontSize(12)
              .fontColor(this.setupScheduleReady ? '#218764' : '#A26B4E')
          }.width('100%')
          if (this.setupScheduleReady) {
            ForEach(this.scheduleItems, (item: ScheduleItem) => {
              Row({ space: 12 }) {
                Text(item.startTime).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
                Column({ space: 3 }) {
                  Text(item.course).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
                  Text(`${item.startTime}-${item.endTime} · ${item.location}`)
                    .width('100%').fontSize(12).fontColor('#9397A9')
                }.layoutWeight(1)
              }.width('100%')
            }, (item: ScheduleItem) => item.id)
          } else {
            Button('使用演示课表')
              .width('100%').height(42).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
              .onClick(() => {
                this.onUseDemoSchedule();
              })
          }
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        Row({ space: 10 }) {
          TextInput({ placeholder: '添加今天要完成的任务', text: this.newTaskTitle })
            .layoutWeight(1).height(46).backgroundColor(Color.White).borderRadius(14)
            .onChange((value: string) => {
              this.onNewTaskTitleChange(value);
            })
          Button('添加').height(46).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.onAddTask();
            })
        }.width('100%')
        Row() {
          Column({ space: 3 }) {
            Text(`${this.profileSubject}考试`).width('100%').fontSize(15).fontWeight(FontWeight.Bold)
            Text(this.profileExamDate).width('100%').fontSize(12).fontColor('#A26B4E')
          }.layoutWeight(1)
          Blank()
          Text(`还有${this.examDays}天`).fontSize(13).fontColor('#E06B3C')
        }
        .width('100%').padding(16).backgroundColor('#FFF2E8').borderRadius(16)
        ForEach(this.tasks, (task: StudyTask, index: number) => {
          this.TaskCard(index)
        }, (task: StudyTask, index: number) => `${index}-${task.title}`)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }
}
