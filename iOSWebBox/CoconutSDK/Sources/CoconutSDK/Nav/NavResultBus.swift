import Foundation

/**
 * Single-slot result bus for coconut.navigator.close({result}) (v3.5.0).
 *
 * The closing container (B) posts its result; the previous container (A)
 * drains it on resume and pushes `nav.result` to its H5. A single slot is
 * provably sufficient: the modal / back stack is LIFO, so at most one
 * closing child hands control back to its immediate predecessor.
 */
public final class NavResultBus {

    private static let state = State()

    /// Lock-protected mutable slot (@unchecked Sendable: all access holds the lock).
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var pending: String?
    }

    /// Store the raw result payload (JSON text for object/array results,
    /// plain text for primitives — see NavigatorComponent.close).
    public static func post(_ result: String) {
        state.lock.lock()
        state.pending = result
        state.lock.unlock()
    }

    /// Take (and clear) the pending result, if any.
    public static func consume() -> String? {
        state.lock.lock()
        defer { state.lock.unlock() }
        let value = state.pending
        state.pending = nil
        return value
    }
}
