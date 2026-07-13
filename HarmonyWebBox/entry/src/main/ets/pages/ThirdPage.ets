import { NavTitleBar } from '../components/NavTitleBar';
import { LoadingOverlay } from '../components/LoadingOverlay';

@Component
export struct ThirdPage {
  pathStack: NavPathStack = new NavPathStack();
  @State isLoading: boolean = false;

  @Builder
  titleBuilder() {
    NavTitleBar({
      onRightClick1: () => {
        console.info('third page right button 1 clicked');
      },
      onRightClick2: () => {
        console.info('third page right button 2 clicked');
      }
    })
  }

  private simulateAsync(): void {
    this.isLoading = true;
    setTimeout(() => {
      this.isLoading = false;
    }, 3000);
  }

  build() {
    NavDestination() {
      // 用 Stack 包裹原内容，LoadingOverlay 在上层 → 不盖标题栏
      Stack() {
        Column() {
          Text('Third Page')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 32 })

          Button('返回')
            .fontSize(18)
            .width(200)
            .height(50)
            .onClick(() => {
              this.pathStack.pop();
            })

          Button('显示 Loading 3秒（不盖标题栏）')
            .fontSize(16)
            .width(280)
            .height(50)
            .backgroundColor('#00B42C')
            .margin({ top: 16 })
            .onClick(() => {
              this.simulateAsync();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        LoadingOverlay({ isLoading: this.isLoading, message: '加载中...' })
      }
      .width('100%')
      .height('100%')
    }
    .title(this.titleBuilder)
    .hideBackButton(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
