import { Index } from './Index';

@Entry
@Component
struct AppRoot {
  private contentBack: () => boolean = () => false;

  onBackPress(): boolean {
    return this.contentBack();
  }

  build() {
    Stack() {
      Index({
        onRegisterBack: (handler: () => boolean) => {
          this.contentBack = handler;
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
