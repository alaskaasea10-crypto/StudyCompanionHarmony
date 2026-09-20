@Component
export struct UserAvatar {
  @Prop avatarUri: string = '';
  @Prop profileName: string = '';
  @Prop avatarSize: number = 58;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.avatarUri.length > 0) {
        Image(this.avatarUri)
          .width(this.avatarSize).height(this.avatarSize)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.avatarSize / 2)
      } else {
        Text(this.profileName.length > 0 ? this.profileName.substring(0, 1) : '学')
          .width(this.avatarSize).height(this.avatarSize)
          .fontSize(this.avatarSize * 0.38).fontWeight(FontWeight.Bold)
          .fontColor(Color.White).textAlign(TextAlign.Center)
          .backgroundColor('#5B5FEF').borderRadius(this.avatarSize / 2)
      }
    }
    .width(this.avatarSize).height(this.avatarSize)
    .border({ width: 2, color: Color.White })
    .borderRadius(this.avatarSize / 2)
    .shadow({ radius: 9, color: '#24000000', offsetY: 3 })
  }
}
