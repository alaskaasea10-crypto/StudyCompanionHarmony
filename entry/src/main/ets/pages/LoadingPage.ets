@Component
export struct LoadingPageView {
  build() {
    Column({ space: 16 }) {
      Text('✦').fontSize(42).fontColor('#5B5FEF')
      Text('正在读取学习画像').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#25283A')
      Text('学伴正在准备你的个性化学习空间').fontSize(13).fontColor('#9397A9')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#F6F7FC')
  }
}
