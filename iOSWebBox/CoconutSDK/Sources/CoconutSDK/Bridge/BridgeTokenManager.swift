import Foundation

public class BridgeTokenManager: @unchecked Sendable {

    public static let shared = BridgeTokenManager()
    private let tag = "BridgeTokenManager"

    private var token: String = ""
    public var enabled: Bool = true

    private init() {}

    @discardableResult
    public func generateToken() -> String {
        token = UUID().uuidString
        Logger.shared.d(tag, "Bridge token generated")
        return token
    }

    public func getToken() -> String { token }

    public func validateToken(_ requestToken: String) -> Bool {
        if !enabled { return true }
        // Fail-closed: an empty token means "never initialized" or "reset without
        // regenerate". Previously this returned true (fail-open), which created a
        // silent bypass window if reset() was called at runtime without an
        // immediate generateToken(). Returning false forces the caller to
        // generate a token before any bridge call can succeed.
        if token.isEmpty { return false }
        return token == requestToken
    }

    public func reset() {
        token = ""
        Logger.shared.d(tag, "Bridge token reset")
    }
}
