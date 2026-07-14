import { common } from '@kit.AbilityKit';
import { window, ComponentContent, promptAction } from '@kit.ArkUI';

/**
 * PopupUtil
 *
 * 通用自定义弹窗工具。允许任意类（包括不含 UI 的 Bridge 组件）弹出任意自定义弹窗。
 *
 * 背景：
 *   Bridge 组件是普通 TS 类，拿不到 ArkUI 的 CustomDialogController（必须是 @Component 成员）。
 *   CameraComponent.showDialog() 已经走过这条路（UIContext + ComponentContent +
 *   PromptAction.openCustomDialog），把那段样板抽出来变成通用工具。
 *
 * 使用方式：
 *   1. 在 EntryAbility.onCreate 里调一次 PopupUtil.init(this.context)。
 *   2. 每个自定义弹窗在 components/popup/ 下独占一个文件，定义参数类 + @Builder +
 *      wrapBuilder + 一个 XxxPopup 门面类（内部调 PopupUtil.show）。
 *   3. 调用方 import { XxxPopup } 后 await XxxPopup.show(params)。
 *
 * 设计要点：
 *   - 不缓存 UIContext：UIContext 会随 window 重建（旋转 / 切前后台）失效，缓存就埋雷。
 *     每次 show 时重新 getLastWindow 再 getUIContext。这是 CameraComponent 现有做法。
 *   - 缓存 UIAbilityContext：app 进程内稳定，EntryAbility.onCreate 一次性 set。
 *   - dismiss 幂等：dismissed 标志防重入，finally 里 dispose 释放资源。
 */

/** 弹窗选项（透传给 promptAction.openCustomDialog）。 */
export class PopupOptions {
  alignment: DialogAlignment = DialogAlignment.Center;
  isModal: boolean = true;
  showInSubWindow: boolean = false;
  autoCancel: boolean = false;
}

/** 弹窗句柄：调用方拿它主动关闭弹窗。 */
export interface PopupHandle {
  dismiss(): Promise<void>;
}

/**
 * 内部 dismiss 实现（带 dismissed 标志位，闭包持有）。
 * 不直接复用 PopupHandle 接口的字面量，是为了满足 ArkTS 严格模式对类/接口的要求。
 */
class PopupHandleImpl implements PopupHandle {
  private dismissed: boolean = false;
  private readonly action: () => void;

  constructor(action: () => void) {
    this.action = action;
  }

  async dismiss(): Promise<void> {
    if (this.dismissed) {
      return;
    }
    this.dismissed = true;
    this.action();
  }
}

export class PopupUtil {
  private static abilityContext: common.UIAbilityContext | null = null;

  /**
   * 在 EntryAbility.onCreate 里调一次。
   */
  static init(context: common.UIAbilityContext): void {
    PopupUtil.abilityContext = context;
    console.info('[PopupUtil] initialized');
  }

  /**
   * 核心 API：传 builder 和参数，弹出来，返回 dismiss 句柄。
   *
   * 调用方一般不直接用，而是通过 XxxPopup.show(...) 门面调用。
   *
   * 注意 T 必须显式 extends Object：ComponentContent<T> 的类型参数有此约束。
   */
  static async show<T extends Object>(
    builder: WrappedBuilder<[T]>,
    params: T,
    options?: PopupOptions
  ): Promise<PopupHandle> {
    const ctx = PopupUtil.abilityContext;
    if (!ctx) {
      throw new Error(
        'PopupUtil not initialized; call PopupUtil.init(context) in EntryAbility.onCreate'
      );
    }

    // 每次现取 UIContext（UIContext 会随 window 重建变化，不能缓存）
    const win = await window.getLastWindow(ctx);
    const uiContext = win.getUIContext();

    const content: ComponentContent<T> = new ComponentContent<T>(uiContext, builder, params);

    const promptOptions: promptAction.BaseDialogOptions = {
      alignment: options?.alignment ?? DialogAlignment.Center,
      isModal: options?.isModal ?? true,
      showInSubWindow: options?.showInSubWindow ?? false,
      autoCancel: options?.autoCancel ?? false
    };

    try {
      await uiContext.getPromptAction().openCustomDialog(content, promptOptions);
    } catch (e) {
      content.dispose();
      // ArkTS 限制：throw 的必须是 Error 实例
      throw new Error(`PopupUtil.openCustomDialog failed: ${e}`);
    }

    return new PopupHandleImpl((): void => {
      try {
        uiContext.getPromptAction().closeCustomDialog(content);
      } catch (e) {
        console.error(`[PopupUtil] dismiss failed: ${e}`);
      } finally {
        content.dispose();
      }
    });
  }
}
