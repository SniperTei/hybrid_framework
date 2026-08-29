import { CoconutSDK } from '@coconut/sdk';
import { router } from '@kit.ArkUI';
import { DeviceComponent } from '../components/DeviceComponent';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    // 显式注册组件（消费者按 API_CONTRACT 自行扩展）
    CoconutSDK.registerComponents([new DeviceComponent()]);
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
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
