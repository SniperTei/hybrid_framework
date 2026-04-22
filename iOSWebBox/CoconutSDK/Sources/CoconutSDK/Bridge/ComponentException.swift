import Foundation

public class ComponentException: Error {
    public let code: String
    public let message: String

    public init(code: String = "200001", message: String) {
        self.code = code
        self.message = message
    }
}

public class ComponentNotFoundException: ComponentException {
    public init(_ message: String) {
        super.init(code: ErrorCode.UNKNOWN_COMPONENT, message: message)
    }
}

public class ComponentNotInitializedException: ComponentException {
    public init(_ message: String) {
        super.init(code: ErrorCode.COMPONENT_NOT_INITIALIZED, message: message)
    }
}
