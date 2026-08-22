import Foundation

/// A self-contained JSON value tree (counterpart of kotlinx JsonElement /
/// ArkTS JSONValue). Pure Foundation — no Codable witness requirement, so
/// arbitrary server payloads can flow through the engine untouched.
public indirect enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: - Parsing

    /// Parse JSON data via JSONSerialization. Returns nil on invalid JSON.
    public static func parse(_ data: Data?) -> JSONValue? {
        guard let data, !data.isEmpty else { return nil }
        guard let any = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return from(any)
    }

    static func from(_ any: Any) -> JSONValue {
        switch any {
        case is NSNull:
            return .null
        case let number as NSNumber:
            if CFBooleanIsBoolean(number) { return .bool(number.boolValue) }
            return .number(number.doubleValue)
        case let bool as Bool:
            return .bool(bool)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { from($0) })
        case let object as [String: Any]:
            var result: [String: JSONValue] = [:]
            for (key, value) in object { result[key] = from(value) }
            return .object(result)
        default:
            return .string(String(describing: any))
        }
    }

    /// Build from a bridge-layer `[String: Any]` (e.g. NetworkComponent params).
    public static func from(any: Any) -> JSONValue { from(any) }

    // MARK: - Serialization

    /// Serialize back to JSON data (nil if the tree cannot be represented).
    public func serialized() -> Data? {
        guard let obj = nsObject else { return nil }
        return try? JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed])
    }

    /// Compact JSON string, e.g. `"payload"` for a string primitive.
    public func serializedString() -> String? {
        guard let data = serialized() else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Bridge-layer `[String: Any]` representation (JSONSerialization objects:
    /// NSNumber / String / NSArray / NSDictionary). App consumers use this to
    /// hand engine data to the `[String: Any]` bridge payload.
    public func anyValue() -> Any? { nsObject }

    var nsObject: Any? {
        switch self {
        case .null:
            return NSNull()
        case .bool(let b):
            return NSNumber(value: b)
        case .number(let n):
            // integral doubles serialize as ints (1.0 → 1), matching wire style
            if n.rounded() == n, abs(n) < 9.007199254740992e15 {
                return NSNumber(value: Int64(n))
            }
            return NSNumber(value: n)
        case .string(let s):
            return s
        case .array(let items):
            return items.compactMap { $0.nsObject }
        case .object(let object):
            var result: [String: Any] = [:]
            for (key, value) in object { result[key] = value.nsObject ?? NSNull() }
            return result
        }
    }

    // MARK: - Accessors

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var intValue: Int? {
        if case .number(let n) = self, n.rounded() == n, abs(n) < 9.007199254740992e15 {
            return Int(n)
        }
        if case .string(let s) = self { return Int(s) }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// String content of any primitive (number 1 → "1", bool → "true");
    /// nil for object/array. Mirrors kotlinx `JsonPrimitive.contentOrNull`.
    public var primitiveStringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.rounded() == n && abs(n) < 9.007199254740992e15 ? String(Int64(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let items) = self { return items }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let object) = self { return object }
        return nil
    }

    public subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }
}

/// NSNumber boolean detection (JSONSerialization gives NSNumber for both
/// bools and numbers; CFGetTypeID distinguishes them).
private func CFBooleanIsBoolean(_ number: NSNumber) -> Bool {
    CFGetTypeID(number) == CFBooleanGetTypeID()
}
