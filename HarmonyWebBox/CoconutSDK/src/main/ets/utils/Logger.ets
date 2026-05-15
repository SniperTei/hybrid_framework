/**
 * Coconut Logger
 *
 * Logging utility with debug mode support
 */
export class Logger {
  private static debugMode: boolean = false;
  private static readonly TAG = 'CoconutSDK';

  static setDebugMode(debug: boolean): void {
    Logger.debugMode = debug;
  }

  static d(tag: string, message: string): void {
    if (Logger.debugMode) {
      console.debug(`[${tag}] ${message}`);
    }
  }

  static i(tag: string, message: string): void {
    console.info(`[${tag}] ${message}`);
  }

  static w(tag: string, message: string): void {
    console.warn(`[${tag}] ${message}`);
  }

  static e(tag: string, message: string): void {
    console.error(`[${tag}] ${message}`);
  }

  static logBridgeCallStart(method: string, id: string): void {
    Logger.d('Bridge', `--> ${method} (${id})`);
  }

  static logBridgeCallSuccess(method: string, id: string): void {
    Logger.d('Bridge', `<-- ${method} (${id}) OK`);
  }

  static logBridgeCallError(method: string, id: string, code: string, message: string): void {
    Logger.d('Bridge', `<-- ${method} (${id}) ERR [${code}]: ${message}`);
  }

  static logBridgeCallValidation(method: string, id: string, message: string): void {
    Logger.w('Bridge', `Validation failed: ${method} (${id}) - ${message}`);
  }
}
