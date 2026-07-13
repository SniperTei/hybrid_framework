/**
 * 通用导航栏标题组件
 *
 * 布局：左侧一张图 + 右侧最多两张图。
 * 各页面通过 NavDestination 的 .title(this.xxxBuilder) 挂载。
 *
 * 交互规则：
 *   - 所有图标默认启用 hoverEffect（按下轻微缩放 + 透明度变化）
 *   - 视觉反馈与是否挂回调解耦——按下就反馈，不管点完有没有动作
 *
 * 使用示例：
 *   @Builder
 *   titleBuilder() {
 *     NavTitleBar({
 *       leftImage: $r('app.media.logo'),       // 静态，无回调 → 不响应
 *       rightImage1: $r('app.media.icon_setting'),
 *       onRightClick1: () => { this.openSettings(); },   // 有回调 → 有反馈
 *       showRightImage2: false
 *     })
 *   }
 */

export interface NavTitleBarOptions {
  leftImage?: Resource;
  rightImage1?: Resource;
  rightImage2?: Resource;
  /** 是否显示左图，默认 true */
  showLeftImage?: boolean;
  /** 是否显示右一图，默认 true */
  showRightImage1?: boolean;
  /** 是否显示右二图，默认 true */
  showRightImage2?: boolean;
  /** 左图点击；传了才有 hover 反馈 */
  onLeftClick?: () => void;
  /** 右一图点击；传了才有 hover 反馈 */
  onRightClick1?: () => void;
  /** 右二图点击；传了才有 hover 反馈 */
  onRightClick2?: () => void;
}

@Styles
function normalStyle() {
  .opacity(1.0)
}

@Styles
function pressedStyle() {
  .opacity(0.5)
}

@Builder
export function NavTitleBar(options: NavTitleBarOptions) {
  Row() {
    // 左侧
    Image(options.leftImage ?? $r('app.media.startIcon'))
      .width(28)
      .height(28)
      .objectFit(ImageFit.Contain)
      .visibility(options.showLeftImage === false ? Visibility.None : Visibility.Visible)
      .hoverEffect(HoverEffect.Scale)
      .stateStyles({ normal: normalStyle, pressed: pressedStyle })
      .onClick(() => {
        if (options.onLeftClick) {
          options.onLeftClick();
        }
      })

    // 中间撑开
    Blank()

    // 右侧第一个
    Image(options.rightImage1 ?? $r('app.media.startIcon'))
      .width(24)
      .height(24)
      .margin({ right: 16 })
      .visibility(options.showRightImage1 === false ? Visibility.None : Visibility.Visible)
      .hoverEffect(HoverEffect.Scale)
      .stateStyles({ normal: normalStyle, pressed: pressedStyle })
      .onClick(() => {
        if (options.onRightClick1) {
          options.onRightClick1();
        }
      })

    // 右侧第二个
    Image(options.rightImage2 ?? $r('app.media.startIcon'))
      .width(24)
      .height(24)
      .visibility(options.showRightImage2 === false ? Visibility.None : Visibility.Visible)
      .hoverEffect(HoverEffect.Scale)
      .stateStyles({ normal: normalStyle, pressed: pressedStyle })
      .onClick(() => {
        if (options.onRightClick2) {
          options.onRightClick2();
        }
      })
  }
  .width('100%')
  .height('100%')
  .padding({ left: 16, right: 16 })
}
