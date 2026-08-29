import { CoconutSDK, CoconutUpdateManager } from '@coconut/sdk';
import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DeviceComponent } from '../components/DeviceComponent';
import { DialogComponent } from '../components/DialogComponent';
import { EventComponent } from '../components/EventComponent';
import { NetworkComponent } from '../components/NetworkComponent';
import { NavigatorComponent } from '../components/NavigatorComponent';
import { StorageComponent } from '../components/StorageComponent';
import { UpdateComponent } from '../components/UpdateComponent';
import { TemplateRegistry } from '../components/TemplateRegistry';
import { VerifyDialog, VerifyDialogConfig } from '../components/VerifyDialog';
import { SecondPage } from './SecondPage';
import { ThirdPage } from './ThirdPage';
import { Routes } from './MyConstants';

@Entry
@Component
struct Index {
  private readonly targetUrl: string = 'https://test-b-fat.pingan.com.cn/fb-offline/platform-workbench/green/workbench/business/menu/index.html#/';
  private readonly testPageUrl: string = 'resource://rawfile/coconut_index.html';
  // ⚠️ dev server URL：模拟器不共享 Mac loopback（局域网 IP 也常 unreachable），
  //    用 127.0.0.1 + hdc 反向转发：hdc rport tcp:5174 tcp:5174
  //    （设备 localhost:5174 → Mac:5174，不依赖局域网 IP）
  private readonly devServerUrl: string = 'http://127.0.0.1:5174/';
  private readonly offlinePackageUrl: string = 'coconut://demo/index.html';
  // 热更新 manifest URL：127.0.0.1 需先建 hdc 反向转发（hdc rport tcp:8000 tcp:8000，
  // 设备 localhost:8000 → Mac:8000，不依赖局域网 IP）；或改为 Mac 局域网 IP 直连
  // （scripts/serve-hot-update.sh 默认起在 8000 端口）
  @State manifestUrl: string = 'http://127.0.0.1:8000/manifest.json';

  private navPathStack: NavPathStack = new NavPathStack();

  dialogController: CustomDialogController = new CustomDialogController({
    builder: VerifyDialog({
      onUmVerify: (account: string, password: string) => {
        this.dialogController.close();
        // Handle UM verification
      },
      onFaceVerify: () => {
        this.dialogController.close();
        // Handle face verification
      }
    }),
    alignment: DialogAlignment.Center,
    customStyle: true,
    backgroundColor: Color.Transparent
  });

  aboutToAppear(): void {
    // Register all components
    CoconutSDK.registerComponents([
      new DeviceComponent(),
      new StorageComponent(),
      new EventComponent(),
      new DialogComponent(),
      new NetworkComponent(),
      new NavigatorComponent(),
      new UpdateComponent()
    ]);
    // Eager template registry validation (JSON parse + path non-empty +
    // duplicate names) — surface config errors at startup, not first
    // forward. Shallow check only: main_pages registration of each page
    // is a documented host contract (crashes at pushUrl if missing).
    const templates = TemplateRegistry.load(getContext(this) as common.UIAbilityContext);
    console.info(`[Index] coconut templates loaded: ${templates.size}`);
  }

  private async checkHotUpdate(): Promise<void> {
    const check = await CoconutUpdateManager.checkUpdate('demo', this.manifestUrl);
    if (check.error !== null) {
      promptAction.showToast({ message: `检查失败: ${check.error}`, duration: 3000 });
      return;
    }
    if (!check.available || check.manifest === null) {
      promptAction.showToast({ message: `无更新，当前版本 ${check.currentVersion}` });
      return;
    }
    const baseUrl = this.manifestUrl.substring(0, this.manifestUrl.lastIndexOf('/'));
    const result = await CoconutUpdateManager.performUpdate(check.manifest, baseUrl);
    if (result.success) {
      promptAction.showToast({ message: `更新成功: ${check.currentVersion} → ${result.version}`, duration: 3000 });
    } else {
      promptAction.showToast({ message: `更新失败: ${result.error ?? 'unknown'}`, duration: 3000 });
    }
  }

  private async rollbackHotUpdate(): Promise<void> {
    const ok = await CoconutUpdateManager.rollback('demo');
    if (ok) {
      const version = CoconutUpdateManager.currentVersion('demo');
      promptAction.showToast({ message: `已回滚，内置版本 ${version}`, duration: 3000 });
    } else {
      promptAction.showToast({ message: '回滚失败，见日志', duration: 3000 });
    }
  }

  @Builder
  pageMap(name: string) {
    if (name === Routes.SECOND_PAGE) {
      SecondPage()
    } else if (name === Routes.THIRD_PAGE) {
      ThirdPage()
    }
  }

  /**
   * Open the standard container route page (v3.5.0 container-nav).
   * Optional header: NavConfig override JSON, e.g.
   * '{"title":"订单详情","closePolicy":"always"}'.
   */
  private openContainer(url: string, header?: string): void {
    const params: Record<string, string> = header !== undefined
      ? { 'url': url, 'header': header }
      : { 'url': url };
    router.pushUrl({ url: 'pages/WebContainer', params: params });
  }

  build() {
    Navigation(this.navPathStack) {
      Column() {
        Column() {
          Text('Coconut SDK Demo')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 32 })

          Button('打开 webview')
            .fontSize(18)
            .width(200)
            .height(50)
            .onClick(() => {
              this.openContainer(this.targetUrl);
            })

          Button('Bridge 测试页')
            .fontSize(18)
            .width(200)
            .height(50)
            .backgroundColor('#00B42C')
            .margin({ top: 16 })
            .onClick(() => {
              this.openContainer(this.testPageUrl);
            })

          // 对标 iOS/Android 的「打开本地测试页面」入口 —— load Vite dev server
          Button('打开本地测试页面 (dev)')
            .fontSize(18)
            .width(200)
            .height(50)
            .backgroundColor('#722ED1')
            .margin({ top: 16 })
            .onClick(() => {
              this.openContainer(this.devServerUrl);
            })

          // 离线包：coconut:// 统一入口（CoconutWebPage 内部翻译 + 拦截服务，
          // 不依赖 dev server / 局域网 IP）
          Button('打开离线包 (coconut://)')
            .fontSize(18)
            .width(200)
            .height(50)
            .backgroundColor('#F53F3F')
            .margin({ top: 16 })
            .onClick(() => {
              this.openContainer(this.offlinePackageUrl);
            })

          // 模板容器（coconut.navigator.forward({template:'demo'}) 的原生入口，
          // 页面本身注册在 coconut_templates.json）
          Button('打开模板容器 (demo)')
            .fontSize(18)
            .width(200)
            .height(50)
            .backgroundColor('#FF7D00')
            .margin({ top: 16 })
            .onClick(() => {
              const params: Record<string, string> = { 'url': this.offlinePackageUrl };
              router.pushUrl({ url: 'pages/DemoTemplatePage', params: params });
            })

            // Sniper YOLO API 冒烟（native 引擎直调，对标 Android/iOS）：
            // @coconut/network 纯 native 消费者场景验证，与 bridge 全链路互补
            Button('Sniper API 冒烟 (native)')
              .fontSize(18)
              .width(200)
              .height(50)
              .backgroundColor('#0095FF')
              .margin({ top: 16 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/SniperYoloAPIPage' });
              })

            // 设置页（真实业务试点：离线包 hash 路由 #/settings，对标 Android/iOS）
            Button('设置页 (#/settings)')
              .fontSize(18)
              .width(200)
              .height(50)
              .backgroundColor('#14C9C9')
              .margin({ top: 16 })
              .onClick(() => {
                this.openContainer(this.offlinePackageUrl + '#/settings');
              })

            // 热更新（对标 iOS/Android demo）：检查更新（可用则自动下载+应用）/ 回滚
            TextInput({ text: this.manifestUrl, placeholder: 'manifest URL' })
              .fontSize(14)
              .width(320)
              .height(44)
              .margin({ top: 24 })
              .onChange((value: string) => {
                this.manifestUrl = value;
              })

            Button('检查热更新')
              .fontSize(18)
              .width(200)
              .height(44)
              .backgroundColor('#0095FF')
              .margin({ top: 12 })
              .onClick(() => {
                this.checkHotUpdate();
              })

            Button('回滚到内置版本')
              .fontSize(18)
              .width(200)
              .height(44)
              .margin({ top: 8 })
              .onClick(() => {
                this.rollbackHotUpdate();
              })

            Button('人脸识别弹窗')
              .fontSize(18)
              .width(200)
              .height(50)
              .backgroundColor('#3370FF')
              .margin({ top: 16 })
              .onClick(() => {
                this.dialogController.open();
              })

            Button('跳转 SecondPage')
              .fontSize(18)
              .width(200)
              .height(50)
              .backgroundColor('#FF7D00')
              .margin({ top: 16 })
              .onClick(() => {
                this.navPathStack.pushPath({ name: Routes.SECOND_PAGE });
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
