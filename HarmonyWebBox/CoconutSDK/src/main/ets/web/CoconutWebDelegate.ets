/**
 * Optional behavioral hooks for a CoconutWebPage host (container-nav
 * design #23: composition over inheritance — the host overrides only
 * what it needs; every method has a no-op default).
 *
 * The delegate is a plain class (not a struct/interface) so host route
 * pages can subclass it:
 *
 *   class MyDelegate extends CoconutWebDelegate {
 *     onBack(): boolean { ... return true; }  // intercept default back
 *   }
 */
export class CoconutWebDelegate {
  /**
   * Called before default back handling (nav-bar back tap / onBackPress).
   * Return true to intercept (suppress the default goBack-or-close
   * semantics); false to proceed with the default.
   */
  onBack(): boolean {
    return false;
  }

  /**
   * Main-frame network-level load failure (white-screen risk; HTTP
   * 4xx/5xx responses that render a body are excluded by design #5).
   */
  onLoadFail(error: string): void {
  }

  /**
   * document.title changed (onTitleReceive) or a page finished loading
   * (getTitle() fallback). Drives AUTO-mode nav-bar title sync.
   */
  onTitleChange(title: string): void {
  }

  /**
   * WebView history changed — canGoBack recomputed on page begin/end.
   * Drives close-button (×) visibility under AUTO close policy.
   */
  onHistoryChange(canGoBack: boolean): void {
  }
}
