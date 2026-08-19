/**
 * CoconutNetwork Logger
 *
 * Minimal logging utility (console-based, no kit dependency).
 * Mirrors CoconutSDK Logger API so callers can swap easily.
 */
export class Logger {
  private static readonly TAG = 'CoconutNetwork';

  static d(tag: string, message: string): void {
    console.debug(`[${tag}] ${message}`);
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
}
