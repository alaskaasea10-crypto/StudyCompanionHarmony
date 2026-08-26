@Component
export struct PageHeader {
  icon: string = '';
  title: string = '';
  subtitle: string = '';

  build() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(this.icon).fontSize(25)
        Text(this.title).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#202235')
      }
      .width('100%')
      Text(this.subtitle).width('100%').fontSize(14).fontColor('#8B90A5')
    }
    .width('100%')
  }
}
