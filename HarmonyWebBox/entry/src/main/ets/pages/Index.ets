import { CoconutSDK, CoconutWebPage } from '@coconut/sdk';
import { DeviceComponent } from '@coconut/sdk';
import { StorageComponent } from '@coconut/sdk';
import { SystemComponent } from '@coconut/sdk';
import { NetworkComponent } from '@coconut/sdk';
import { DialogComponent } from '@coconut/sdk';
import { SecurityComponent } from '@coconut/sdk';
import { PerformanceComponent } from '@coconut/sdk';
import { PermissionComponent } from '@coconut/sdk';
import { RouterComponent } from '@coconut/sdk';
import { StackComponent } from '@coconut/sdk';
import { ClipboardComponent } from '@coconut/sdk';
import { ResourceComponent } from '@coconut/sdk';
import { VerifyDialog, VerifyDialogConfig } from '@coconut/sdk';

@Entry
@Component
struct Index {
  @State showWebView: boolean = false;
  // private targetUrl: string = 'http://115.191.30.167:8032/dashboard';
  private targetUrl: string = 'https://test-b-fat.pingan.com.cn/fb-offline/platform-workbench/green/workbench/business/menu/index.html#/';

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
      new SystemComponent(),
      new NetworkComponent(),
      new DialogComponent(),
      new SecurityComponent(),
      new PerformanceComponent(),
      new PermissionComponent(),
      new RouterComponent(),
      new StackComponent(),
      new ClipboardComponent(),
      new ResourceComponent()
    ]);
  }

  build() {
    Column() {
      if (this.showWebView) {
        CoconutWebPage({ url: this.targetUrl })
      } else {
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
              this.showWebView = true;
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
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
