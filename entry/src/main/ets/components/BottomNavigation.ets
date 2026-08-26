export interface NavigationItem {
  icon: string;
  title: string;
}

@Component
export struct BottomNavigation {
  @Prop currentTab: number = 0;
  onTabChange: (index: number) => void = () => {};
  private readonly items: NavigationItem[] = [
    { icon: '🏠', title: '首页' },
    { icon: '📋', title: '计划' },
    { icon: '📚', title: '学习' },
    { icon: '⏱️', title: '专注' },
    { icon: '🌱', title: '成长' },
    { icon: '👤', title: '我的' }
  ];

  @Builder
  TabButton(index: number, item: NavigationItem) {
    Column() {
      Text(item.icon)
        .width('100%').height(30).fontSize(21)
        .textAlign(TextAlign.Center).maxLines(1)
      Text(item.title)
        .width('100%').height(22).fontSize(12)
        .textAlign(TextAlign.Center).maxLines(1)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? '#5B5FEF' : '#8B90A5')
    }
    .layoutWeight(1).height(72)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTabChange(index);
    })
  }

  build() {
    Row() {
      ForEach(this.items, (item: NavigationItem, index: number) => {
        this.TabButton(index, item)
      }, (item: NavigationItem) => item.title)
    }
    .width('100%').height(72).backgroundColor(Color.White)
    .borderRadius({ topLeft: 22, topRight: 22 })
  }
}
