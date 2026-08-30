import { CoconutSDK } from '@coconut/sdk';
import { router } from '@kit.ArkUI';
import { DeviceComponent } from '../components/DeviceComponent';
import { StorageComponent } from '../components/StorageComponent';
import { EventComponent } from '../components/EventComponent';
import { DialogComponent } from '../components/DialogComponent';
import { NetworkComponent } from '../components/NetworkComponent';
import { NavigatorComponent } from '../components/NavigatorComponent';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    // 显式注册组件（消费者按 API_CONTRACT 自行扩展）。参考组件集从
    // HarmonyWebBox 拷入（update 不拷，H5 设置页正确显示未注册）——
    // 对齐 Android/iOS RealApp 的六组件注册。
    CoconutSDK.registerComponents([
      new DeviceComponent(),
      new StorageComponent(),
      new EventComponent(),
      new DialogComponent(),
      new NetworkComponent(),
      new NavigatorComponent()
    ]);
  }

  build() {
    Column({ space: 16 }) {
      Text('CoconutHarmonyApp')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 80 })

      Button('打开 Coconut 容器')
        .width('80%')
        .height(48)
        .fontSize(16)
        .onClick(() => {
          // H5 三件套随 rawfile 打包
          router.pushUrl({
            url: 'pages/WebContainer',
            params: { 'url': 'resource://rawfile/coconut_index.html' }
          });
        })

      // H5 App（真实业务试点 Phase 4）：离线包模块 h5app 随宿主 rawfile
      // 自带（build-offline-package.sh 分发），coconut:// 走 SDK 本地服务
      Button('H5 App (4 tab)')
        .width('80%')
        .height(48)
        .fontSize(16)
        .onClick(() => {
          router.pushUrl({
            url: 'pages/WebContainer',
            params: { 'url': 'coconut://h5app/index.html' }
          });
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
