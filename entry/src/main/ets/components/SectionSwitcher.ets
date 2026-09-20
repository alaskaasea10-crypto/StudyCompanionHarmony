@Component
export struct SectionSwitcher {
  @Prop selectedIndex: number = 0;
  @Prop firstTitle: string = '';
  @Prop secondTitle: string = '';
  onChange: (index: number) => void = () => {};

  @Builder
  SwitchItem(index: number, title: string) {
    Text(title)
      .layoutWeight(1).height(40).textAlign(TextAlign.Center).fontSize(13)
      .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedIndex === index ? '#5B5FEF' : '#858A9D')
      .backgroundColor(this.selectedIndex === index ? Color.White : Color.Transparent)
      .borderRadius(13)
      .onClick(() => {
        this.onChange(index);
      })
  }

  build() {
    Row({ space: 4 }) {
      this.SwitchItem(0, this.firstTitle)
      this.SwitchItem(1, this.secondTitle)
    }
    .width('100%').height(48).padding(4).backgroundColor('#EBECF4').borderRadius(16)
  }
}
