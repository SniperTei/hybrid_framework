import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { Logger } from '../utils/Logger';

/**
 * Offline package serving for the coconut:// scheme.
 *
 * ArkWeb has no custom-scheme registration (unlike iOS
 * WKURLSchemeHandler), so the main frame is translated by
 * CoconutWebPage to `resource://rawfile/coconut-web/<moduleId>/<path>`
 * (the built-in load path that works with zero interception), and
 * onInterceptRequest serves BOTH URL shapes with:
 *
 *   1. sandbox overlay `<filesDir>/coconut_resources/<moduleId>/<path>`
 *      (hot-update layer; layout aligned with Android
 *      OfflineResourceManager)
 *   2. rawfile `coconut-web/<moduleId>/<path>` (built-in package)
 *   3. 404 response
 *
 * onInterceptRequest returning null = keep default loading, so this
 * never touches regular http(s) requests.
 */
export class CoconutOfflineResources {
  private static readonly SCHEME = 'coconut://';
  private static readonly RAWFILE_URL_PREFIX = 'resource://rawfile/coconut-web/';
  private static readonly RAWFILE_ROOT = 'coconut-web';
  private static readonly SANDBOX_ROOT = 'coconut_resources';
  private static readonly TAG = 'CoconutOffline';

  /**
   * Map an offline URL to a rawfile-relative package path:
   *   coconut://demo/index.html          → coconut-web/demo/index.html
   *   resource://rawfile/coconut-web/…   → coconut-web/…
   * Empty / directory paths resolve to index.html (aligned with iOS
   * parseOfflinePath). Returns null for non-offline URLs.
   */
  static parseOfflinePath(url: string): string | null {
    let rest: string | null = null;
    if (url.startsWith(CoconutOfflineResources.SCHEME)) {
      rest = CoconutOfflineResources.RAWFILE_ROOT + '/' +
        url.substring(CoconutOfflineResources.SCHEME.length);
    } else if (url.startsWith(CoconutOfflineResources.RAWFILE_URL_PREFIX)) {
      rest = CoconutOfflineResources.RAWFILE_ROOT + '/' +
        url.substring(CoconutOfflineResources.RAWFILE_URL_PREFIX.length);
    } else {
      return null;
    }
    // Strip query / fragment
    const cut = rest.search(/[?#]/);
    if (cut >= 0) {
      rest = rest.substring(0, cut);
    }
    rest = rest.replace(/^\/+/, '');
    if (rest.length === 0) {
      return null;
    }
    // Directory-ish path (trailing slash or extension-less last
    // segment) resolves to the package entry.
    if (!rest.endsWith('/')) {
      const lastSlash = rest.lastIndexOf('/');
      const lastSeg = rest.substring(lastSlash + 1);
      if (!lastSeg.includes('.')) {
        rest += '/';
      }
    }
    if (rest.endsWith('/')) {
      rest += 'index.html';
    }
    return rest;
  }

  /**
   * coconut://… → resource://rawfile/coconut-web/… (main-frame load
   * translation; query is preserved). Non-coconut URLs pass through.
   */
  static translateUrl(url: string): string {
    if (!url.startsWith(CoconutOfflineResources.SCHEME)) {
      return url;
    }
    const queryIdx = url.search(/[?#]/);
    const query = queryIdx >= 0 ? url.substring(queryIdx) : '';
    const base = queryIdx >= 0 ? url.substring(0, queryIdx) : url;
    const rel = CoconutOfflineResources.parseOfflinePath(base);
    if (rel === null) {
      return url;
    }
    return 'resource://rawfile/' + rel + query;
  }

  /** MIME table aligned with Android OfflineResourceManager / iOS CoconutSchemeHandler. */
  static mimeType(path: string): string {
    const lower = path.toLowerCase();
    const dot = lower.lastIndexOf('.');
    const ext = dot >= 0 ? lower.substring(dot + 1) : '';
    switch (ext) {
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'json':
      case 'map':
        return 'application/json';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'ico':
        return 'image/x-icon';
      case 'woff':
        return 'font/woff';
      case 'woff2':
        return 'font/woff2';
      case 'ttf':
        return 'font/ttf';
      default:
        return 'application/octet-stream';
    }
  }

  /**
   * onInterceptRequest entry: serve the offline package for coconut://
   * and resource://rawfile/coconut-web/ URLs, return null for
   * everything else (default loading).
   */
  static intercept(url: string, context: common.UIAbilityContext | null): WebResourceResponse | null {
    const rel = CoconutOfflineResources.parseOfflinePath(url);
    if (rel === null) {
      return null;
    }
    // Path traversal guard (rel always starts with coconut-web/, but
    // reject anything trying to escape the package root).
    if (rel.includes('..')) {
      Logger.w(CoconutOfflineResources.TAG, `Rejected path traversal: ${url}`);
      return CoconutOfflineResources.textResponse(400, `Invalid offline URL: ${url}`);
    }

    // 1. Sandbox overlay (hot-update layer). Layout mirrors Android:
    //    filesDir/coconut_resources/<moduleId>/<path> — i.e. the
    //    coconut-web/ prefix maps to the sandbox root.
    if (context !== null) {
      const sandboxRel = rel.substring(CoconutOfflineResources.RAWFILE_ROOT.length + 1);
      const data = CoconutOfflineResources.readSandboxFile(context, sandboxRel);
      if (data !== null) {
        Logger.d(CoconutOfflineResources.TAG, `Serving sandbox overlay: ${sandboxRel} (${data.byteLength} bytes)`);
        return CoconutOfflineResources.binaryResponse(data, rel);
      }
    }

    // 2. Built-in rawfile package
    if (context !== null) {
      const data = CoconutOfflineResources.readRawFile(context, rel);
      if (data !== null) {
        Logger.d(CoconutOfflineResources.TAG, `Serving offline rawfile: ${rel} (${data.byteLength} bytes)`);
        return CoconutOfflineResources.binaryResponse(data, rel);
      }
    }

    // 3. 404 (an intercepted request must always receive a response,
    //    otherwise the page hangs)
    Logger.e(CoconutOfflineResources.TAG, `Offline resource missing: ${rel}`);
    return CoconutOfflineResources.textResponse(404, `Not Found: ${rel}`);
  }

  // MARK: - File readers

  private static readSandboxFile(context: common.UIAbilityContext, sandboxRel: string): ArrayBuffer | null {
    const path = `${context.filesDir}/${CoconutOfflineResources.SANDBOX_ROOT}/${sandboxRel}`;
    try {
      // accessSync lies on missing files (repo-known pitfall); statSync throws.
      const stat = fileIo.statSync(path);
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        return buf;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      return null;
    }
  }

  private static readRawFile(context: common.UIAbilityContext, rel: string): ArrayBuffer | null {
    try {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(rel);
      // Copy into an exact-fit ArrayBuffer — setResponseData does not
      // accept Uint8Array (same doc/impl gap as fileIo).
      return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    } catch (e) {
      return null;
    }
  }

  // MARK: - Response builders (ArkTS strict: setter construction, no object literals)

  private static applyCorsHeader(response: WebResourceResponse): void {
    // Offline pages run on a null-origin scheme (resource://); allow any
    // crossorigin-attributed subresource to read served bytes.
    const headers: Array<Header> = [
      { headerKey: 'Access-Control-Allow-Origin', headerValue: '*' } as Header
    ];
    response.setResponseHeader(headers);
  }

  private static binaryResponse(data: ArrayBuffer, relPath: string): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    const mime = CoconutOfflineResources.mimeType(relPath);
    response.setResponseMimeType(mime);
    if (CoconutOfflineResources.isTextMime(mime)) {
      response.setResponseEncoding('utf-8');
    }
    response.setResponseData(data);
    CoconutOfflineResources.applyCorsHeader(response);
    return response;
  }

  private static textResponse(status: number, message: string): WebResourceResponse {
    const response = new WebResourceResponse();
    response.setResponseCode(status);
    response.setReasonMessage(status === 200 ? 'OK' : 'Error');
    response.setResponseMimeType('text/plain');
    response.setResponseEncoding('utf-8');
    response.setResponseData(message);
    CoconutOfflineResources.applyCorsHeader(response);
    return response;
  }

  private static isTextMime(mime: string): boolean {
    return mime.startsWith('text/') ||
      mime === 'application/json' ||
      mime === 'application/javascript' ||
      mime === 'image/svg+xml';
  }
}
