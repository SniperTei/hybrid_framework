import XCTest
import CryptoKit
@testable import CoconutSDK

final class RequestSignatureValidatorTests: XCTestCase {

    private let sharedSecret = "test-secret-12345"
    private var validator: RequestSignatureValidator { .shared }

    private let method = "device.getInfo"
    private let id = "req-1"
    private let paramsJson = "{\"key\":\"value\"}"

    override func setUp() {
        super.setUp()
        validator.reset()
        validator.enabled = true
        validator.sharedSecret = sharedSecret
        validator.timestampToleranceMs = 300_000
    }

    override func tearDown() {
        validator.reset()
        validator.enabled = false
        validator.sharedSecret = ""
        super.tearDown()
    }

    /// Compute the expected HMAC-SHA256 hex signature for the given inputs.
    private func sign(method: String, id: String, timestamp: Int64, nonce: String, paramsJson: String) -> String {
        let payload = "\(method)|\(id)|\(timestamp)|\(nonce)|\(paramsJson)"
        let key = SymmetricKey(data: sharedSecret.data(using: .utf8)!)
        let mac = HMAC<SHA256>.authenticationCode(for: payload.data(using: .utf8)!, using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    private func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - disabled

    func testDisabledAcceptsAnySignature() {
        validator.enabled = false
        let result = validator.validate(
            method: method, id: id, timestamp: 0,
            nonce: "", paramsJson: paramsJson, sign: "garbage"
        )
        if case .invalid(let code, _) = result {
            XCTFail("Expected valid but got \(code)")
        }
    }

    // MARK: - happy path

    func testValidSignaturePassesAndRecordsNonce() {
        let nonce = "nonce-1"
        let ts = nowMs()
        let signature = sign(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson)
        let result = validator.validate(
            method: method, id: id, timestamp: ts,
            nonce: nonce, paramsJson: paramsJson, sign: signature
        )
        if case .invalid(let code, _) = result {
            XCTFail("Expected valid, got \(code)")
        }
    }

    // MARK: - nonce reuse

    func testReusedNonceRejected() {
        let nonce = "nonce-reuse"
        let ts = nowMs()
        let signature = sign(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson)

        // First use → valid
        let r1 = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson, sign: signature)
        if case .invalid(let code, _) = r1 { XCTFail("First use should be valid, got \(code)") }

        // Second use → NONCE_REUSED
        let r2 = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson, sign: signature)
        guard case .invalid(let code, _) = r2 else {
            XCTFail("Expected NONCE_REUSED")
            return
        }
        XCTAssertEqual(code, ErrorCode.NONCE_REUSED)
    }

    func testEmptyNonceRejectedAsReused() {
        let ts = nowMs()
        let signature = sign(method: method, id: id, timestamp: ts, nonce: "", paramsJson: paramsJson)
        let result = validator.validate(method: method, id: id, timestamp: ts, nonce: "", paramsJson: paramsJson, sign: signature)
        guard case .invalid(let code, _) = result else {
            XCTFail("Expected NONCE_REUSED for empty nonce")
            return
        }
        XCTAssertEqual(code, ErrorCode.NONCE_REUSED)
    }

    // MARK: - signature invalid

    func testWrongSignatureRejected() {
        let nonce = "nonce-wrong-sign"
        let ts = nowMs()
        let result = validator.validate(
            method: method, id: id, timestamp: ts,
            nonce: nonce, paramsJson: paramsJson, sign: "deadbeef"
        )
        guard case .invalid(let code, _) = result else {
            XCTFail("Expected SIGNATURE_INVALID")
            return
        }
        XCTAssertEqual(code, ErrorCode.SIGNATURE_INVALID)
    }

    // MARK: - timestamp expiry

    func testExpiredTimestampRejected() {
        let nonce = "nonce-expired"
        // 10 minutes ago, outside 5-min tolerance
        let ts = nowMs() - 600_000
        let signature = sign(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson)
        let result = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson, sign: signature)
        guard case .invalid(let code, _) = result else {
            XCTFail("Expected SIGNATURE_EXPIRED")
            return
        }
        XCTAssertEqual(code, ErrorCode.SIGNATURE_EXPIRED)
    }

    func testFutureTimestampRejected() {
        let nonce = "nonce-future"
        let ts = nowMs() + 600_000
        let signature = sign(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson)
        let result = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson, sign: signature)
        guard case .invalid(let code, _) = result else {
            XCTFail("Expected SIGNATURE_EXPIRED for future timestamp")
            return
        }
        XCTAssertEqual(code, ErrorCode.SIGNATURE_EXPIRED)
    }

    func testZeroTimestampRejected() {
        let nonce = "nonce-zero"
        let signature = sign(method: method, id: id, timestamp: 0, nonce: nonce, paramsJson: paramsJson)
        let result = validator.validate(method: method, id: id, timestamp: 0, nonce: nonce, paramsJson: paramsJson, sign: signature)
        guard case .invalid(let code, _) = result else {
            XCTFail("Expected SIGNATURE_EXPIRED for zero timestamp")
            return
        }
        XCTAssertEqual(code, ErrorCode.SIGNATURE_EXPIRED)
    }

    // MARK: - LRU eviction

    func testNonceCacheEvictsOldestAfter1000Entries() {
        // Fill 1000 distinct nonces (indices 0..999). Each is recorded.
        for i in 0..<1000 {
            let nonce = "nonce-\(i)"
            let ts = nowMs()
            let signature = sign(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson)
            let result = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson, sign: signature)
            if case .invalid(let code, _) = result {
                XCTFail("Nonce \(i) should be valid, got \(code)")
                return
            }
        }

        // Insert one more (index 1000) → should evict nonce-0 (oldest).
        let nonce1000 = "nonce-1000"
        let ts = nowMs()
        let sig1000 = sign(method: method, id: id, timestamp: ts, nonce: nonce1000, paramsJson: paramsJson)
        let r = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce1000, paramsJson: paramsJson, sign: sig1000)
        if case .invalid(let code, _) = r {
            XCTFail("Nonce 1000 should be valid, got \(code)")
            return
        }

        // nonce-0 should now be evicted: reusing it with a fresh valid signature should NOT be NONCE_REUSED.
        let nonce0 = "nonce-0"
        let ts2 = nowMs()
        let sig0 = sign(method: method, id: id, timestamp: ts2, nonce: nonce0, paramsJson: paramsJson)
        let r2 = validator.validate(method: method, id: id, timestamp: ts2, nonce: nonce0, paramsJson: paramsJson, sign: sig0)
        if case .invalid(let code, _) = r2 {
            // It's fine if it's some error, but NOT NONCE_REUSED (that would mean eviction failed)
            XCTAssertNotEqual(code, ErrorCode.NONCE_REUSED, "nonce-0 was not evicted (LRU broken)")
        }
    }

    // MARK: - reset

    func testResetClearsNonceCache() {
        let nonce = "nonce-reset-test"
        let ts = nowMs()
        let signature = sign(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson)
        _ = validator.validate(method: method, id: id, timestamp: ts, nonce: nonce, paramsJson: paramsJson, sign: signature)

        // Same nonce after reset → should be valid (cache cleared)
        validator.reset()
        let ts2 = nowMs()
        let signature2 = sign(method: method, id: id, timestamp: ts2, nonce: nonce, paramsJson: paramsJson)
        let result = validator.validate(method: method, id: id, timestamp: ts2, nonce: nonce, paramsJson: paramsJson, sign: signature2)
        if case .invalid(let code, _) = result {
            XCTAssertEqual(code, ErrorCode.NONCE_REUSED, "Unexpected error after reset")
            XCTFail("Nonce should be valid after reset")
        }
    }
}
