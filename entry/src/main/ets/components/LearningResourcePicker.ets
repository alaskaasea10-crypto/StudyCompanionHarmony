import { common } from '@kit.AbilityKit';
import { LearningResourceSearchResult, LearningResourceSearchService,
  LearningResourceType } from '../services/LearningResourceSearchService';
import { formatSubjectName } from '../utils/SubjectDisplayName';

@Component
export struct LearningResourcePicker {
  @Prop subject: string = '';
  @Prop taskTitle: string = '';
  @State private busy: boolean = false;
  @State private message: string = '';
  onClose: () => void = () => {};

  private async openResource(resourceType: LearningResourceType): Promise<void> {
    if (this.busy) { return; }
    const result: LearningResourceSearchResult | undefined =
      LearningResourceSearchService.searchLearningResources({
        subject: this.subject,
        taskTitle: this.taskTitle,
        resourceType: resourceType
      });
    if (result === undefined) {
      this.message = '当前任务信息还不完整，暂时无法生成资料搜索。';
      return;
    }
    this.busy = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.openLink(result.externalUri);
      this.message = `已为你打开“${result.displayQuery}”的真实搜索结果。`;
    } catch (error) {
      this.message = '暂时没能打开搜索结果，请检查网络或浏览器后再试。';
    } finally {
      this.busy = false;
    }
  }

  @Builder
  ResourceChoice(icon: string, title: string, description: string, resourceType: LearningResourceType) {
    Row({ space: 13 }) {
      Text(icon).fontSize(23).width(38).height(38).textAlign(TextAlign.Center)
        .backgroundColor('#F0EEFA').borderRadius(12)
      Column({ space: 3 }) {
        Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#30344B').width('100%')
        Text(description).fontSize(11).fontColor('#858BA1').width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(20).fontColor('#928DC7')
    }.width('100%').height(68).padding({ left: 12, right: 12 })
      .backgroundColor('#F8F7FC').borderRadius(16)
      .border({ width: 1, color: '#E8E5F5' })
      .opacity(this.busy ? 0.55 : 1)
      .onClick(() => { this.openResource(resourceType); })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#660E1020')
        .hitTestBehavior(HitTestMode.Block).onClick(() => { if (!this.busy) { this.onClose(); } })
      Column({ space: 14 }) {
        Row() {
          Column({ space: 3 }) {
            Text('小星球帮你找').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#292D43')
            Text(`根据「${formatSubjectName(this.subject)} · ${formatSubjectName(this.taskTitle)}」`)
              .fontSize(11).fontColor('#858BA1').maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('×').width(36).height(36).textAlign(TextAlign.Center).fontSize(24).fontColor('#777D90')
            .onClick(() => { if (!this.busy) { this.onClose(); } })
        }.width('100%').alignItems(VerticalAlign.Top)
        Text('你现在需要哪一种帮助？').fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor('#5D637A').width('100%')
        this.ResourceChoice('🎬', '视频讲解', '找相关课程和知识点讲解', 'video')
        this.ResourceChoice('✏️', '例题练习', '找相关例题和解题过程', 'exercise')
        Text('会前往哔哩哔哩查看真实搜索结果。').fontSize(10).fontColor('#9296A8').width('100%')
        if (this.message.length > 0) {
          Text(this.message).fontSize(11).lineHeight(17).fontColor('#625DC0').width('100%')
            .padding(10).backgroundColor('#F3F1FB').borderRadius(11)
        }
      }.width('90%').padding(20).alignItems(HorizontalAlign.Start)
        .backgroundColor('#FCFBFF').borderRadius(24)
        .shadow({ radius: 28, color: '#33252A4A', offsetX: 0, offsetY: 10 })
        .hitTestBehavior(HitTestMode.Default)
    }.width('100%').height('100%')
  }
}
