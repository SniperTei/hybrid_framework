import Foundation
import CoconutSDK

public class ResourceComponent: BaseComponent {
    public init() { super.init() }

    override public var name: String { "resource" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Resource and offline package management component" }

    private var componentContext: ComponentContext?
    private let resourceDirectory = "CoconutResources"

    override public func onInit(context: ComponentContext) async {
        componentContext = context
        ensureResourceDirectory()
    }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getVersion": return try getVersion(params)
        case "getAllVersions": return getAllVersions()
        case "checkUpdate": return try await checkUpdate(params)
        case "applyUpdate": return try await applyUpdate(params)
        default: try functionNotSupportedError(function)
        }
    }

    private func getVersion(_ params: [String: Any]?) throws -> [String: Any] {
        let name = getParam(params, "name")
        if name.isEmpty { try error("200007", "Parameter 'name' is required") }

        let key = resourceVersionKey(name)
        let version = UserDefaults.standard.string(forKey: key) ?? ""

        return success([
            "name": name,
            "version": version,
            "exists": !version.isEmpty
        ])
    }

    private func getAllVersions() -> [String: Any] {
        let prefix = "coconut_resource_"
        let allDefaults = UserDefaults.standard.dictionaryRepresentation()
        let versions = allDefaults
            .filter { $0.key.hasPrefix(prefix) }
            .mapValues { "\($0)" }

        let list = versions.map { (key, version) -> [String: Any] in
            let name = String(key.dropFirst(prefix.count))
            return ["name": name, "version": version]
        }

        return success(["count": list.count, "resources": list])
    }

    private func checkUpdate(_ params: [String: Any]?) async throws -> [String: Any] {
        let name = getParam(params, "name")
        let remoteUrl = getParam(params, "url")
        let remoteVersion = getParam(params, "version")

        if name.isEmpty || remoteUrl.isEmpty {
            try error("200007", "Parameters 'name' and 'url' are required")
        }

        let currentVersion = UserDefaults.standard.string(forKey: resourceVersionKey(name)) ?? ""
        let hasUpdate = currentVersion.isEmpty || (!remoteVersion.isEmpty && remoteVersion != currentVersion)

        return success([
            "name": name,
            "currentVersion": currentVersion,
            "remoteVersion": remoteVersion,
            "hasUpdate": hasUpdate
        ])
    }

    private func applyUpdate(_ params: [String: Any]?) async throws -> [String: Any] {
        let name = getParam(params, "name")
        let remoteUrl = getParam(params, "url")
        let version = getParam(params, "version")

        if name.isEmpty || remoteUrl.isEmpty {
            try error("200007", "Parameters 'name' and 'url' are required")
        }

        do {
            guard let url = URL(string: remoteUrl) else {
                try error("200007", "Invalid URL: \(remoteUrl)")
            }

            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            guard statusCode == 200 else {
                return success(["success": false, "error": "HTTP \(statusCode)"])
            }

            let filePath = resourceFilePath(name)
            try data.write(to: filePath)

            if !version.isEmpty {
                UserDefaults.standard.set(version, forKey: resourceVersionKey(name))
            }

            return success([
                "success": true,
                "name": name,
                "version": version,
                "size": data.count
            ])
        } catch {
            return success(["success": false, "error": error.localizedDescription])
        }
    }

    private func ensureResourceDirectory() {
        let dir = resourceDirectoryURL()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func resourceDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(resourceDirectory)
    }

    private func resourceFilePath(_ name: String) -> URL {
        return resourceDirectoryURL().appendingPathComponent(name)
    }

    private func resourceVersionKey(_ name: String) -> String {
        return "coconut_resource_\(name)"
    }

    override public func onCleanup() async {
        componentContext = nil
    }
}
