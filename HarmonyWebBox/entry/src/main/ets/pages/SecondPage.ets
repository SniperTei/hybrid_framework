import { Routes } from './MyConstants';
import { NavTitleBar } from '../components/NavTitleBar';
import { LoadingOverlay } from '../components/LoadingOverlay';

@Component
export struct SecondPage {
  pathStack: NavPathStack = new NavPathStack();
  @State isLoading: boolean = false;

  @Builder
  titleBuilder() {
    NavTitleBar({
      onRightClick1: () => {
        console.info('second page right button 1 clicked');
      },
      onRightClick2: () => {
        console.info('second page right button 2 clicked');
      }
    })
  }

  /** 给 bindContentCover 用的全屏 loading builder */
  @Builder
  loadingBuilder() {
    LoadingOverlay({ isLoading: true, message: '加载中...' })
  }

  private simulateAsync(): void {
    this.isLoading = true;
    setTimeout(() => {
      this.isLoading = false;
    }, 3000);
  }

  build() {
    NavDestination() {
      Column() {
        Text('Second Page')
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

        Button('跳转 ThirdPage')
          .fontSize(18)
          .width(200)
          .height(50)
          .backgroundColor('#FF7D00')
          .margin({ top: 16 })
          .onClick(() => {
            this.pathStack.pushPath({ name: Routes.THIRD_PAGE });
          })

        Button('显示 Loading 3秒')
          .fontSize(18)
          .width(200)
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
    }
    .title(this.titleBuilder)
    .hideBackButton(true)
    .bindContentCover(this.isLoading, this.loadingBuilder)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}
