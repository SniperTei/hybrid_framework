import Foundation
import CoconutSDK

private struct TemplateEntry: Decodable {
    let templateName: String
    /// "ModuleName.ClassName" — NSClassFromString requires the module prefix;
    /// a bare class name resolves to nil silently.
    let templatePage: String
}

/**
 * Container template registry (v3.5.0): bundle `coconut_templates.json` →
 * {name: CoconutWebViewController subclass}. Templates are how hosts extend
 * the standard container with custom UI / behavior (iOS has real
 * subclassing; no composition needed).
 *
 * Validation is strict and fail-fast (duplicates, unresolvable class names,
 * classes outside the CoconutWebViewController hierarchy all throw) — an
 * eagerly-validated registry at startup beats a broken forward at runtime.
 * Lazy-cached after first resolve.
 */
@MainActor
public final class TemplateRegistry {

    public static let shared = TemplateRegistry()

    public struct TemplateError: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    private var cache: [String: CoconutWebViewController.Type]?

    private init() {}

    /// Validated {name: class} map, cached. Missing bundle file → empty map
    /// (forward reports "template not registered" business failure).
    public func resolve() -> [String: CoconutWebViewController.Type] {
        if let cache { return cache }
        do {
            let map = try loadAndValidate()
            cache = map
            return map
        } catch {
            // Startup eager validation surfaces this loudly; runtime path
            // degrades to "no templates" instead of crashing a forward.
            NSLog("[TemplateRegistry] template registry unavailable: \(error.localizedDescription)")
            cache = [:]
            return [:]
        }
    }

    /// Eager validation hook for app startup (SceneDelegate): throws on any
    /// malformed entry so bad registries fail at launch, not at forward.
    public func validateEagerly() throws {
        _ = try loadAndValidate()
    }

    private func loadAndValidate() throws -> [String: CoconutWebViewController.Type] {
        guard let url = Bundle.main.url(forResource: "coconut_templates", withExtension: "json") else {
            throw TemplateError(message: "coconut_templates.json not found in main bundle")
        }
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([TemplateEntry].self, from: data)

        var map: [String: CoconutWebViewController.Type] = [:]
        for entry in entries {
            if map[entry.templateName] != nil {
                throw TemplateError(message: "duplicate templateName: \(entry.templateName)")
            }
            guard let cls = NSClassFromString(entry.templatePage) else {
                throw TemplateError(message: "class not found: \(entry.templatePage) (needs 'Module.Class' format)")
            }
            guard let vcType = cls as? CoconutWebViewController.Type else {
                throw TemplateError(message: "\(entry.templatePage) is not a CoconutWebViewController subclass")
            }
            map[entry.templateName] = vcType
        }
        return map
    }
}
