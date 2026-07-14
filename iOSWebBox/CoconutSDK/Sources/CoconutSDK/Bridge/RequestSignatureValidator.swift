import Foundation
import CryptoKit

public class RequestSignatureValidator: @unchecked Sendable {

    public static let shared = RequestSignatureValidator()
    private let tag = "RequestSignature"

    public var enabled: Bool = false
    public var sharedSecret: String = ""
    public var timestampToleranceMs: Int64 = 300_000 // 5 minutes

    private let maxNonceCache = 1000
    private var nonceCache: [String: Int64] = [:]
    private let lock = NSLock()

    private init() {}

    public enum SignResult {
        case valid
        case invalid(errorCode: String, message: String)
    }

    public func validate(
        method: String, id: String, timestamp: Int64,
        nonce: String, paramsJson: String, sign: String
    ) -> SignResult {
        if !enabled { return .valid }

        // Check timestamp tolerance
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if timestamp <= 0 || abs(now - timestamp) > timestampToleranceMs {
            return .invalid(errorCode: ErrorCode.SIGNATURE_EXPIRED, message: "Request timestamp expired")
        }

        // Check nonce reuse
        if nonce.isEmpty {
            return .invalid(errorCode: ErrorCode.NONCE_REUSED, message: "Nonce is required when signing is enabled")
        }

        lock.lock()
        defer { lock.unlock() }

        if nonceCache[nonce] != nil {
            return .invalid(errorCode: ErrorCode.NONCE_REUSED, message: "Nonce already used")
        }

        // Compute expected signature using CryptoKit HMAC-SHA256
        let payload = "\(method)|\(id)|\(timestamp)|\(nonce)|\(paramsJson)"
        let expected = computeHmac(payload: payload)

        if expected.isEmpty {
            return .invalid(errorCode: ErrorCode.SIGNATURE_INVALID, message: "Signature verification failed")
        }

        if !constantTimeEquals(a: expected, b: sign) {
            return .invalid(errorCode: ErrorCode.SIGNATURE_INVALID, message: "Invalid signature")
        }

        // Record nonce with LRU eviction
        if nonceCache.count >= maxNonceCache, let oldestKey = nonceCache.keys.first {
            nonceCache.removeValue(forKey: oldestKey)
        }
        nonceCache[nonce] = now
        return .valid
    }

    private func computeHmac(payload: String) -> String {
        guard let keyData = sharedSecret.data(using: .utf8),
              let payloadData = payload.data(using: .utf8) else {
            return ""
        }
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    private func constantTimeEquals(a: String, b: String) -> Bool {
        if a.count != b.count { return false }
        var result = 0
        for (ca, cb) in zip(a, b) {
            result = result | (Int(ca.asciiValue ?? 0) ^ Int(cb.asciiValue ?? 0))
        }
        return result == 0
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        nonceCache.removeAll()
    }
}
