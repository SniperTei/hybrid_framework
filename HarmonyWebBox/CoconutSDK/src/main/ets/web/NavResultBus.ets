/**
 * Single-slot result bus for coconut.navigator.close({result}).
 *
 * The closing container (B) posts its result; the previous container (A)
 * drains it on resume and pushes `nav.result` to its H5. A single slot is
 * provably sufficient: the router stack is LIFO, so at most one closing
 * child hands control back to its immediate predecessor.
 *
 * ArkTS port of Android coconut-sdk web/NavResultBus.kt.
 */
export class NavResultBus {
  private static pending: string | null = null;

  static post(result: string): void {
    NavResultBus.pending = result;
  }

  static consume(): string | null {
    const value = NavResultBus.pending;
    NavResultBus.pending = null;
    return value;
  }
}
