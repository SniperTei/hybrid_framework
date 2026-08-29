import { BaseComponent, JsonObject, RemoteManifest, UpdateCheckResult, UpdateResult, CoconutUpdateManager } from '@coconut/sdk';

/**
 * Update Component — H5 热更新入口（app 层第 7 个组件）.
 *
 * - check({manifestUrl, moduleId?}): 查询更新服务器；manifest + 推导的
 *   baseUrl 缓存为组件内部状态，manifest 本身不透传 H5。
 * - apply({}): 无参复用 check 缓存；未 check 先 apply → 业务失败提示先检查。
 * - rollback({}): 回滚模块上一版本。
 * - version({}): 当前本地模块版本。
 *
 * 失败约定：manifestUrl 缺失 → bridge error 200007；更新服务器 / 状态机
 * 失败 → code 000000 + success:false（业务层，与权限拒绝约定一致）。
 *
 * 测试缝：manager 操作可注入（UpdateDeps），默认走 CoconutUpdateManager
 * 静态 API。
 */
export class UpdateComponent extends BaseComponent {
  name: string = 'update';
  version: string = '1.0.0';
  description: string = 'Hot update component (check/apply/rollback/version)';
  methods: string[] = ['check', 'apply', 'rollback', 'version'];

  private readonly deps: UpdateDeps;

  /** manager 操作注入面 — ohosTest 用假实现，不碰真机文件系统/网络 */
  private readonly defaultDeps: UpdateDeps = new UpdateDeps(
    (moduleId: string, manifestUrl: string): Promise<UpdateCheckResult> =>
      CoconutUpdateManager.checkUpdate(moduleId, manifestUrl),
    (manifest: RemoteManifest, baseUrl: string): Promise<UpdateResult> =>
      CoconutUpdateManager.performUpdate(manifest, baseUrl),
    (moduleId: string): Promise<boolean> => CoconutUpdateManager.rollback(moduleId),
    (moduleId: string): string => CoconutUpdateManager.currentVersion(moduleId),
  );

  constructor(deps?: UpdateDeps) {
    super();
    this.deps = deps ?? this.defaultDeps;
  }

  // ---- check 状态（manifest 不过桥）----
  private cachedManifest: RemoteManifest | null = null;
  private cachedBaseUrl: string = '';
  private moduleId: string = UpdateComponent.DEFAULT_MODULE_ID;

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'check':
        return this.checkHandler(paramsJson);
      case 'apply':
        return this.applyHandler();
      case 'rollback':
        return this.rollbackHandler();
      case 'version':
        return this.versionHandler();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async checkHandler(paramsJson: string): Promise<string> {
    const manifestUrl = this.getParam(paramsJson, 'manifestUrl');
    if (manifestUrl.length === 0) {
      return this.error('200007', 'manifestUrl is required');
    }
    const requestedModule = this.getParam(paramsJson, 'moduleId');
    if (requestedModule.length > 0) {
      this.moduleId = requestedModule;
    }

    const result = await this.deps.checkUpdate(this.moduleId, manifestUrl);
    if (result.error !== null) {
      return this.businessFailure(`check failed: ${result.error}`);
    }

    // 缓存供后续无参 apply。baseUrl = manifest URL 去掉最后一段路径
    //（逐文件 URL 相对它拼接）。
    if (result.available && result.manifest !== null) {
      this.cachedManifest = result.manifest;
      this.cachedBaseUrl = manifestUrl.substring(0, manifestUrl.lastIndexOf('/'));
    } else {
      this.cachedManifest = null;
    }

    const builder = new JsonObject();
    builder.putBool('available', result.available);
    builder.put('currentVersion', result.currentVersion);
    builder.put('remoteVersion', result.remoteVersion);
    return this.success(builder);
  }

  private async applyHandler(): Promise<string> {
    const manifest = this.cachedManifest;
    if (manifest === null) {
      return this.businessFailure('no update available — call check first');
    }
    const result = await this.deps.performUpdate(manifest, this.cachedBaseUrl);
    if (!result.success) {
      return this.businessFailure(result.error ?? 'apply failed');
    }
    const builder = new JsonObject();
    builder.putBool('success', true);
    builder.put('moduleId', result.moduleId);
    builder.put('version', result.version);
    return this.success(builder);
  }

  private async rollbackHandler(): Promise<string> {
    const ok = await this.deps.rollback(this.moduleId);
    if (!ok) {
      return this.businessFailure('nothing to roll back');
    }
    const builder = new JsonObject();
    builder.putBool('success', true);
    builder.put('version', this.deps.localVersion(this.moduleId));
    return this.success(builder);
  }

  private versionHandler(): string {
    const builder = new JsonObject();
    builder.put('version', this.deps.localVersion(this.moduleId));
    return this.success(builder);
  }

  private businessFailure(message: string): string {
    const builder = new JsonObject();
    builder.putBool('success', false);
    builder.put('message', message);
    return this.success(builder);
  }

  static readonly DEFAULT_MODULE_ID: string = 'demo';
}

/** manager 操作四件套 — 注入缝 */
export class UpdateDeps {
  readonly checkUpdate: (moduleId: string, manifestUrl: string) => Promise<UpdateCheckResult>;
  readonly performUpdate: (manifest: RemoteManifest, baseUrl: string) => Promise<UpdateResult>;
  readonly rollback: (moduleId: string) => Promise<boolean>;
  readonly localVersion: (moduleId: string) => string;

  constructor(
    checkUpdate: (moduleId: string, manifestUrl: string) => Promise<UpdateCheckResult>,
    performUpdate: (manifest: RemoteManifest, baseUrl: string) => Promise<UpdateResult>,
    rollback: (moduleId: string) => Promise<boolean>,
    localVersion: (moduleId: string) => string,
  ) {
    this.checkUpdate = checkUpdate;
    this.performUpdate = performUpdate;
    this.rollback = rollback;
    this.localVersion = localVersion;
  }
}
