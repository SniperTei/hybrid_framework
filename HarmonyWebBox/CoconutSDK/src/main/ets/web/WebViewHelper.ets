/**
 * WebView Helper
 *
 * Security and configuration helpers for WebView
 */
export class WebViewHelper {
  /**
   * Build the JavaScript config injection script
   */
  static buildConfigScript(configJson: string): string {
    return `window.__coconutConfig = ${configJson};`;
  }

  /**
   * Escape JSON for safe embedding in JavaScript string
   */
  static escapeJson(json: string): string {
    return json
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t');
  }
}
