/**
 * 全屏 Loading 遮罩组件
 *
 * ## 模式一：Stack 内覆盖（仅盖内容区，不盖标题栏）
 *
 *   NavDestination() {
 *     Stack() {
 *       Column() { /* 内容 *\/ }
 *       LoadingOverlay({ isLoading: this.isLoading, message: '加载中' })
 *     }
 *   }
 *
 * ## 模式二：bindContentCover（盖住标题栏，全屏覆盖）
 *
 *   @Builder
 *   loadingBuilder() {
 *     LoadingOverlay({ isLoading: true, message: '加载中' })
 *   }
 *
 *   NavDestination() {
 *     // 内容不需要 Stack 包裹
 *   }
 *   .bindContentCover(this.isLoading, this.loadingBuilder)
 *
 * 模式二中 LoadingOverlay 的 isLoading 写死 true，
 * 因为显示/隐藏由 bindContentCover 的第一个参数控制，
 * LoadingOverlay 自己不用再判。
 */

@Component
export struct LoadingOverlay {
  /** 是否显示 loading */
  @Prop isLoading: boolean = false;
  /** 提示文字；空串则只显示 spinner */
  @Prop message: string = '';
  /** 遮罩背景色，默认半透明黑 */
  @Prop maskColor: ResourceColor = '#66000000';
  /** 卡片背景色 */
  @Prop cardColor: ResourceColor = 'rgba(0,0,0,0.8)';
  /** spinner 颜色 */
  @Prop spinnerColor: ResourceColor = '#FFFFFF';
  /** 文字颜色 */
  @Prop textColor: ResourceColor = '#FFFFFF';

  build() {
    if (this.isLoading) {
      Stack() {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(this.spinnerColor)

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(14)
              .fontColor(this.textColor)
              .margin({ top: 12 })
          }
        }
        .padding(24)
        .backgroundColor(this.cardColor)
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.maskColor)
      .alignContent(Alignment.Center)
    }
  }
}
