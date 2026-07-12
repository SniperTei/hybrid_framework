/**
 * Verify Dialog Config
 *
 * Configuration for VerifyDialog.
 */
export class VerifyDialogConfig {
  title: string = '身份验证';
  umLabel: string = 'UM验证';
  faceLabel: string = '人脸识别';
  umPlaceholder: string = '请输入UM账号';
  passwordPlaceholder: string = '请输入密码';
  umButtonText: string = '验证';
  faceButtonText: string = '开始识别';
  faceDescription: string = '为了您的账户安全，请完成人脸识别';
  defaultTab: number = 0;
  /**
   * "Y" = show both UM verification and face recognition tabs
   * "N" or empty = show only face recognition (no tabs)
   */
  passwordFlag: string = 'N';
}

/**
 * Verify Dialog
 *
 * Reusable dialog with tab switching between password verification
 * and face recognition.
 *
 * Usage:
 * ```
 * // Both UM + face (passwordFlag = "Y")
 * let config = new VerifyDialogConfig();
 * config.passwordFlag = 'Y';
 *
 * // Only face (passwordFlag = "N")
 * config.passwordFlag = 'N';
 *
 * dialogController = new CustomDialogController({
 *   builder: VerifyDialog({
 *     config: config,
 *     onUmVerify: (account: string, password: string) => { ... },
 *     onFaceVerify: () => { ... }
 *   }),
 *   alignment: DialogAlignment.Center,
 *   customStyle: true,
 *   backgroundColor: Color.Transparent
 * })
 * ```
 */
@CustomDialog
@Component
export struct VerifyDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: VerifyDialog() });
  config: VerifyDialogConfig = new VerifyDialogConfig();
  onUmVerify: (account: string, password: string) => void = (_account: string, _password: string) => {};
  onFaceVerify: () => void = () => {};

  @State private currentTab: number = 0;
  @State private umAccount: string = '';
  @State private umPassword: string = '';

  private showPasswordTab(): boolean {
    return this.config.passwordFlag === 'Y';
  }

  aboutToAppear(): void {
    if (this.showPasswordTab()) {
      this.currentTab = this.config.defaultTab;
    } else {
      this.currentTab = 1;
    }
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Text(this.config.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2129')

        Blank()

        Stack() {
          Text('✕')
            .fontSize(14)
            .fontColor('#86909C')
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('#F2F3F5')
        .alignContent(Alignment.Center)
        .onClick(() => {
          this.controller.close();
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24 })

      // Tab bar - only show when passwordFlag is Y
      if (this.showPasswordTab()) {
        Row() {
          Column() {
            Text(this.config.umLabel)
              .fontSize(15)
              .fontColor(this.currentTab === 0 ? '#3370FF' : '#86909C')
              .fontWeight(this.currentTab === 0 ? FontWeight.Bold : FontWeight.Normal)
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.currentTab === 0 ? '#EBF3FF' : Color.Transparent)
          .onClick(() => {
            this.currentTab = 0;
          })

          Blank()
            .width(12)

          Column() {
            Text(this.config.faceLabel)
              .fontSize(15)
              .fontColor(this.currentTab === 1 ? '#3370FF' : '#86909C')
              .fontWeight(this.currentTab === 1 ? FontWeight.Bold : FontWeight.Normal)
          }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .borderRadius(8)
          .backgroundColor(this.currentTab === 1 ? '#EBF3FF' : Color.Transparent)
          .onClick(() => {
            this.currentTab = 1;
          })
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .margin({ top: 16 })
        .backgroundColor('#F7F8FA')
        .borderRadius(8)
      }

      // Tab content
      if (this.currentTab === 0) {
        this.UmVerifyContent()
      } else {
        this.FaceVerifyContent()
      }

      // Action button
      Button(!this.showPasswordTab() || this.currentTab === 1 ? this.config.faceButtonText : this.config.umButtonText)
        .width('100%')
        .height(48)
        .backgroundColor('#3370FF')
        .borderRadius(24)
        .fontSize(16)
        .fontColor(Color.White)
        .margin({ left: 24, right: 24, bottom: 24, top: 24 })
        .onClick(() => {
          if (this.showPasswordTab() && this.currentTab === 0) {
            this.onUmVerify(this.umAccount, this.umPassword);
          } else {
            this.onFaceVerify();
          }
        })
    }
    .width('85%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  UmVerifyContent() {
    Column() {
      Column() {
        Text('UM账号')
          .fontSize(12)
          .fontColor('#86909C')
          .margin({ bottom: 6 })
        TextInput({ placeholder: this.config.umPlaceholder, text: this.umAccount })
          .height(44)
          .fontSize(14)
          .fontColor('#1D2129')
          .placeholderColor('#C9CDD4')
          .backgroundColor('#F7F8FA')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.umAccount = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 20 })

      Column() {
        Text('密码')
          .fontSize(12)
          .fontColor('#86909C')
          .margin({ bottom: 6 })
        TextInput({ placeholder: this.config.passwordPlaceholder, text: this.umPassword })
          .height(44)
          .fontSize(14)
          .fontColor('#1D2129')
          .placeholderColor('#C9CDD4')
          .backgroundColor('#F7F8FA')
          .borderRadius(8)
          .type(InputType.Password)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.umPassword = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 16 })
    }
    .padding({ left: 24, right: 24 })
  }

  @Builder
  FaceVerifyContent() {
    Column() {
      Text(this.config.faceDescription)
        .fontSize(14)
        .fontColor('#86909C')
        .margin({ top: 24 })

      Stack() {
        Circle({ width: 140, height: 140 })
          .fill('#EBF3FF')
          .stroke('#3370FF')
          .strokeWidth(3)

        Circle({ width: 44, height: 44 })
          .fill('#3370FF')
          .opacity(0.25)

        Circle({ width: 72, height: 36 })
          .fill('#3370FF')
          .opacity(0.15)
          .position({ x: '50%', y: '72%' })
          .translate({ x: '-50%', y: '-50%' })
      }
      .width(140)
      .height(140)
      .margin({ top: 28 })
    }
    .alignItems(HorizontalAlign.Center)
  }
}
