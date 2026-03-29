import Foundation

public class Logger {

    public static let shared = Logger()

    private let tag = "CoconutSDK"
    private var isDebug = true

    public enum Level: Int {
        case debug = 0, info, warn, error, none
    }

    private var minLevel: Level = .debug

    public func setDebugMode(_ debug: Bool) {
        isDebug = debug
        minLevel = debug ? .debug : .warn
    }

    public func d(_ tag: String, _ message: String) {
        guard isDebug && minLevel.rawValue <= Level.debug.rawValue else { return }
        print("[\(self.tag)] [\(tag)] \(message)")
    }

    public func i(_ tag: String, _ message: String) {
        guard minLevel.rawValue <= Level.info.rawValue else { return }
        print("[\(self.tag)] [\(tag)] ℹ️ \(message)")
    }

    public func w(_ tag: String, _ message: String) {
        guard minLevel.rawValue <= Level.warn.rawValue else { return }
        print("[\(self.tag)] [\(tag)] ⚠️ \(message)")
    }

    public func e(_ tag: String, _ message: String, _ error: Error? = nil) {
        guard minLevel.rawValue <= Level.error.rawValue else { return }
        if let error = error {
            print("[\(self.tag)] [\(tag)] ❌ \(message): \(error)")
        } else {
            print("[\(self.tag)] [\(tag)] ❌ \(message)")
        }
    }
}
