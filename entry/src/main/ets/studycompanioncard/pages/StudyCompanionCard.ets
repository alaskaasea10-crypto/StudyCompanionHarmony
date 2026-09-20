let storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct StudyCompanionCard {
  @LocalStorageProp('appName') appName: string = '学伴';
  @LocalStorageProp('eyebrow') eyebrow: string = '星球提醒';
  @LocalStorageProp('taskTitle') taskTitle: string = '准备好了吗？一起学一点。';
  @LocalStorageProp('subject') subject: string = '学习任务';
  @LocalStorageProp('minutesText') minutesText: string = '轻轻开始';
  @LocalStorageProp('examText') examText: string = '等待设置考试';
  @LocalStorageProp('progressText') progressText: string = '0/0';
  @LocalStorageProp('progressPercent') progressPercent: string = '0%';
  @LocalStorageProp('actionText') actionText: string = '打开学伴';
  @LocalStorageProp('target') target: string = 'home';
  @LocalStorageProp('taskId') taskId: string = '';

  build() {
    FormLink({
      action: 'router',
      bundleName: 'com.dongxitonghang.studycompanion',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      params: {
        target: this.target,
        taskId: this.taskId,
        source: 'studyWidget'
      }
    }) {
      Column({ space: 8 }) {
        Row({ space: 10 }) {
          Image($r('app.media.study_planet')).width(54).height(48).objectFit(ImageFit.Contain)
          Column({ space: 4 }) {
            Text('星球提醒').fontSize(12).fontColor('#7D70AD')
            Text(this.taskTitle).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#40375D')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').layoutWeight(1)
        Row() {
          Text(this.minutesText).fontSize(11).fontColor('#8D82A6').maxLines(1)
          Blank()
          Text(this.actionText + ' ›').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#7060B0')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 }).backgroundColor('#EAE3FA').borderRadius(12)
        }.width('100%')
      }.width('100%').height('100%').padding(14).borderRadius(22).clip(true)
        .linearGradient({ angle: 135, colors: [['#FAF7FF', 0], ['#EFEAFB', 1]] })
    }
  }
}
