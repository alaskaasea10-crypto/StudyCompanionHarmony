import { EmotionalSupportMessage } from '../models/EmotionalSupportModels';
import { EmotionalSupportClient } from '../services/EmotionalSupportClient';
import { StudyPlanet } from '../components/StudyPlanet';

@Component
export struct EmotionalSupportPageView {
  @Prop planetStage: number = 1;
  @State input: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State messages: EmotionalSupportMessage[] = [{
    id: 'welcome', role: 'assistant',
    text: '我在。你可以说说现在最压着你的那件事，我会先听你说。', createdAt: 0
  }];
  onBack: () => void = () => {};

  private send(): void {
    const text: string = this.input.trim();
    if (text.length === 0 || this.busy) { return; }
    const sentAt: number = Date.now();
    const history: EmotionalSupportMessage[] = this.messages;
    this.messages = history.concat([{ id: `user-${sentAt}`, role: 'user', text: text, createdAt: sentAt }]);
    this.input = '';
    this.error = '';
    this.busy = true;
    EmotionalSupportClient.reply(text, history).then((response) => {
      this.messages = this.messages.concat([{
        id: `assistant-${Date.now()}`, role: 'assistant',
        text: response.reply ?? '我在听。', createdAt: Date.now()
      } as EmotionalSupportMessage]);
    }).catch((error: Error) => {
      this.error = error.message.length > 0 ? error.message : '星球暂时没有回应，请稍后再试';
    }).finally(() => { this.busy = false; });
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Text('‹').fontSize(28).fontColor('#6E66A2').width(36).onClick(() => { this.onBack(); })
        StudyPlanet({ stage: this.planetStage, planetSize: 42 })
        Column({ space: 3 }) {
          Text('和星球说说话').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#292D43')
          Text('倾听与情绪陪伴').fontSize(11).fontColor('#8C90A2')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Text('本次对话退出后不保存，也不会进入学习画像或分享给小队。星球不能替代医生或心理咨询师。')
        .width('100%').fontSize(11).lineHeight(17).fontColor('#817A9B')
        .padding(11).backgroundColor('#F1EEFA').borderRadius(12)
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.messages, (message: EmotionalSupportMessage) => {
            Row() {
              if (message.role === 'user') { Blank() }
              Text(message.text).fontSize(14).lineHeight(22)
                .fontColor(message.role === 'user' ? Color.White : '#42465B')
                .backgroundColor(message.role === 'user' ? '#6865D9' : Color.White)
                .padding(14).borderRadius(17).constraintSize({ maxWidth: '84%' })
              if (message.role !== 'user') { Blank() }
            }.width('100%')
          }, (message: EmotionalSupportMessage) => message.id)
          if (this.busy) {
            Text('星球正在听…').fontSize(12).fontColor('#8C90A2').width('100%')
          }
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
      if (this.error.length > 0) {
        Text(this.error).width('100%').fontSize(12).fontColor('#B76450')
      }
      TextArea({ text: this.input, placeholder: '现在心里是什么感觉？' })
        .width('100%').height(92).maxLength(500).fontSize(15).backgroundColor(Color.White)
        .borderRadius(16).padding(14).enabled(!this.busy)
        .onChange((value: string) => { this.input = value; })
      Button(this.busy ? '正在回应…' : '发送给星球').width('100%').height(46)
        .backgroundColor('#6865D9').borderRadius(14)
        .enabled(!this.busy && this.input.trim().length > 0).onClick(() => { this.send(); })
    }.width('100%').layoutWeight(1).padding(20).backgroundColor('#F6F7FC')
  }
}
