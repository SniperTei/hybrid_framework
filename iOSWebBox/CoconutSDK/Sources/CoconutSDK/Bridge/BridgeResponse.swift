import Foundation

public struct BridgeResponse {

    public let jsonrpc: String
    public let id: String
    public let code: String
    public let message: String
    public let result: Any?

    private static let jsonrpcVersion = "2.0"

    private init(id: String, code: String, message: String, result: Any? = nil) {
        self.jsonrpc = BridgeResponse.jsonrpcVersion
        self.id = id
        self.code = code
        self.message = message
        self.result = result
    }

    public static func success(id: String, result: Any? = nil) -> BridgeResponse {
        return BridgeResponse(id: id, code: ErrorCode.SUCCESS, message: "success", result: result)
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
            "jsonrpc": jsonrpc,
            "id": id,
            "code": code,
            "message": message
        ]
        if let result = result {
            dict["result"] = result
        } else {
            dict["result"] = NSNull()
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return "{\"jsonrpc\":\"2.0\",\"id\":\"\(id)\",\"code\":\"\(ErrorCode.INTERNAL_ERROR)\",\"message\":\"JSON serialization error\",\"result\":null}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
