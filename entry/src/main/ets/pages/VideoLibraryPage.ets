import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { LearningVideo, VideoModule, VideoLibraryState } from '../models/VideoModels';
import { VideoCatalog } from '../services/VideoCatalog';

@Component
export struct VideoLibraryPageView {
  @State detailId: string = ''; 
  @Prop moduleId: string = 'career';
  @Prop plannedVideoIds: string[] = [];
  @Prop initialQuery: string = '';
  @Prop backLabel: string = '返回小队';
  @State private topic: string = '全部';
  @State private query: string = '';
  @State private mode: string = '全部';
  @State private favoriteIds: string[] = [];
  @State private watchedIds: string[] = [];
  @State private loaded: boolean = false;
  @State private busy: boolean = false;
  @State private message: string = '';
  private store?: preferences.Preferences;
  onBack: () => void = () => {};
  onAddTask: (video: LearningVideo) => Promise<void> = async () => {};

  aboutToAppear(): void {
    this.query = this.initialQuery;
    this.loadRecords();
  }

  private config(): VideoModule { return VideoCatalog.module(this.moduleId); }
  private videos(): LearningVideo[] {
    return VideoCatalog.filter(this.moduleId, this.topic, this.query, this.mode, this.favoriteIds, this.watchedIds);
  }

  private async loadRecords(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext();
      if (context === undefined) { throw new Error('context'); }
      this.store = await preferences.getPreferences(context, 'learning_video_library');
      const raw: string = await this.store.get('records', '{"favoriteIds":[],"watchedIds":[]}') as string;
      const value: VideoLibraryState = VideoCatalog.decode(raw);
      this.favoriteIds = value.favoriteIds;
      this.watchedIds = value.watchedIds;
      this.loaded = true;
    } catch (error) {
      this.message = '本地记录读取失败，仍可观看；请返回后重试。';
    }
  }

  private async toggleRecord(id: string, favorite: boolean): Promise<void> {
    if (!this.loaded || this.busy || this.store === undefined) { return; }
    this.busy = true;
    const next: VideoLibraryState = {
      favoriteIds: favorite ? VideoCatalog.toggle(this.favoriteIds, id) : this.favoriteIds,
      watchedIds: favorite ? this.watchedIds : VideoCatalog.toggle(this.watchedIds, id)
    };
    try {
      await this.store.put('records', JSON.stringify(next));
      await this.store.flush();
      this.favoriteIds = next.favoriteIds;
      this.watchedIds = next.watchedIds;
      this.message = favorite ? '收藏记录已保存到本机。' : '观看标记已保存；不会据此修改知识掌握度。';
    } catch (error) {
      this.message = '记录保存失败，请重试。';
    } finally { this.busy = false; }
  }

  private async openUrl(url: string): Promise<void> {
    if (this.busy) { return; }
    if (!VideoCatalog.allowedUrl(url)) { this.message = '链接不在允许的来源范围内。'; return; }
    this.busy = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.openLink(url);
      this.message = '已请求打开原平台。看完可回来手动标记“已看”。';
    } catch (error) {
      this.message = '未能打开链接，请检查网络及浏览器后重试；部分内容可能已下架。';
    } finally { this.busy = false; }
  }

  private async addTask(video: LearningVideo): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      await this.onAddTask(video);
      this.message = '已加入今日待办：预留15分钟观看与记录（不是视频时长）。';
    } catch (error) {
      this.message = '学习任务保存失败，请重试。';
    } finally { this.busy = false; }
  }

  private async copyLink(video: LearningVideo): Promise<void> {
    if (this.busy || !VideoCatalog.allowedUrl(video.url)) { return; }
    this.busy = true;
    try {
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, video.url));
      this.message = '链接已复制，可粘贴到浏览器打开。';
    } catch (error) {
      this.message = '复制失败，请稍后重试。';
    } finally { this.busy = false; }
  }

  @Builder
  VideoCard(video: LearningVideo) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('▶').fontSize(19).fontColor(this.config().accent)
        }.width(54).height(62).backgroundColor(this.config().tint).borderRadius(14)
        Column({ space: 5 }) {
          Text(video.topic + '  /  ' + video.format).fontSize(10).fontColor(this.config().accent)
          Text(video.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#292D40').lineHeight(23)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Text(this.detailId === video.id ? '收起简介 ⌃' : '简介与来源 ›').fontSize(11).fontColor('#83889B')
        .onClick(() => { this.detailId = this.detailId === video.id ? '' : video.id; })
      if (this.detailId === video.id) {
      Text(video.description).width('100%').fontSize(12).lineHeight(20).fontColor('#697087')
      Text(`${video.platform} · ${video.publisher}`).width('100%').fontSize(10).lineHeight(17).fontColor('#83889B')
      Text(video.publishedAt.length > 0 ? `发布 ${video.publishedAt}` : '日期与时长见原平台')
        .width('100%').fontSize(10).fontColor('#83889B')
      Text(video.note).width('100%').fontSize(10).lineHeight(17).fontColor('#837968')
        .padding(10).backgroundColor('#FAF7F1').borderRadius(10)
      }
      Row({ space: 8 }) {
        Button('去观看 ↗').layoutWeight(1).height(40).fontSize(12).fontWeight(FontWeight.Medium)
          .backgroundColor(this.config().accent).fontColor(Color.White).borderRadius(12)
          .enabled(!this.busy).onClick(() => { this.openUrl(video.url); })
        Button(this.plannedVideoIds.includes(video.id) ? '已加入待办' : '加入计划')
          .layoutWeight(1).height(40).fontSize(12).fontColor(this.config().accent)
          .backgroundColor(this.config().tint).borderRadius(12)
          .enabled(!this.busy && !this.plannedVideoIds.includes(video.id))
          .onClick(() => { this.addTask(video); })
      }.width('100%')
      Row({ space: 8 }) {
        Button(this.favoriteIds.includes(video.id) ? '★ 已收藏' : '☆ 收藏')
          .layoutWeight(1).height(40).fontSize(11).fontColor(this.config().accent).backgroundColor(Color.Transparent)
          .enabled(this.loaded && !this.busy).onClick(() => { this.toggleRecord(video.id, true); })
        Button(this.watchedIds.includes(video.id) ? '✓ 已看' : '标记已看')
          .layoutWeight(1).height(40).fontSize(11).fontColor('#697087').backgroundColor(Color.Transparent)
          .enabled(this.loaded && !this.busy).onClick(() => { this.toggleRecord(video.id, false); })
        Button('复制链接').layoutWeight(1).height(40).fontSize(11).fontColor('#697087')
          .backgroundColor(Color.Transparent).enabled(!this.busy).onClick(() => { this.copyLink(video); })
      }.width('100%').margin({ top: -8, bottom: -6 })
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(20)
      .border({ width: 1, color: '#EAECF3' })
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Button('‹ ' + this.backLabel).height(44).fontSize(12).fontColor('#626B84').backgroundColor(Color.Transparent)
          .onClick(() => { this.onBack(); })
        Blank()
        Text('知识补给').fontSize(11).fontColor('#8B91A4')
      }.width('100%').padding({ left: 10, right: 24 })
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 8 }) {
            Text('LEARN  /  EXPLORE').fontSize(9).letterSpacing(2).fontColor(this.config().accent)
            Text(this.config().title).fontSize(27).fontWeight(FontWeight.Medium).fontColor('#282D40')
            Text(this.config().subtitle).fontSize(13).fontColor('#737B90')
            Text('原平台观看 · 记录仅存本机')
              .fontSize(11).lineHeight(19).fontColor('#7E8496').margin({ top: 4 })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
            .backgroundColor(this.config().tint).borderRadius(20)
          TextInput({ placeholder: '搜索标题、知识点或平台', text: this.query })
            .height(44).fontSize(13).backgroundColor(Color.White).borderRadius(12)
            .onChange((value: string) => { this.query = value; })
          Scroll() {
            Row({ space: 8 }) {
              ForEach(VideoCatalog.topics(this.moduleId), (topic: string) => {
                Button(topic).height(36).fontSize(11).fontColor(this.topic === topic ? Color.White : '#72798C')
                  .backgroundColor(this.topic === topic ? this.config().accent : Color.White)
                  .onClick(() => { this.topic = topic; })
              }, (topic: string) => topic)
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          Row({ space: 8 }) {
            ForEach(['全部', '收藏', '已看'], (mode: string) => {
              Button(mode).height(36).fontSize(11).backgroundColor(Color.Transparent)
                .fontColor(this.mode === mode ? this.config().accent : '#8B91A4')
                .fontWeight(this.mode === mode ? FontWeight.Medium : FontWeight.Normal)
                .onClick(() => { this.mode = mode; })
            }, (mode: string) => mode)
            Blank()
            Text(`${this.videos().length} 项内容`).fontSize(11).fontColor('#8B91A4')
          }.width('100%')
          if (this.message.length > 0) {
            Text(this.message).width('100%').fontSize(12).lineHeight(20).fontColor('#556580')
              .padding(12).backgroundColor('#EAF0F8').borderRadius(12)
          }
          if (this.videos().length === 0) {
            Column({ space: 12 }) {
              Text('这里还没有内容').fontSize(16).fontColor('#555E76')
              Text('试试其他分类，或先收藏、标记一条视频。').fontSize(12).fontColor('#8B91A4')
              Button('重置筛选').height(40).fontSize(12).backgroundColor(this.config().tint)
                .fontColor(this.config().accent).onClick(() => { this.query = ''; this.topic = '全部'; this.mode = '全部'; })
            }.width('100%').padding(24).backgroundColor(Color.White).borderRadius(18)
          }
          ForEach(this.videos(), (video: LearningVideo) => {
            this.VideoCard(video)
          }, (video: LearningVideo) => video.id)
          Button('去 B 站搜索更多 ↗').width('100%').height(44).fontSize(12)
            .fontColor(this.config().accent).backgroundColor(this.config().tint).enabled(!this.busy)
            .onClick(() => {
              this.openUrl('https://search.bilibili.com/all?keyword=' + encodeURIComponent(this.config().searchTerm));
            })
          Text('外链可能需登录或付费；搜索结果未逐条审核。医保、合同内容请核对当地现行规定。')
            .width('100%').fontSize(10).lineHeight(18).fontColor('#8990A2')
        }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 28 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1).backgroundColor('#F6F7FC')
  }
}
