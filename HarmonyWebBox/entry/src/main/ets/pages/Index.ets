import { CoconutSDK, CoconutWebPage } from '@coconut/sdk';
import { DeviceComponent } from '../components/DeviceComponent';
import { EventComponent } from '../components/EventComponent';
import { StorageComponent } from '../components/StorageComponent';
import { VerifyDialog, VerifyDialogConfig } from '../components/VerifyDialog';
import { SecondPage } from './SecondPage';
import { ThirdPage } from './ThirdPage';
import { Routes } from './MyConstants';

@Entry
@Component
struct Index {
  @State showWebView: boolean = false;
  // private targetUrl: string = 'http://115.191.30.167:8032/dashboard';
  @State targetUrl: string = 'https://test-b-fat.pingan.com.cn/fb-offline/platform-workbench/green/workbench/business/menu/index.html#/';
  private readonly testPageUrl: string = 'resource://rawfile/coconut_index.html';

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
      new EventComponent()
    ]);
  }

  @Builder
  pageMap(name: string) {
    if (name === Routes.SECOND_PAGE) {
      SecondPage()
    } else if (name === Routes.THIRD_PAGE) {
      ThirdPage()
    }
  }

  build() {
    Navigation(this.navPathStack) {
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

            Button('Bridge 测试页')
              .fontSize(18)
              .width(200)
              .height(50)
              .backgroundColor('#00B42C')
              .margin({ top: 16 })
              .onClick(() => {
                this.targetUrl = this.testPageUrl;
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
      }
      .width('100%')
      .height('100%')
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
