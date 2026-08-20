import { BaseComponent, ComponentContext, CoconutSDK, JsonParser, JsonObject } from '@coconut/sdk';
import { HttpClient, HttpConfig, HttpMethod, RequestOptions, HttpErrorCode } from '@coconut/network';
import { connection } from '@kit.NetworkKit';

/**
 * Topic emitted on network type/online changes (deduped).
 */
export const NETWORK_TOPIC_CHANGE: string = 'network.change';

const ALLOWED_METHODS: string[] = ['GET', 'POST', 'PUT', 'DELETE'];

class NetworkStatus {
  type: string = 'unknown';
  online: boolean = false;
}

/**
 * Network Component
 *
 * Bridges the standalone @coconut/network engine to the H5 bridge:
 * - request: native HTTP via HttpClient (bypasses WebView CORS, unified
 *   outbound guard). Business-layer failure convention: bridge code 000000
 *   + success:false in the result payload.
 * - getNetworkType: current connectivity (wifi/cellular/ethernet/none/unknown).
 * - network.change: native → H5 push on connectivity change (deduped by
 *   type|online key), reusing the EventEmitter channel.
 *
 * The HttpClient is injectable for tests (FakeAdapter); by default it is
 * created once with allowedDomains synced from CoconutSDK.config.
 */
export class NetworkComponent extends BaseComponent {
  name: string = 'network';
  version: string = '1.0.0';
  description: string = 'Network request + connectivity component';
  methods: string[] = ['request', 'getNetworkType'];

  private client: HttpClient;
  private netConn: connection.NetConnection | null = null;
  private lastStateKey: string = '';
  // Cached state from the NetConnection event stream. Pull APIs
  // (hasDefaultNet/getDefaultNet/getNetCapabilities) throw 201 unless the
  // signing profile carries the GET_NETWORK_INFO ACL — events don't, so they
  // are the source of truth; the pull path remains only as cold-start fallback.
  private cachedType: string = 'unknown';
  private cachedOnline: boolean = false;
  private hasCachedState: boolean = false;

  constructor(client?: HttpClient) {
    super();
    if (client !== undefined) {
      this.client = client;
    } else {
      const config = new HttpConfig();
      // SSRF guard: reuse the inbound bridge whitelist for outbound requests.
      // Reference assignment so later CoconutSDK.configure() changes propagate.
      config.allowedDomains = CoconutSDK.config.allowedDomains;
      this.client = new HttpClient(config);
    }
  }

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'request':
        return this.requestHandler(paramsJson);
      case 'getNetworkType':
        return this.getNetworkTypeHandler();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  protected async onInit(): Promise<void> {
    const ctx = this.getComponentContext();
    if (ctx === null) {
      return;
    }
    this.netConn = connection.createNetConnection();
    this.netConn.on('netAvailable', () => {
      console.debug('[NetworkComponent] event: netAvailable');
      this.cachedOnline = true;
      this.hasCachedState = true;
      // Coalesce: the netCapabilitiesChange that follows within ms refines
      // the bearer; the deferred emit dedups against it (single push).
      setTimeout(() => {
        this.updateCacheAndEmit(
          this.cachedType === 'none' ? 'unknown' : this.cachedType, true);
      }, 150);
    });
    this.netConn.on('netUnavailable', () => {
      console.debug('[NetworkComponent] event: netUnavailable');
      this.updateCacheAndEmit('none', false);
    });
    this.netConn.on('netLost', () => {
      // Some HarmonyOS builds deliver netLost instead of netUnavailable
      // when the default network dies (observed on real device)
      console.debug('[NetworkComponent] event: netLost');
      this.updateCacheAndEmit('none', false);
    });
    this.netConn.on('netCapabilitiesChange',
      (data: connection.NetCapabilityInfo) => {
        // NB: this SDK calls the field `netCap` (docs say netCapabilities)
        this.updateCacheAndEmit(
          NetworkComponent.bearerToType(data.netCap.bearerTypes), true);
      });
    this.netConn.register(() => {
    });
  }

  protected async onCleanup(): Promise<void> {
    if (this.netConn !== null) {
      this.netConn.unregister(() => {
      });
      this.netConn = null;
    }
    this.lastStateKey = '';
    this.cachedType = 'unknown';
    this.cachedOnline = false;
    this.hasCachedState = false;
  }

  /**
   * request: {url, method, headers, body, params, timeoutMs}
   * → {success, httpStatus, code, msg, data, headers, costTime, message}
   */
  private async requestHandler(paramsJson: string): Promise<string> {
    const url = this.getParam(paramsJson, 'url');
    if (url.length === 0) {
      return this.error('200007', 'url is required');
    }

    const methodStr = this.getParam(paramsJson, 'method', 'GET').toUpperCase();
    let method: HttpMethod = HttpMethod.GET;
    if (methodStr === 'POST') {
      method = HttpMethod.POST;
    } else if (methodStr === 'PUT') {
      method = HttpMethod.PUT;
    } else if (methodStr === 'DELETE') {
      method = HttpMethod.DELETE;
    } else if (methodStr !== 'GET') {
      // deliberate whitelist — PATCH/HEAD etc. deferred to a later round
      return this.error('200007', `method not allowed: ${methodStr} ` +
        `(allowed: ${ALLOWED_METHODS.join('/')})`);
    }

    const options: RequestOptions = { method: method };

    const headers = this.extractStringMap(JsonParser.getObject(paramsJson, 'headers'));
    if (Object.keys(headers).length > 0) {
      options.headers = headers;
    }

    const query = this.extractStringMap(JsonParser.getObject(paramsJson, 'params'));
    if (Object.keys(query).length > 0) {
      options.params = query;
    }

    const timeoutMs = this.getIntParam(paramsJson, 'timeoutMs', 0);

    const request = this.client.newRequest(url, options);
    if (this.hasParam(paramsJson, 'body')) {
      // raw JSON string passthrough (contentType stays application/json)
      request.setBody(JsonParser.getObject(paramsJson, 'body'));
    }
    if (timeoutMs > 0) {
      request.setTimeout(timeoutMs, timeoutMs);
    }

    const resp = await request.buildCall().execute();

    // Outbound guard hit → surface as bridge security error (200007),
    // mirroring inbound BridgeSecurityValidator semantics.
    if (resp.code === String(HttpErrorCode.URL_BLOCKED)) {
      return this.error('200007', resp.msg);
    }

    const builder = new JsonObject();
    builder.putBool('success', resp.isSuccess());
    builder.putNumber('httpStatus', resp.httpStatus);
    builder.put('code', resp.code);
    builder.put('msg', resp.msg);
    if (resp.data !== null) {
      builder.putJson('data', JSON.stringify(resp.data));
    } else {
      builder.putNull('data');
    }
    builder.putJson('headers', JSON.stringify(resp.headers));
    builder.putNumber('costTime', resp.costTime);
    builder.put('message', resp.msg);
    return this.success(builder);
  }

  /**
   * getNetworkType → {type: wifi|cellular|ethernet|none|unknown, online, success}
   *
   * Served from the cached event-stream state; the pull path runs only when
   * no NetConnection event has arrived yet (before register's first callback).
   */
  private async getNetworkTypeHandler(): Promise<string> {
    let type = this.cachedType;
    let online = this.cachedOnline;
    if (!this.hasCachedState) {
      const status = await NetworkComponent.fetchNetworkType();
      type = status.type;
      online = status.online;
    }
    const builder = new JsonObject();
    builder.put('type', type);
    builder.putBool('online', online);
    builder.putBool('success', true);
    return this.success(builder);
  }

  /** Extract Record<string,string> from a JSON object string */
  private extractStringMap(objJson: string): Record<string, string> {
    const map: Record<string, string> = {};
    const keys = JsonParser.getKeys(objJson);
    for (const key of keys) {
      map[key] = JsonParser.getString(objJson, key);
    }
    return map;
  }

  /** Update the cached event-stream state, then emit (deduped) */
  private updateCacheAndEmit(type: string, online: boolean): void {
    console.debug(`[NetworkComponent] state → ${type}|${online}`);
    this.cachedType = type;
    this.cachedOnline = online;
    this.hasCachedState = true;
    this.emitState(type, online);
  }

  /** Emit network.change, deduped on type|online (first emit carries initial state) */
  private emitState(type: string, online: boolean): void {
    const key = `${type}|${online}`;
    if (key === this.lastStateKey) {
      return;
    }
    this.lastStateKey = key;
    const ctx = this.getComponentContext();
    if (ctx === null) {
      return;
    }
    const builder = new JsonObject();
    builder.put('type', type);
    builder.putBool('online', online);
    ctx.eventEmitter.emit(NETWORK_TOPIC_CHANGE, builder.build());
  }

  /**
   * Cold-start fallback only — pulls via hasDefaultNet/getDefaultNet, which
   * throw 201 unless the signing profile carries the GET_NETWORK_INFO ACL.
   * Never silently swallow: log so a missing ACL is diagnosable.
   */
  private static async fetchNetworkType(): Promise<NetworkStatus> {
    const status = new NetworkStatus();
    try {
      status.online = await connection.hasDefaultNet();
    } catch (e) {
      console.error(`[NetworkComponent] hasDefaultNet failed: ${JSON.stringify(e)}`);
      status.online = false;
    }
    if (!status.online) {
      status.type = 'none';
      return status;
    }
    try {
      const net = await connection.getDefaultNet();
      // module-level function on this SDK (not a NetHandle method)
      const caps = await connection.getNetCapabilities(net);
      status.type = NetworkComponent.bearerToType(caps.bearerTypes);
    } catch (e) {
      console.error(`[NetworkComponent] getDefaultNet failed: ${JSON.stringify(e)}`);
      status.type = 'unknown';
    }
    return status;
  }

  private static bearerToType(bearerTypes: Array<connection.NetBearType>): string {
    if (bearerTypes.includes(connection.NetBearType.BEARER_WIFI)) {
      return 'wifi';
    }
    if (bearerTypes.includes(connection.NetBearType.BEARER_ETHERNET)) {
      return 'ethernet';
    }
    if (bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR)) {
      return 'cellular';
    }
    return 'unknown';
  }
}
