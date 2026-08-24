interface StudyTask {
  title: string;
  subject: string;
  minutes: number;
  completed: boolean;
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State tasks: StudyTask[] = [
    { title: '回顾矩阵运算规则', subject: '线性代数', minutes: 25, completed: false },
    { title: '完成数据结构报告框架', subject: '数据结构', minutes: 30, completed: false },
    { title: '线性代数基础小测', subject: '线性代数', minutes: 10, completed: false },
    { title: '复习今日课堂笔记', subject: '专业课', minutes: 20, completed: false }
  ];
  @State currentTaskIndex: number = 0;
  @State focusMinutes: number = 25;
  @State remainingSeconds: number = 25 * 60;
  @State isRunning: boolean = false;
  @State todayMinutes: number = 0;
  @State shadowPulse: number = 1;
  @State newTaskTitle: string = '';
  @State energyState: string = '一般';
  private timerId: number = -1;

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private completedCount(): number {
    return this.tasks.filter((task: StudyTask) => task.completed).length;
  }

  private currentTask(): StudyTask {
    return this.tasks[this.currentTaskIndex];
  }

  private formatTime(seconds: number): string {
    const minute: number = Math.floor(seconds / 60);
    const second: number = seconds % 60;
    return `${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}`;
  }

  private todayTimeText(): string {
    if (this.todayMinutes < 60) {
      return `${this.todayMinutes}分钟`;
    }
    const hour: number = Math.floor(this.todayMinutes / 60);
    const minute: number = this.todayMinutes % 60;
    return `${hour}小时${minute}分钟`;
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.isRunning = false;
  }

  private beginFocus(index: number): void {
    this.stopTimer();
    this.currentTaskIndex = index;
    this.focusMinutes = this.tasks[index].minutes;
    this.remainingSeconds = this.focusMinutes * 60;
    this.currentTab = 2;
    this.startTimer();
  }

  private startTimer(): void {
    if (this.isRunning || this.remainingSeconds <= 0) {
      return;
    }
    this.isRunning = true;
    this.timerId = setInterval(() => {
      if (this.remainingSeconds > 0) {
        this.remainingSeconds -= 1;
        this.shadowPulse = this.shadowPulse >= 1.08 ? 1 : this.shadowPulse + 0.01;
      } else {
        this.finishFocus();
      }
    }, 1000);
  }

  private resetFocus(): void {
    this.stopTimer();
    this.remainingSeconds = this.focusMinutes * 60;
    this.shadowPulse = 1;
  }

  private finishFocus(): void {
    this.stopTimer();
    if (this.remainingSeconds > 0) {
      this.remainingSeconds = 0;
    }
    if (!this.tasks[this.currentTaskIndex].completed) {
      this.todayMinutes += this.focusMinutes;
      this.setTaskCompleted(this.currentTaskIndex, true);
    }
  }

  private setTaskCompleted(index: number, completed: boolean): void {
    this.tasks = this.tasks.map((task: StudyTask, taskIndex: number) => {
      if (taskIndex === index) {
        return {
          title: task.title,
          subject: task.subject,
          minutes: task.minutes,
          completed: completed
        };
      }
      return task;
    });
  }

  private addTask(): void {
    const title: string = this.newTaskTitle.trim();
    if (title.length === 0) {
      return;
    }
    this.tasks = this.tasks.concat([{
      title: title,
      subject: '自定义任务',
      minutes: 25,
      completed: false
    }]);
    this.newTaskTitle = '';
  }

  @Builder
  TabButton(index: number, icon: string, title: string) {
    Column({ space: 3 }) {
      Text(icon).fontSize(21)
      Text(title)
        .fontSize(12)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? '#5B5FEF' : '#8B90A5')
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    })
  }

  @Builder
  PageHeader(icon: string, title: string, subtitle: string) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(icon).fontSize(25)
        Text(title).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202235')
      }
      .width('100%')
      Text(subtitle).width('100%').fontSize(14).fontColor('#8B90A5')
    }
    .width('100%')
  }

  @Builder
  HomeTaskRow(index: number) {
    Row({ space: 10 }) {
      Text(this.tasks[index].completed ? '✓' : '○')
        .fontSize(18)
        .fontColor(this.tasks[index].completed ? '#22B07D' : '#4F556B')
      Column({ space: 3 }) {
        Text(this.tasks[index].title)
          .width('100%')
          .fontSize(15)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#292C3D')
          .decoration({
            type: this.tasks[index].completed ? TextDecorationType.LineThrough : TextDecorationType.None
          })
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%')
          .fontSize(12)
          .fontColor('#9A9EB0')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .onClick(() => {
      this.setTaskCompleted(index, !this.tasks[index].completed);
    })
  }

  @Builder
  HomePage() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('上午好，小林').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202235')
            Text('今天从一件小事开始').fontSize(15).fontColor('#8B90A5')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('🔥 11天连续')
            .fontSize(13)
            .fontColor('#E88132')
            .backgroundColor('#FFF1DF')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .borderRadius(16)
        }
        .width('100%')

        Column({ space: 14 }) {
          Row({ space: 8 }) {
            Text('✦').fontColor('#5B5FEF')
            Text('主动建议').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#5B5FEF')
          }
          .width('100%')
          Text(`现在最值得做：${this.tasks[0].title}`)
            .width('100%').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#202235')
          Text(`结合考试日期、今日课表和你“${this.energyState}”的状态，先完成一个${this.tasks[0].minutes}分钟的小目标。`)
            .width('100%').fontSize(15).fontColor('#666C82').lineHeight(23)
          Row({ space: 8 }) {
            Text(`⏱ ${this.tasks[0].minutes}分钟`).fontSize(13).fontColor('#555A70')
            Text('📘 线性代数').fontSize(13).fontColor('#555A70')
            Text('🎯 还有14天').fontSize(13).fontColor('#555A70')
          }
          .width('100%')
          Button(`开始 ${this.tasks[0].minutes} 分钟`)
            .width('100%').height(48).fontSize(16).backgroundColor('#5B5FEF').borderRadius(16)
            .onClick(() => {
              this.beginFocus(0);
            })
        }
        .width('100%').padding(20).backgroundColor('#F0EFFF').borderRadius(24)

        Row({ space: 12 }) {
          Column({ space: 7 }) {
            Text('今日学习').fontSize(13).fontColor('#8B90A5')
            Text(this.todayTimeText()).fontSize(21).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1).padding(16).backgroundColor(Color.White).borderRadius(18)
          Column({ space: 7 }) {
            Text('任务完成').fontSize(13).fontColor('#8B90A5')
            Text(`${this.completedCount()} / ${this.tasks.length}`).fontSize(21).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1).padding(16).backgroundColor(Color.White).borderRadius(18)
        }

        Column({ space: 4 }) {
          Text('今日待办').width('100%').fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 4 })
          ForEach(this.tasks, (task: StudyTask, index: number) => {
            this.HomeTaskRow(index)
          }, (task: StudyTask, index: number) => `${index}-${task.title}`)
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(22)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  @Builder
  PlanTaskCard(index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.tasks[index].title)
          .width('100%').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.tasks[index].completed ? '#9A9EB0' : '#25283A')
        Text(`${this.tasks[index].subject} · ${this.tasks[index].minutes}分钟`)
          .width('100%').fontSize(12).fontColor('#9A9EB0')
      }
      .layoutWeight(1)
      if (this.tasks[index].completed) {
        Text('已完成')
          .fontSize(13).fontColor('#22B07D').backgroundColor('#E8F8F2')
          .padding({ left: 11, right: 11, top: 7, bottom: 7 }).borderRadius(14)
      } else {
        Button('开始')
          .fontSize(13).height(36).backgroundColor('#5B5FEF')
          .onClick(() => {
            this.beginFocus(index);
          })
      }
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }

  @Builder
  PlanPage() {
    Scroll() {
      Column({ space: 16 }) {
        this.PageHeader('📋', '计划', '今日行动清单 · 根据考试目标动态调整')
        Row({ space: 10 }) {
          TextInput({ placeholder: '添加今天要完成的任务', text: this.newTaskTitle })
            .layoutWeight(1).height(46).backgroundColor(Color.White).borderRadius(14)
            .onChange((value: string) => {
              this.newTaskTitle = value;
            })
          Button('添加')
            .height(46).backgroundColor('#5B5FEF')
            .onClick(() => {
              this.addTask();
            })
        }
        .width('100%')
        Row() {
          Text('线性代数考试').fontSize(15).fontWeight(FontWeight.Bold)
          Blank()
          Text('还有14天').fontSize(13).fontColor('#E06B3C')
        }
        .width('100%').padding(16).backgroundColor('#FFF2E8').borderRadius(16)
        ForEach(this.tasks, (task: StudyTask, index: number) => {
          this.PlanTaskCard(index)
        }, (task: StudyTask, index: number) => `${index}-${task.title}`)
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  @Builder
  FocusPage() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 5 }) {
          Text('正在做').fontSize(13).fontColor('#B9B6DA')
          Text(this.currentTask().title)
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White).textAlign(TextAlign.Center)
        }
        .width('100%')
        Stack() {
          Column()
            .width(230).height(230).borderRadius(115).backgroundColor('#37336C').opacity(0.6)
            .scale({ x: this.shadowPulse, y: this.shadowPulse })
          Column()
            .width(180).height(180).borderRadius(90).backgroundColor('#625AF5')
            .opacity(this.isRunning ? 0.82 : 0.48)
          Column({ space: 7 }) {
            Text(this.formatTime(this.remainingSeconds))
              .fontSize(45).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text(this.isRunning ? '学习影子正在生长' : '本轮专注已暂停')
              .fontSize(13).fontColor('#D8D6F0')
          }
        }
        .width('100%').height(250)
        Row({ space: 10 }) {
          Button(this.isRunning ? '暂停' : '继续')
            .layoutWeight(1).height(46).backgroundColor('#625AF5')
            .onClick(() => {
              if (this.isRunning) {
                this.stopTimer();
              } else {
                this.startTimer();
              }
            })
          Button('重置')
            .layoutWeight(1).height(46).backgroundColor('#343154')
            .onClick(() => {
              this.resetFocus();
            })
        }
        .width('100%')
        Button('完成本轮专注')
          .width('100%').height(46).fontColor('#24213F').backgroundColor('#E5E2FF')
          .onClick(() => {
            this.finishFocus();
          })
        Row() {
          Column({ space: 5 }) {
            Text('今日累计').fontSize(12).fontColor('#AAA6CB')
            Text(this.todayTimeText()).fontSize(19).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
          Column({ space: 5 }) {
            Text('共同专注').fontSize(12).fontColor('#AAA6CB')
            Text('3个学习影子').fontSize(19).fontColor(Color.White).fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
        }
        .width('100%').padding(18).backgroundColor('#282548').borderRadius(18)
      }
      .width('100%').padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .layoutWeight(1).backgroundColor('#17152F')
  }

  @Builder
  EnergyButton(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.energyState === title ? Color.White : '#5F6478')
      .backgroundColor(this.energyState === title ? '#5B5FEF' : '#F0F1F6')
      .padding({ left: 14, right: 14, top: 9, bottom: 9 }).borderRadius(16)
      .onClick(() => {
        this.energyState = title;
      })
  }

  @Builder
  ProfilePage() {
    Scroll() {
      Column({ space: 18 }) {
        this.PageHeader('👤', '我的', '学习画像 · 数据与隐私')
        Row({ space: 14 }) {
          Text('林')
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#5B5FEF').borderRadius(29)
          Column({ space: 5 }) {
            Text('小林').fontSize(20).fontWeight(FontWeight.Bold)
            Text('大二 · 计算机科学与技术').fontSize(13).fontColor('#8B90A5')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 15 }) {
          Text('学习画像').width('100%').fontSize(18).fontWeight(FontWeight.Bold)
          Row() {
            Text('当前目标').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text('期末复习').fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          Row() {
            Text('学习方式').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text('练习驱动').fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          Row() {
            Text('每日可用时间').fontSize(14).fontColor('#8B90A5')
            Blank()
            Text('60分钟').fontSize(14).fontWeight(FontWeight.Medium)
          }
          .width('100%')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Column({ space: 13 }) {
          Text('今天的状态').width('100%').fontSize(17).fontWeight(FontWeight.Bold)
          Row({ space: 9 }) {
            this.EnergyButton('状态不错')
            this.EnergyButton('一般')
            this.EnergyButton('有点累')
          }
          .width('100%')
        }
        .width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
        Button('重新设置学习画像')
          .width('100%').height(46).fontColor('#5B5FEF').backgroundColor('#ECEBFF')
      }
      .width('100%').padding(20)
    }
    .layoutWeight(1)
  }

  build() {
    Column() {
      if (this.currentTab === 0) {
        this.HomePage()
      } else if (this.currentTab === 1) {
        this.PlanPage()
      } else if (this.currentTab === 2) {
        this.FocusPage()
      } else {
        this.ProfilePage()
      }
      Row() {
        this.TabButton(0, '⌂', '首页')
        this.TabButton(1, '📋', '计划')
        this.TabButton(2, '◉', '专注')
        this.TabButton(3, '👤', '我的')
      }
      .width('100%').height(72).backgroundColor(Color.White)
      .borderRadius({ topLeft: 22, topRight: 22 })
    }
    .width('100%').height('100%').backgroundColor('#F6F7FC')
  }
}
