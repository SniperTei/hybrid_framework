import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { ComponentManager } from '../component/ComponentManager';
import { Logger } from '../utils/Logger';

/**
 * Hot update manager for the offline H5 package — HarmonyOS counterpart of
 * Android OfflineResourceManager's update API and iOS CoconutUpdateManager.
 *
 * Flow (semantics identical across platforms):
 *   checkUpdate(moduleId, manifestUrl)
 *     → fetch remote manifest, compare against max(sandbox, bundled) version
 *   performUpdate(manifest, baseUrl)
 *     → per-file download + md5 verification into `.staging_<moduleId>`,
 *       then atomic swap; any failure leaves the old version untouched
 *   rollback(moduleId)
 *     → delete sandbox overlay + version entry, fall back to built-in package
 *
 * Layout (reuses CoconutOfflineResources' sandbox):
 *   <filesDir>/coconut_resources/<moduleId>/...       module overlay
 *   <filesDir>/coconut_resources/version.json          {"<moduleId>": "<version>"}
 *   <filesDir>/coconut_resources/.staging_<moduleId>/  staging (cleared on entry/failure)
 *
 * Context comes from ComponentManager.getSharedContext() (nullable — callers
 * must handle null before updating). File operations take the sandbox root
 * path explicitly so the hypium tests can inject a temp directory.
 */
export class CoconutUpdateManager {
  private static readonly TAG = 'CoconutUpdate';
  private static readonly SANDBOX_ROOT = 'coconut_resources';
  private static readonly BUNDLED_ROOT = 'coconut-web';
  private static readonly VERSION_FILE = 'version.json';
  private static readonly CONNECT_TIMEOUT_MS = 15000;
  private static readonly READ_TIMEOUT_MS = 30000;

  // ---- Update API ----

  static async checkUpdate(moduleId: string, manifestUrl: string): Promise<UpdateCheckResult> {
    const context = CoconutUpdateManager.sharedContext();
    const current = CoconutUpdateManager.currentVersionOf(moduleId, context);
    const json = await CoconutUpdateManager.downloadText(manifestUrl);
    if (json === null) {
      return UpdateCheckResult.unavailable(current, '', null,
        `Failed to fetch manifest: ${manifestUrl}`);
    }
    const manifest = RemoteManifest.parse(json);
    if (manifest === null) {
      return UpdateCheckResult.unavailable(current, '', null, 'Failed to parse manifest');
    }
    if (manifest.moduleId !== moduleId) {
      return UpdateCheckResult.unavailable(current, manifest.version, manifest,
        `moduleId mismatch: expected=${moduleId} got=${manifest.moduleId}`);
    }
    const available = CoconutUpdateManager.decideUpdate(
      CoconutUpdateManager.readSandboxVersionEntry(moduleId, context),
      CoconutUpdateManager.bundledManifestVersion(moduleId, context),
      manifest.version);
    const result = new UpdateCheckResult();
    result.available = available;
    result.currentVersion = current;
    result.remoteVersion = manifest.version;
    result.manifest = manifest;
    return result;
  }

  static async performUpdate(manifest: RemoteManifest, baseUrl: string): Promise<UpdateResult> {
    const context = CoconutUpdateManager.sharedContext();
    if (context === null) {
      return UpdateResult.failed(manifest.moduleId, manifest.version, 'No UIAbility context (SDK not initialized)');
    }
    const rootDir = CoconutUpdateManager.sandboxRootDir(context);

    const validationError = CoconutUpdateManager.validateManifest(manifest);
    if (validationError !== null) {
      return UpdateResult.failed(manifest.moduleId, manifest.version, validationError);
    }

    const stagingDir = `${rootDir}/.staging_${manifest.moduleId}`;
    CoconutUpdateManager.removeDir(stagingDir);
    CoconutUpdateManager.ensureDir(stagingDir);

    try {
      for (let i = 0; i < manifest.files.length; i++) {
        const file = manifest.files[i];
        const target = `${stagingDir}/${file}`;
        const parentDir = target.substring(0, target.lastIndexOf('/'));
        CoconutUpdateManager.ensureDir(parentDir);
        const data = await CoconutUpdateManager.downloadBytes(
          CoconutUpdateManager.joinUrl(baseUrl, file));
        if (data === null) {
          throw new Error(`Download failed: ${file}`);
        }
        const expected = (manifest.fileHashes.get(file) ?? '').toLowerCase();
        const actual = CoconutUpdateManager.md5Hex(data);
        if (actual !== expected) {
          throw new Error(`MD5 mismatch for ${file}: expected=${expected} actual=${actual}`);
        }
        const fileHandle = fileIo.openSync(target, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          // fileIo.writeSync rejects Uint8Array (repo-known pitfall) — pass the ArrayBuffer.
          fileIo.writeSync(fileHandle.fd, data);
        } finally {
          fileIo.closeSync(fileHandle);
        }
      }

      CoconutUpdateManager.swapDir(rootDir, manifest.moduleId);
      CoconutUpdateManager.writeSandboxVersion(rootDir, manifest.moduleId, manifest.version);
      Logger.i(CoconutUpdateManager.TAG, `Update applied: ${manifest.moduleId} v${manifest.version}`);
      return UpdateResult.ok(manifest.moduleId, manifest.version);
    } catch (e) {
      const message = e instanceof Error ? e.message : `${e}`;
      Logger.e(CoconutUpdateManager.TAG, `performUpdate failed: ${message}`);
      CoconutUpdateManager.removeDir(stagingDir);
      return UpdateResult.failed(manifest.moduleId, manifest.version, message);
    }
  }

  static async rollback(moduleId: string): Promise<boolean> {
    const context = CoconutUpdateManager.sharedContext();
    if (context === null) {
      Logger.e(CoconutUpdateManager.TAG, 'rollback: no UIAbility context');
      return false;
    }
    const rootDir = CoconutUpdateManager.sandboxRootDir(context);
    const moduleDir = `${rootDir}/${moduleId}`;
    if (!CoconutUpdateManager.removeDir(moduleDir)) {
      return false;
    }
    CoconutUpdateManager.removeSandboxVersionEntry(rootDir, moduleId);
    Logger.i(CoconutUpdateManager.TAG, `Rolled back ${moduleId} to bundled version`);
    return true;
  }

  static currentVersion(moduleId: string): string {
    return CoconutUpdateManager.currentVersionOf(moduleId, CoconutUpdateManager.sharedContext());
  }

  private static currentVersionOf(moduleId: string, context: common.UIAbilityContext | null): string {
    let current = '0.0.0';
    const sandbox = CoconutUpdateManager.readSandboxVersionEntry(moduleId, context);
    const bundled = CoconutUpdateManager.bundledManifestVersion(moduleId, context);
    const candidates: string[] = [];
    if (sandbox !== null) {
      candidates.push(sandbox);
    }
    if (bundled !== null) {
      candidates.push(bundled);
    }
    for (let i = 0; i < candidates.length; i++) {
      if (CoconutUpdateManager.compareVersions(candidates[i], current) > 0) {
        current = candidates[i];
      }
    }
    return current;
  }

  private static sharedContext(): common.UIAbilityContext | null {
    const shared = ComponentManager.getInstance().getSharedContext();
    return shared !== null ? shared.context : null;
  }

  static sandboxRootDir(context: common.UIAbilityContext): string {
    return `${context.filesDir}/${CoconutUpdateManager.SANDBOX_ROOT}`;
  }

  private static joinUrl(baseUrl: string, path: string): string {
    const base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return `${base}/${path}`;
  }

  // ---- Atomic swap (rename with copy+delete fallback) ----

  /**
   * Drop the current module directory and move the staging directory into
   * its place. fileIo.renameSync on directories is uncertain on some
   * HarmonyOS builds (risk #1 in the plan), so a copy-tree + delete
   * fallback is kept as cheap insurance — both paths stay exercised.
   */
  static swapDir(rootDir: string, moduleId: string): void {
    const moduleDir = `${rootDir}/${moduleId}`;
    const stagingDir = `${rootDir}/.staging_${moduleId}`;
    CoconutUpdateManager.removeDir(moduleDir);
    try {
      fileIo.renameSync(stagingDir, moduleDir);
      Logger.d(CoconutUpdateManager.TAG, `swapDir: renamed staging into place`);
    } catch (e) {
      Logger.w(CoconutUpdateManager.TAG, `swapDir: rename failed (${e}), falling back to copy+delete`);
      CoconutUpdateManager.copyTree(stagingDir, moduleDir);
      CoconutUpdateManager.removeDir(stagingDir);
    }
  }

  private static copyTree(srcDir: string, destDir: string): void {
    CoconutUpdateManager.ensureDir(destDir);
    const entries = fileIo.listFileSync(srcDir);
    for (let i = 0; i < entries.length; i++) {
      const name = `${entries[i]}`;
      const src = `${srcDir}/${name}`;
      const dest = `${destDir}/${name}`;
      if (CoconutUpdateManager.isDirectory(src)) {
        CoconutUpdateManager.copyTree(src, dest);
      } else {
        const stat = fileIo.statSync(src);
        const file = fileIo.openSync(src, fileIo.OpenMode.READ_ONLY);
        try {
          const buf = new ArrayBuffer(stat.size);
          fileIo.readSync(file.fd, buf);
          const out = fileIo.openSync(dest, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
          try {
            fileIo.writeSync(out.fd, buf);
          } finally {
            fileIo.closeSync(out);
          }
        } finally {
          fileIo.closeSync(file);
        }
      }
    }
  }

  private static isDirectory(path: string): boolean {
    try {
      return fileIo.statSync(path).isDirectory();
    } catch (e) {
      return false;
    }
  }

  private static removeDir(path: string): boolean {
    try {
      // accessSync lies on missing files (repo-known pitfall); statSync throws.
      fileIo.statSync(path);
    } catch (e) {
      return true; // already gone
    }
    try {
      fileIo.rmdirSync(path);
      return true;
    } catch (e) {
      Logger.e(CoconutUpdateManager.TAG, `removeDir failed: ${path} (${e})`);
      return false;
    }
  }

  private static ensureDir(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (e) {
      // mkdirSync throws "File exists" even with recursive=true (device
      // pitfall — caught by e2e, not unit tests). Real failures (permission
      // etc.) surface at the subsequent openSync/listFileSync call.
    }
  }

  // ---- version.json persistence ----

  static readSandboxVersions(rootDir: string): Map<string, string> {
    const versions = new Map<string, string>();
    try {
      const stat = fileIo.statSync(`${rootDir}/${CoconutUpdateManager.VERSION_FILE}`);
      const file = fileIo.openSync(`${rootDir}/${CoconutUpdateManager.VERSION_FILE}`, fileIo.OpenMode.READ_ONLY);
      try {
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        const json = CoconutUpdateManager.decodeText(buf);
        CoconutUpdateManager.parseStringPairs(json).forEach(pair => {
          versions.set(pair[0], pair[1]);
        });
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      // no version.json yet — empty map
    }
    return versions;
  }

  private static writeSandboxVersion(rootDir: string, moduleId: string, version: string): void {
    const versions = CoconutUpdateManager.readSandboxVersions(rootDir);
    versions.set(moduleId, version);
    CoconutUpdateManager.writeSandboxVersions(rootDir, versions);
  }

  private static removeSandboxVersionEntry(rootDir: string, moduleId: string): void {
    const versions = CoconutUpdateManager.readSandboxVersions(rootDir);
    versions.delete(moduleId);
    CoconutUpdateManager.writeSandboxVersions(rootDir, versions);
  }

  private static writeSandboxVersions(rootDir: string, versions: Map<string, string>): void {
    const pairs: string[] = [];
    versions.forEach((value, key) => {
      pairs.push(`${JSON.stringify(key)}:${JSON.stringify(value)}`);
    });
    const json = `{${pairs.join(',')}}`;
    try {
      CoconutUpdateManager.ensureDir(rootDir);
      const file = fileIo.openSync(`${rootDir}/${CoconutUpdateManager.VERSION_FILE}`,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, json);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      Logger.e(CoconutUpdateManager.TAG, `writeSandboxVersions failed: ${e}`);
    }
  }

  private static readSandboxVersionEntry(moduleId: string,
    context: common.UIAbilityContext | null): string | null {
    if (context === null) {
      return null;
    }
    const versions = CoconutUpdateManager.readSandboxVersions(CoconutUpdateManager.sandboxRootDir(context));
    const entry = versions.get(moduleId);
    return entry !== undefined ? entry : null;
  }

  private static bundledManifestVersion(moduleId: string,
    context: common.UIAbilityContext | null): string | null {
    if (context === null) {
      return null;
    }
    try {
      const bytes: Uint8Array = context.resourceManager
        .getRawFileContentSync(`${CoconutUpdateManager.BUNDLED_ROOT}/${moduleId}/manifest.json`);
      const json = CoconutUpdateManager.decodeText(
        bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
      const manifest = RemoteManifest.parse(json);
      return manifest !== null && manifest.moduleId === moduleId ? manifest.version : null;
    } catch (e) {
      return null;
    }
  }

  // ---- Network ----

  private static async downloadBytes(url: string): Promise<ArrayBuffer | null> {
    const session = http.createHttp();
    try {
      const response = await session.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: CoconutUpdateManager.CONNECT_TIMEOUT_MS,
        readTimeout: CoconutUpdateManager.READ_TIMEOUT_MS,
      } as http.HttpRequestOptions);
      if (response.responseCode !== 200) {
        Logger.e(CoconutUpdateManager.TAG, `downloadBytes ${url}: HTTP ${response.responseCode}`);
        return null;
      }
      const data = response.result;
      return data instanceof ArrayBuffer ? data : null;
    } catch (e) {
      Logger.e(CoconutUpdateManager.TAG, `downloadBytes ${url} failed: ${e}`);
      return null;
    } finally {
      session.destroy();
    }
  }

  private static async downloadText(url: string): Promise<string | null> {
    const data = await CoconutUpdateManager.downloadBytes(url);
    return data === null ? null : CoconutUpdateManager.decodeText(data);
  }

  private static decodeText(buf: ArrayBuffer): string {
    // Package files are UTF-8 (HTML/JS/JSON) — TextDecoder handles them all.
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
  }

  // ---- Pure helpers (aligned with Android companion / iOS statics) ----

  static compareVersions(v1: string, v2: string): number {
    const parts1 = v1.split('.');
    const parts2 = v2.split('.');
    const len = Math.max(parts1.length, parts2.length);
    for (let i = 0; i < len; i++) {
      const p1 = i < parts1.length ? CoconutUpdateManager.parseSegment(parts1[i]) : 0;
      const p2 = i < parts2.length ? CoconutUpdateManager.parseSegment(parts2[i]) : 0;
      if (p1 !== p2) {
        return p1 - p2;
      }
    }
    return 0;
  }

  private static parseSegment(segment: string): number {
    const value = parseInt(segment);
    return isNaN(value) ? 0 : value;
  }

  static isSafePackagePath(path: string): boolean {
    if (path.length === 0 || path.startsWith('/') || path.includes('\\')) {
      return false;
    }
    const segments = path.split('/');
    for (let i = 0; i < segments.length; i++) {
      const seg = segments[i];
      if (seg.length === 0 || seg === '.' || seg === '..') {
        return false;
      }
    }
    return true;
  }

  static decideUpdate(sandboxVersion: string | null, bundledVersion: string | null,
    remoteVersion: string): boolean {
    let current = '0.0.0';
    const candidates: string[] = [];
    if (sandboxVersion !== null) {
      candidates.push(sandboxVersion);
    }
    if (bundledVersion !== null) {
      candidates.push(bundledVersion);
    }
    for (let i = 0; i < candidates.length; i++) {
      if (CoconutUpdateManager.compareVersions(candidates[i], current) > 0) {
        current = candidates[i];
      }
    }
    return CoconutUpdateManager.compareVersions(remoteVersion, current) > 0;
  }

  static validateManifest(manifest: RemoteManifest): string | null {
    if (manifest.files.length === 0) {
      return 'manifest has no files';
    }
    for (let i = 0; i < manifest.files.length; i++) {
      const file = manifest.files[i];
      if (!CoconutUpdateManager.isSafePackagePath(file)) {
        return `unsafe package path: ${file}`;
      }
      const hash = manifest.fileHashes.get(file);
      if (hash === undefined || hash.trim().length === 0) {
        return `missing fileHashes entry: ${file}`;
      }
    }
    return null;
  }

  /**
   * Pure-JS MD5 (RFC 1321). cryptoFramework's Md was rejected on some
   * device images ("build context fail" / "update failed" inside HUKS), so
   * the digest is computed locally — package files are small enough that
   * JS throughput is a non-issue, and known-vector tests pin correctness.
   */
  static md5Hex(data: ArrayBuffer): string {
    const bytes = new Uint8Array(data);
    const K = new Array<number>(64);
    for (let i = 0; i < 64; i++) {
      K[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 4294967296);
    }
    const S: number[] = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
      5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
      4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
      6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];

    // Pad: message + 0x80 + zeros + 64-bit LE bit length, to a 64-byte multiple.
    const len = bytes.length;
    const paddedLen = (((len + 8) >> 6) + 1) << 6;
    const padded = new Uint8Array(paddedLen);
    padded.set(bytes);
    padded[len] = 0x80;
    const bitLen = len * 8;
    const low = bitLen >>> 0;
    const high = Math.floor(bitLen / 4294967296);
    padded[paddedLen - 8] = low & 0xFF;
    padded[paddedLen - 7] = (low >>> 8) & 0xFF;
    padded[paddedLen - 6] = (low >>> 16) & 0xFF;
    padded[paddedLen - 5] = (low >>> 24) & 0xFF;
    padded[paddedLen - 4] = high & 0xFF;
    padded[paddedLen - 3] = (high >>> 8) & 0xFF;
    padded[paddedLen - 2] = (high >>> 16) & 0xFF;
    padded[paddedLen - 1] = (high >>> 24) & 0xFF;

    let a0 = 0x67452301;
    let b0 = 0xefcdab89;
    let c0 = 0x98badcfe;
    let d0 = 0x10325476;
    const M = new Uint32Array(16);

    for (let offset = 0; offset < paddedLen; offset += 64) {
      for (let j = 0; j < 16; j++) {
        const idx = offset + j * 4;
        M[j] = padded[idx] | (padded[idx + 1] << 8) | (padded[idx + 2] << 16) | (padded[idx + 3] << 24);
      }
      let A = a0;
      let B = b0;
      let C = c0;
      let D = d0;
      for (let i = 0; i < 64; i++) {
        let F = 0;
        let g = 0;
        if (i < 16) {
          F = (B & C) | (~B & D);
          g = i;
        } else if (i < 32) {
          F = (D & B) | (~D & C);
          g = (5 * i + 1) % 16;
        } else if (i < 48) {
          F = B ^ C ^ D;
          g = (3 * i + 5) % 16;
        } else {
          F = C ^ (B | ~D);
          g = (7 * i) % 16;
        }
        F = (F + A + K[i] + M[g]) | 0;
        A = D;
        D = C;
        C = B;
        B = (B + ((F << S[i]) | (F >>> (32 - S[i])))) | 0;
      }
      a0 = (a0 + A) | 0;
      b0 = (b0 + B) | 0;
      c0 = (c0 + C) | 0;
      d0 = (d0 + D) | 0;
    }

    const words = [a0, b0, c0, d0];
    let hex = '';
    for (let w = 0; w < 4; w++) {
      const word = words[w];
      for (let b = 0; b < 4; b++) {
        const byte = (word >>> (b * 8)) & 0xFF;
        hex += (byte < 16 ? '0' : '') + byte.toString(16);
      }
    }
    return hex;
  }

  static parseStringPairs(json: string): Array<[string, string]> {
    // Extract `"key":"value"` pairs from a flat JSON object string.
    const pairs: Array<[string, string]> = [];
    const matches = json.match(/"[^"]*"\s*:\s*"[^"]*"/g);
    if (matches === null) {
      return pairs;
    }
    for (let i = 0; i < matches.length; i++) {
      const colonIdx = matches[i].indexOf(':');
      const key = matches[i].substring(0, colonIdx).trim().replace(/^"|"$/g, '');
      const value = matches[i].substring(colonIdx + 1).trim().replace(/^"|"$/g, '');
      pairs.push([key, value] as [string, string]);
    }
    return pairs;
  }
}

/**
 * Manifest served by the update server. Hand-rolled parser matching the
 * repo's string-extraction pattern (BridgeRequest.fromJson); tolerant of
 * unknown fields.
 */
export class RemoteManifest {
  moduleId: string = '';
  version: string = '';
  entry: string = '';
  files: string[] = [];
  md5: string = '';
  fileHashes: Map<string, string> = new Map();

  static parse(json: string): RemoteManifest | null {
    if (json.trim().length === 0) {
      return null;
    }
    const manifest = new RemoteManifest();
    // Whitespace-tolerant lookup: real servers pretty-print manifests
    // ("key": "value"), unlike the compact wire JSON JsonParser targets.
    manifest.moduleId = RemoteManifest.getString(json, 'moduleId');
    manifest.version = RemoteManifest.getString(json, 'version');
    manifest.entry = RemoteManifest.getString(json, 'entry');
    manifest.md5 = RemoteManifest.getString(json, 'md5');

    // files: ["a","b", ...]
    const filesIdx = json.indexOf('"files":');
    if (filesIdx !== -1) {
      const openIdx = json.indexOf('[', filesIdx);
      const closeIdx = json.indexOf(']', openIdx);
      if (openIdx !== -1 && closeIdx > openIdx) {
        const items = json.substring(openIdx + 1, closeIdx).split(',');
        for (let i = 0; i < items.length; i++) {
          const item = items[i].trim().replace(/^"|"$/g, '');
          if (item.length > 0) {
            manifest.files.push(item);
          }
        }
      }
    }

    // fileHashes: {"path":"hash", ...}
    const hashesIdx = json.indexOf('"fileHashes":');
    if (hashesIdx !== -1) {
      const openIdx = json.indexOf('{', hashesIdx);
      let depth = 0;
      let closeIdx = -1;
      for (let i = openIdx; i < json.length; i++) {
        if (json[i] === '{') {
          depth++;
        } else if (json[i] === '}') {
          depth--;
          if (depth === 0) {
            closeIdx = i;
            break;
          }
        }
      }
      if (openIdx !== -1 && closeIdx > openIdx) {
        const pairs = CoconutUpdateManager.parseStringPairs(json.substring(openIdx, closeIdx + 1));
        for (let i = 0; i < pairs.length; i++) {
          manifest.fileHashes.set(pairs[i][0], pairs[i][1]);
        }
      }
    }

    if (manifest.moduleId.length === 0 || manifest.version.length === 0) {
      return null;
    }
    return manifest;
  }

  private static getString(json: string, key: string): string {
    // Matches `"key"<ws>:<ws>"value"` — tolerant of pretty-printed JSON.
    const match = json.match(new RegExp(`"${key}"\\s*:\\s*"`));
    if (match === null) {
      return '';
    }
    const valueStart = (match.index ?? 0) + match[0].length;
    const valueEnd = json.indexOf('"', valueStart);
    return valueEnd === -1 ? '' : json.substring(valueStart, valueEnd);
  }
}

export class UpdateCheckResult {
  available: boolean = false;
  currentVersion: string = '';
  remoteVersion: string = '';
  manifest: RemoteManifest | null = null;
  error: string | null = null;

  static unavailable(current: string, remote: string, manifest: RemoteManifest | null,
    error: string): UpdateCheckResult {
    const result = new UpdateCheckResult();
    result.available = false;
    result.currentVersion = current;
    result.remoteVersion = remote;
    result.manifest = manifest;
    result.error = error;
    return result;
  }
}

export class UpdateResult {
  success: boolean = false;
  moduleId: string = '';
  version: string = '';
  error: string | null = null;

  static ok(moduleId: string, version: string): UpdateResult {
    const result = new UpdateResult();
    result.success = true;
    result.moduleId = moduleId;
    result.version = version;
    return result;
  }

  static failed(moduleId: string, version: string, error: string): UpdateResult {
    const result = new UpdateResult();
    result.success = false;
    result.moduleId = moduleId;
    result.version = version;
    result.error = error;
    return result;
  }
}
