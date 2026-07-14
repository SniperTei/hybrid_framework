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
        if token.isEmpty { return true }
        return token == requestToken
    }

    public func reset() {
        token = ""
        Logger.shared.d(tag, "Bridge token reset")
    }
}
