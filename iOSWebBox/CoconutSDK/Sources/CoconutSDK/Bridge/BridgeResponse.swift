import Foundation

public struct BridgeResponse {

    public let id: String
    public let code: String
    public let message: String
    public let result: Any?
    public let streaming: Bool?

    private init(id: String, code: String, message: String, result: Any? = nil, streaming: Bool? = nil) {
        self.id = id
        self.code = code
        self.message = message
        self.result = result
        self.streaming = streaming
    }

    public static func success(id: String, result: Any? = nil) -> BridgeResponse {
        return BridgeResponse(id: id, code: ErrorCode.SUCCESS, message: "success", result: result)
    }

    /// Streaming response: coconut.js fires the callback but keeps it registered
    /// for subsequent responses with the same id (and resets the timeout timer).
    /// Send a final non-streaming response (omit `streaming`) to release the callback.
    public static func streaming(id: String, result: Any? = nil) -> BridgeResponse {
        return BridgeResponse(id: id, code: ErrorCode.SUCCESS, message: "success", result: result, streaming: true)
    }

    public static func error(id: String, code: String, message: String) -> BridgeResponse {
        return BridgeResponse(id: id, code: code, message: message, result: nil)
    }

    public static func parseError(id: String, message: String = "Parse error") -> BridgeResponse {
        return error(id: id, code: ErrorCode.PARSE_ERROR, message: message)
    }

    public static func invalidRequest(id: String, message: String = "Invalid request") -> BridgeResponse {
        return error(id: id, code: ErrorCode.INVALID_REQUEST, message: message)
    }

    public static func methodNotFound(id: String, method: String) -> BridgeResponse {
        return error(id: id, code: ErrorCode.METHOD_NOT_FOUND, message: "Method not found: \(method)")
    }

    public static func invalidParams(id: String, message: String = "Invalid params") -> BridgeResponse {
        return error(id: id, code: ErrorCode.INVALID_PARAMS, message: message)
    }

    public static func internalError(id: String, message: String = "Internal error") -> BridgeResponse {
        return error(id: id, code: ErrorCode.INTERNAL_ERROR, message: message)
    }

    public var isSuccess: Bool { code == ErrorCode.SUCCESS }

    public func toJSON() -> String {
        var dict: [String: Any] = [
            "id": id,
            "code": code,
            "message": message
        ]
        if let result = result {
            dict["result"] = result
        } else {
            dict["result"] = NSNull()
        }
        // Omit streaming when nil so one-shot responses don't leak the field
        // (coconut.js keys strictly off streaming === true).
        if let streaming = streaming {
            dict["streaming"] = streaming
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return "{\"id\":\"\(id)\",\"code\":\"\(ErrorCode.INTERNAL_ERROR)\",\"message\":\"JSON serialization error\",\"result\":null}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
