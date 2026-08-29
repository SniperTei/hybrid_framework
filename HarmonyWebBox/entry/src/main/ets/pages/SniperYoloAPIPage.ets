import { HttpClient, HttpConfig, HttpMethod, RequestOptions, HttpError } from '@coconut/network';
import { HttpResponse } from '@coconut/network';
import { router } from '@kit.ArkUI';

/**
 * Sniper YOLO API 冒烟（Native）— @coconut/network 引擎 ArkTS 直调演示，
 * 对标 Android SniperYoloAPIActivity / iOS SniperYoloAPIViewController。
 * 与 WebView / bridge 全链路（NetworkComponent）互补：这里验证的是引擎
 * 作为独立 HAR 在纯 native 消费者场景下的表现（native-first 用法，同热更新下载）。
 *
 * base URL 默认 127.0.0.1：模拟器不共享 Mac loopback，需先建 hdc 反向转发
 * （hdc rport tcp:8041 tcp:8041，设备 localhost:8041 → Mac:8041），
 * 或改填 Mac 局域网 IP 直连。
 */
@Entry
@Component
struct SniperYoloAPIPage {
  private readonly defaultBase: string = 'http://127.0.0.1:8041/api/v1';
  private readonly timeoutMs: number = 15000;
  private client: HttpClient = new HttpClient(new HttpConfig());
  private token: string = '';
  private createdFoodId: string = '';
  private scroller: Scroller = new Scroller();

  @State baseUrl: string = 'http://127.0.0.1:8041/api/v1';
  @State logText: string = '（日志区）';
  @State running: boolean = false;

  // ---- 5 步冒烟（与 H5 版 net_driver / Android 语义一致）----

  private async stepLogin(): Promise<HttpResponse<Object> | null> {
    const resp = await this.exec('POST /users/test-login', `${this.base()}/users/test-login`,
      { method: HttpMethod.POST, connectTimeout: this.timeoutMs, readTimeout: this.timeoutMs });
    this.token = this.extractStringField(resp, 'access_token');
    this.appendLog(this.token.length > 0 ? '✓ token 已保存（后续请求自动带 Bearer）' : '⚠ 未取到 access_token');
    return resp;
  }

  private async stepListFoods(): Promise<HttpResponse<Object> | null> {
    return this.exec('GET /foods/?count=5', `${this.base()}/foods/`,
      {
        method: HttpMethod.GET, headers: this.authHeaders(), params: { 'count': '5' },
        connectTimeout: this.timeoutMs, readTimeout: this.timeoutMs
      });
  }

  private async stepCreateFood(): Promise<HttpResponse<Object> | null> {
    const body: Record<string, Object> = {
      'title': `native-demo-${Date.now()}`,
      'maker': 'coconut',
      'star': 4
    };
    const resp = await this.exec('POST /foods/', `${this.base()}/foods/`,
      { method: HttpMethod.POST, headers: this.authHeaders(), body: body,
        connectTimeout: this.timeoutMs, readTimeout: this.timeoutMs });
    this.createdFoodId = this.extractIdField(resp);
    this.appendLog(this.createdFoodId.length > 0
      ? `✓ 已记录新id=${this.createdFoodId}（按钮5可清理）` : '⚠ 未取到新 id');
    return resp;
  }

  private async stepGet404(): Promise<HttpResponse<Object> | null> {
    const resp = await this.exec('GET /foods/99999', `${this.base()}/foods/99999`,
      { method: HttpMethod.GET, headers: this.authHeaders(),
        connectTimeout: this.timeoutMs, readTimeout: this.timeoutMs });
    if (resp !== null) {
      this.appendLog(!resp.isSuccess()
        ? `✓ 404 业务失败 envelope 正常（code=${resp.code}）` : '✗ 预期业务失败，实际成功了？');
    }
    return resp;
  }

  private async stepDeleteFood(): Promise<HttpResponse<Object> | null> {
    if (this.createdFoodId.length === 0) {
      this.appendLog('跳过：没有待清理的记录（先跑第 3 步创建）');
      return null;
    }
    const id = this.createdFoodId;
    const resp = await this.exec(`DELETE /foods/${id}`, `${this.base()}/foods/${id}`,
      { method: HttpMethod.DELETE, headers: this.authHeaders(),
        connectTimeout: this.timeoutMs, readTimeout: this.timeoutMs });
    if (resp !== null && resp.isSuccess()) {
      this.createdFoodId = '';
      this.appendLog(`✓ 已清理 id=${id}`);
    }
    return resp;
  }

  private async runAll(): Promise<void> {
    // 传输层失败（exec 返回 null）即短路，与 Android/iOS 一致
    if (await this.stepLogin() === null) {
      return;
    }
    if (await this.stepListFoods() === null) {
      return;
    }
    if (await this.stepCreateFood() === null) {
      return;
    }
    if (await this.stepGet404() === null) {
      return;
    }
    await this.stepDeleteFood();
    this.appendLog('—— 全部 5 步完成 ——');
  }

  // ---- 基础设施 ----

  private base(): string {
    return this.baseUrl.trim().length > 0 ? this.baseUrl.trim() : this.defaultBase;
  }

  /** 统一执行 + 日志渲染；传输层失败返回 null（runAll 借此短路） */
  private async exec(label: string, url: string, options: RequestOptions):
    Promise<HttpResponse<Object> | null> {
    this.appendLog(`→ ${label}`);
    const resp = await this.client.request<Object>(url, options);
    if (HttpError.isNetworkError(parseInt(resp.code))) {
      this.appendLog(`✗ 网络异常: ${resp.msg}`);
      return null;
    }
    this.appendLog(`← HTTP ${resp.httpStatus} · code=${resp.code} · ${resp.costTime}ms`);
    this.appendLog(resp.data !== null ? JSON.stringify(resp.data, null, 2) : 'null');
    if (!resp.isSuccess()) {
      this.appendLog(`msg: ${resp.msg}`);
    }
    return resp;
  }

  /** 从 envelope data 里取字符串字段（缺失返回 ''） */
  private extractStringField(resp: HttpResponse<Object> | null, key: string): string {
    if (resp === null || resp.data === null) {
      return '';
    }
    const rec: Record<string, Object> = resp.data as Record<string, Object>;
    const v: Object | undefined = rec[key];
    if (v !== undefined && typeof v === 'string') {
      return v as string;
    }
    return '';
  }

  /** 从 envelope data 里取 id 字段（数字/字符串都转成字符串，缺失返回 ''） */
  private extractIdField(resp: HttpResponse<Object> | null): string {
    if (resp === null || resp.data === null) {
      return '';
    }
    const rec: Record<string, Object> = resp.data as Record<string, Object>;
    const v: Object | undefined = rec['id'];
    if (v !== undefined) {
      return `${v}`;
    }
    return '';
  }

  private authHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    if (this.token.length > 0) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }

  private appendLog(line: string): void {
    if (this.logText === '（日志区）') {
      this.logText = '';
    }
    this.logText += `${line}\n\n`;
  }

  private launch(block: () => Promise<void>): void {
    this.running = true;
    block().then(() => {
      this.running = false;
    }).catch((err: Error) => {
      this.running = false;
      this.appendLog(`✗ ${err.message}`);
    });
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题
      Row() {
        Button('‹ 返回')
          .fontSize(15)
          .backgroundColor('#F2F3F5')
          .fontColor('#333333')
          .onClick(() => {
            router.back();
          })
        Text('Sniper API 冒烟')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row()
          .width(76)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      TextInput({ text: this.baseUrl, placeholder: 'API base URL' })
        .fontSize(13)
        .width('100%')
        .height(40)
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.baseUrl = value;
        })

      Column() {
        Button('1 登录 (test-login)')
          .fontSize(15).width('100%').height(40).backgroundColor('#0095FF')
          .enabled(!this.running).margin({ top: 8 })
          .onClick(() => {
            this.launch(() => this.stepLogin().then(() => {}));
          })
        Button('2 列表 (foods?count=5)')
          .fontSize(15).width('100%').height(40).backgroundColor('#0095FF')
          .enabled(!this.running).margin({ top: 8 })
          .onClick(() => {
            this.launch(() => this.stepListFoods().then(() => {}));
          })
        Button('3 创建 food')
          .fontSize(15).width('100%').height(40).backgroundColor('#0095FF')
          .enabled(!this.running).margin({ top: 8 })
          .onClick(() => {
            this.launch(() => this.stepCreateFood().then(() => {}));
          })
        Button('4 GET 404 (envelope)')
          .fontSize(15).width('100%').height(40).backgroundColor('#0095FF')
          .enabled(!this.running).margin({ top: 8 })
          .onClick(() => {
            this.launch(() => this.stepGet404().then(() => {}));
          })
        Button('5 删除 food (清理)')
          .fontSize(15).width('100%').height(40).backgroundColor('#0095FF')
          .enabled(!this.running).margin({ top: 8 })
          .onClick(() => {
            this.launch(() => this.stepDeleteFood().then(() => {}));
          })
        Button('Run All (5 步)')
          .fontSize(15).width('100%').height(40).backgroundColor('#00B42C')
          .enabled(!this.running).margin({ top: 8 })
          .onClick(() => {
            this.launch(() => this.runAll());
          })
        Button('清空日志')
          .fontSize(15).width('100%').height(40).margin({ top: 8 })
          .onClick(() => {
            this.logText = '';
          })
      }
      .padding({ left: 16, right: 16 })

      // 日志区
      Scroll(this.scroller) {
        Text(this.logText)
          .fontSize(11)
          .fontFamily('monospace')
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding(8)
      }
      .scrollable(ScrollDirection.Vertical)
      .backgroundColor('#F2F3F5')
      .borderRadius(8)
      .layoutWeight(1)
      .width('100%')
      .margin({ left: 12, right: 12, top: 12, bottom: 12 })
      .onAreaChange(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
