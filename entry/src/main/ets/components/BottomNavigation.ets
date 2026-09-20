export interface NavigationItem {
  icon: Resource;
  darkIcon: Resource;
  title: string;
}

@Component
export struct BottomNavigation {
  @Prop currentTab: number = 0;
  @Prop darkMode: boolean = false;
  onTabChange: (index: number) => void = () => {};
  private readonly items: NavigationItem[] = [
    { icon: $r('app.media.nav_home'), darkIcon: $r('app.media.nav_home_dark'), title: '首页' },
    { icon: $r('app.media.nav_learning'), darkIcon: $r('app.media.nav_learning_dark'), title: '学习' },
    { icon: $r('app.media.nav_focus'), darkIcon: $r('app.media.nav_focus_dark'), title: '专注' },
    { icon: $r('app.media.nav_profile'), darkIcon: $r('app.media.nav_profile_dark'), title: '我的' }
  ];

  @Builder
  TabButton(index: number, item: NavigationItem) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(38).height(34).borderRadius(12)
          .backgroundColor(this.currentTab === index ? (this.darkMode ? '#292837' : '#F0EFFF') : Color.Transparent)
        Image(this.darkMode ? item.darkIcon : item.icon)
          .width(22).height(22)
          .objectFit(ImageFit.Contain)
          .opacity(this.currentTab === index ? 1 : (this.darkMode ? 0.62 : 0.42))
          .scale({
            x: this.currentTab === index ? 1 : 0.96,
            y: this.currentTab === index ? 1 : 0.96
          })
      }
      .width(40).height(34)
      Text(item.title)
        .width('100%').height(18).lineHeight(18).fontSize(11)
        .textAlign(TextAlign.Center).maxLines(1)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.darkMode ? (this.currentTab === index ? '#D5CDE8' : '#9592A5') :
          (this.currentTab === index ? '#4F52E8' : '#8D93A8'))
    }
    .layoutWeight(1).height(68)
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
    .width('100%').height(76).padding({ top: 4, bottom: 4 })
    .backgroundColor(this.darkMode ? '#151620' : Color.White)
    .border({ width: { top: 0.5 }, color: this.darkMode ? '#2D2D3B' : '#ECEEF5' })
    .borderRadius({ topLeft: this.darkMode ? 0 : 20, topRight: this.darkMode ? 0 : 20 })
  }
}
