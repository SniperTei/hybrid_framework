import { describe, it, expect } from '@ohos/hypium';
import { ComponentException, JsonParser, RemoteManifest, UpdateCheckResult, UpdateResult } from '@coconut/sdk';
import { UpdateComponent, UpdateDeps } from '../../../../../main/ets/components/UpdateComponent';

/**
 * UpdateComponent state machine tests — all manager ops injected via
 * UpdateDeps fakes (no network / filesystem).
 *
 * Conventions asserted: manifestUrl 缺失 → ComponentException 200007；
 * 更新服务器 / 状态机失败 → 业务层 success:false（manifest 不透传 H5，
 * apply 无参复用 check 缓存）。
 */

let rec: UpdateRecorder;

/** manager 操作录制器 — 注入假实现，记录透传参数 */
class UpdateRecorder extends UpdateDeps {
  public lastManifest: RemoteManifest | null = null;
  public lastBaseUrl: string = '';
  public lastRollbackModule: string = '';
  public checkToReturn: UpdateCheckResult = availableCheck();
  public performToReturn: UpdateResult = okResult('2.0.0');
  public rollbackToReturn: boolean = true;
  public localVersionToReturn: string = '1.0.0';

  constructor() {
    super(
      (moduleId: string, manifestUrl: string): Promise<UpdateCheckResult> =>
        Promise.resolve(rec.checkToReturn),
      (manifest: RemoteManifest, baseUrl: string): Promise<UpdateResult> => {
        rec.lastManifest = manifest;
        rec.lastBaseUrl = baseUrl;
        return Promise.resolve(rec.performToReturn);
      },
      (moduleId: string): Promise<boolean> => {
        rec.lastRollbackModule = moduleId;
        return Promise.resolve(rec.rollbackToReturn);
      },
      (moduleId: string): string => rec.localVersionToReturn,
    );
    rec = this;
  }
}

function manifest(version: string): RemoteManifest {
  const m = new RemoteManifest();
  m.moduleId = 'demo';
  m.version = version;
  m.entry = 'index.html';
  m.files = ['index.html'];
  return m;
}

function availableCheck(): UpdateCheckResult {
  const result = new UpdateCheckResult();
  result.available = true;
  result.currentVersion = '1.0.0';
  result.remoteVersion = '2.0.0';
  result.manifest = manifest('9.9.9');
  result.error = null;
  return result;
}

function okResult(version: string): UpdateResult {
  const r = new UpdateResult();
  r.success = true;
  r.moduleId = 'demo';
  r.version = version;
  r.error = null;
  return r;
}

async function expectError(fn: () => Promise<string>, code: string): Promise<void> {
  let thrown: Object | null = null;
  try {
    await fn();
  } catch (e) {
    thrown = e as Object;
  }
  expect(thrown instanceof ComponentException).assertTrue();
  expect((thrown as ComponentException).code).assertEqual(code);
}

function msgContains(json: string, key: string, needle: string): void {
  expect(JsonParser.getString(json, key).indexOf(needle) >= 0).assertTrue();
}

export default function updateComponentTest() {
  describe('UpdateComponent', () => {

    it('meta_nameAndMethods', 0, () => {
      const comp = new UpdateComponent();
      expect(comp.name).assertEqual('update');
      expect(comp.methods.join(',')).assertEqual('check,apply,rollback,version');
    });

    it('unknownFunction_throws200002', 0, async () => {
      const comp = new UpdateComponent();
      await expectError(() => comp.handle('reboot', '{}'), '200002');
    });

    it('missingManifestUrl_throws200007', 0, async () => {
      const comp = new UpdateComponent();
      await expectError(() => comp.handle('check', '{}'), '200007');
    });

    it('checkAvailable_returnsVersions', 0, async () => {
      rec = new UpdateRecorder();
      const comp = new UpdateComponent(rec);
      const json = await comp.handle('check', '{"manifestUrl":"http://host:8000/manifest.json"}');
      expect(JsonParser.getBool(json, 'available')).assertTrue();
      expect(JsonParser.getString(json, 'currentVersion')).assertEqual('1.0.0');
      expect(JsonParser.getString(json, 'remoteVersion')).assertEqual('2.0.0');
    });

    it('apply_reusesCachedManifestAndBaseUrl', 0, async () => {
      rec = new UpdateRecorder();
      const comp = new UpdateComponent(rec);
      await comp.handle('check', '{"manifestUrl":"http://host:8000/manifest.json"}');
      const json = await comp.handle('apply', '{}');
      expect(JsonParser.getBool(json, 'success')).assertTrue();
      expect(JsonParser.getString(json, 'version')).assertEqual('2.0.0');
      expect(rec.lastManifest !== null && rec.lastManifest.version === '9.9.9').assertTrue();
      expect(rec.lastBaseUrl).assertEqual('http://host:8000');
    });

    it('apply_withoutCheck_businessFailure', 0, async () => {
      rec = new UpdateRecorder();
      const comp = new UpdateComponent(rec);
      const json = await comp.handle('apply', '{}');
      expect(JsonParser.getBool(json, 'success')).assertFalse();
      msgContains(json, 'message', 'check first');
    });

    it('checkTransportError_businessFailure', 0, async () => {
      rec = new UpdateRecorder();
      const failing = new UpdateCheckResult();
      failing.available = false;
      failing.currentVersion = '1.0.0';
      failing.remoteVersion = '';
      failing.manifest = null;
      failing.error = 'connection refused';
      rec.checkToReturn = failing;
      const comp = new UpdateComponent(rec);
      const json = await comp.handle('check', '{"manifestUrl":"http://x/m.json"}');
      expect(JsonParser.getBool(json, 'success')).assertFalse();
      msgContains(json, 'message', 'connection refused');
    });

    it('checkUpToDate_clearsCache_applyFails', 0, async () => {
      rec = new UpdateRecorder();
      const upToDate = new UpdateCheckResult();
      upToDate.available = false;
      upToDate.currentVersion = '2.0.0';
      upToDate.remoteVersion = '2.0.0';
      upToDate.manifest = manifest('2.0.0');
      upToDate.error = null;
      rec.checkToReturn = upToDate;
      const comp = new UpdateComponent(rec);
      await comp.handle('check', '{"manifestUrl":"http://x/m.json"}');
      const json = await comp.handle('apply', '{}');
      expect(JsonParser.getBool(json, 'success')).assertFalse();
    });

    it('applyManagerError_businessFailure', 0, async () => {
      rec = new UpdateRecorder();
      const failing = new UpdateResult();
      failing.success = false;
      failing.moduleId = 'demo';
      failing.version = '';
      failing.error = 'md5 mismatch';
      rec.performToReturn = failing;
      const comp = new UpdateComponent(rec);
      await comp.handle('check', '{"manifestUrl":"http://x/m.json"}');
      const json = await comp.handle('apply', '{}');
      expect(JsonParser.getBool(json, 'success')).assertFalse();
      msgContains(json, 'message', 'md5 mismatch');
    });

    it('rollbackOk_returnsRestoredVersion', 0, async () => {
      rec = new UpdateRecorder();
      const comp = new UpdateComponent(rec);
      const json = await comp.handle('rollback', '{}');
      expect(JsonParser.getBool(json, 'success')).assertTrue();
      expect(JsonParser.getString(json, 'version')).assertEqual('1.0.0');
      expect(rec.lastRollbackModule).assertEqual('demo');
    });

    it('rollbackNothingStaged_businessFailure', 0, async () => {
      rec = new UpdateRecorder();
      rec.rollbackToReturn = false;
      const comp = new UpdateComponent(rec);
      const json = await comp.handle('rollback', '{}');
      expect(JsonParser.getBool(json, 'success')).assertFalse();
    });

    it('version_returnsLocalVersion', 0, async () => {
      rec = new UpdateRecorder();
      rec.localVersionToReturn = '3.2.1';
      const comp = new UpdateComponent(rec);
      const json = await comp.handle('version', '{}');
      expect(JsonParser.getString(json, 'version')).assertEqual('3.2.1');
    });
  });
}
