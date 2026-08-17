// coconut.d.ts — Type definitions for coconut.js SDK
//
// Reference: API_CONTRACT.md (repository root) for wire protocol,
//            component signatures, and error code conventions.
//
// coconut.js is a UMD single-file SDK loaded via <script>, so the global
// `coconut` is the primary surface. This file augments Window with the
// correct shape and also exports types for `import type` use cases.

// ---------------------------------------------------------------------------
// Error codes
// ---------------------------------------------------------------------------
//
// Code convention (see API_CONTRACT.md §2):
//   000000 success
//   100xxx standard / bridge-level errors
//   200xxx business / component-level errors
//   300xxx security / bridge-token errors

export type CoconutErrorCode =
  | '000000' // SUCCESS
  | '100005' // INTERNAL_ERROR (bridge / context unavailable)
  | '200001' // UNKNOWN_COMPONENT
  | '200002' // UNKNOWN_FUNCTION
  | '200003' // PERMISSION_DENIED
  | '200004' // TIMEOUT
  | '200007' // PARAM_VALIDATION_FAILED
  | '300004'; // BRIDGE_TOKEN_INVALID

export interface CoconutError {
  code: CoconutErrorCode | string;
  message: string;
}

// ---------------------------------------------------------------------------
// Callback convention
// ---------------------------------------------------------------------------
//
// All bridge calls use error-first callbacks to match coconut.js's runtime.
//   err === null     → success, data populated
//   err === {code,…} → failure, data undefined

export type CoconutCallback<T = unknown> = (
  error: CoconutError | null,
  data: T
) => void;

// ---------------------------------------------------------------------------
// Environment (coconut.env)
// ---------------------------------------------------------------------------

export type CoconutPlatform = 'android' | 'ios' | 'harmony' | 'web' | 'node';

export interface CoconutEnv {
  // Identity / platform
  platform: CoconutPlatform;
  isAndroid: boolean;
  isiOS: boolean;
  isHarmony: boolean;
  isWeb: boolean;
  isNode: boolean;
  isNative: boolean; // android || ios || harmony

  // Versions
  version: string; // coconut.js file version, e.g. '3.2.0'
  sdkVersion: string; // alias of version
  hybridVersion: string; // bridge protocol major, currently '3'
  appName: string; // from __coconutConfig (lazy)
  appVersion: string; // from __coconutConfig (lazy)

  // Capability detection (Phase 2)
  capabilities: Record<string, string[]>;

  // Browser-side info (best-effort, may be undefined in node)
  userAgent?: string;
  language?: string;
  cookieEnabled?: boolean;
  online?: boolean;
  isWebView?: boolean;
  isChrome?: boolean;
  isSafari?: boolean;
  isFirefox?: boolean;
  isEdge?: boolean;
  isWeChat?: boolean;
  isAlipay?: boolean;
  isWindows?: boolean;
  isMac?: boolean;
  isLinux?: boolean;
  isMobile?: boolean;
  isTablet?: boolean;
  isDesktop?: boolean;
  isIPhone?: boolean;
  isIPad?: boolean;
  isIPod?: boolean;
  androidVersion?: string;
  screenWidth?: number;
  screenHeight?: number;
  devicePixelRatio?: number;
  viewportWidth?: number;
  viewportHeight?: number;
  isTouchDevice?: boolean;
  localStorage?: boolean;
  sessionStorage?: boolean;
}

// ---------------------------------------------------------------------------
// Component APIs (shortcut namespaces)
// ---------------------------------------------------------------------------

export interface DeviceGetInfoResult {
  manufacturer: string;
  brand: string;
  model: string;
  osName: string;
  osVersion: string;
  platform: 'ios' | 'android' | 'harmony';
  screenWidth: number;
  screenHeight: number;
  screenScale?: number;
  [k: string]: unknown;
}

export interface DeviceAPI {
  getInfo(cb: CoconutCallback<DeviceGetInfoResult>): void;
}

export interface StorageSetItemResult { success: boolean; }
export interface StorageGetItemResult { value: string | null; exists?: boolean; }
export interface StorageRemoveItemResult { success: boolean; }
export interface StorageClearResult { success: boolean; }
export interface StorageGetAllKeysResult { keys: string[]; count: number; }
export interface StorageGetSizeResult { count: number; size: number; }

export interface StorageAPI {
  setItem(key: string, value: string, cb?: CoconutCallback<StorageSetItemResult>): void;
  getItem(key: string, cb: CoconutCallback<StorageGetItemResult>): void;
  removeItem(key: string, cb?: CoconutCallback<StorageRemoveItemResult>): void;
  clear(cb?: CoconutCallback<StorageClearResult>): void;
  getAllKeys(cb: CoconutCallback<StorageGetAllKeysResult>): void;
  getSize(cb: CoconutCallback<StorageGetSizeResult>): void;
}

// dialog component (v3.3.0)
export interface DialogAlertResult { confirmed: boolean; }
export interface DialogConfirmResult { confirmed: boolean; }
export interface DialogOpResult { success: boolean; }

export type DialogToastPosition = 'top' | 'center' | 'bottom';

export interface DialogAPI {
  alert(title: string, message: string, buttonText: string, cb?: CoconutCallback<DialogAlertResult>): void;
  confirm(title: string, message: string, confirmText: string, cancelText: string, cb?: CoconutCallback<DialogConfirmResult>): void;
  toast(message: string, duration?: number, position?: DialogToastPosition, cb?: CoconutCallback<DialogOpResult>): void;
  showLoading(message: string, cb?: CoconutCallback<DialogOpResult>): void;
  hideLoading(cb?: CoconutCallback<DialogOpResult>): void;
}

// Native-pushed event payload. coconut.on callbacks receive event.data
// (not the envelope); lifecycle events deliver {topic, timestamp}.
export type EventHandler = (data: unknown) => void;

export interface LifecycleEventData {
  topic: 'app.foreground' | 'app.background';
  timestamp: number;
}

// ---------------------------------------------------------------------------
// Main Coconut interface
// ---------------------------------------------------------------------------

export interface Coconut {
  // Identity / version
  version: string;
  sdkVersion: string;
  hybridVersion: string;
  environment: CoconutPlatform;
  env: CoconutEnv;
  debug: boolean;
  defaultTimeout: number;
  isInitialized: boolean;

  // Lifecycle
  init(options?: CoconutInitOptions): Coconut;

  // Bridge calls (error-first callback)
  call<T = unknown>(
    component: string,
    functionName: string,
    params: object | null,
    callback: CoconutCallback<T>,
    timeout?: number
  ): void;

  // Promise wrapper (one-shot responses only; not for streaming)
  callAsync<T = unknown>(
    component: string,
    functionName: string,
    params?: object | null
  ): Promise<T>;

  // Events (native → H5 push)
  on(topic: string, handler: EventHandler): void;
  off(topic: string): void;

  // Capability detection (Phase 2)
  supports(component: string, functionName: string): boolean;

  // Shortcut namespaces
  device: DeviceAPI;
  storage: StorageAPI;
  dialog: DialogAPI;

  // Internal (re-exposed for advanced use; not stable API)
  handlers: Record<string, EventHandler>;
  handleResponse(responseJson: string): void;
  handleEvent(eventJson: string): void;
  handleWebMock(request: unknown): void;
}

export interface CoconutInitOptions {
  debug?: boolean;
  timeout?: number;
}

// ---------------------------------------------------------------------------
// Window globals (script-tag load)
// ---------------------------------------------------------------------------

declare global {
  const coconut: Coconut;

  interface Window {
    coconut: Coconut;
    __coconutConfig?: CoconutConfig;
    __coconutIOSCallback?: (responseJson: string) => void;
    __coconutHarmonyCallback?: (responseJson: string) => void;
    __coconutEvent?: (eventJson: string) => void;
    CoconutBridge?: { call: (requestJson: string) => string | void };
    CoconutHarmonyBridge?: { call: (requestJson: string) => void };
    webkit?: {
      messageHandlers: { CoconutBridge?: { postMessage: (requestJson: string) => void } };
    };
  }
}

export interface CoconutConfig {
  token: string;
  appName: string;
  appVersion: string;
  hybridVersion: string;
  capabilities?: Record<string, string[]>;
}

export {};
