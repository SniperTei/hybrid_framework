import Foundation
import CryptoKit

/// Hot update manager for the offline H5 package — iOS counterpart of
/// Android's `OfflineResourceManager` update API.
///
/// Flow (semantics identical across platforms):
///   checkUpdate(moduleId, manifestUrl)
///     → fetch remote manifest, compare against max(sandbox, bundled) version
///   performUpdate(manifest, baseUrl)
///     → per-file download + md5 verification into `.staging_<moduleId>`,
///       then atomic swap; any failure leaves the old version untouched
///   rollback(moduleId)
///     → delete sandbox overlay + version entry, fall back to bundled package
///
/// Layout (reuses the scheme handler's sandbox):
///   <AppSupport>/CoconutResources/<moduleId>/...       module overlay
///   <AppSupport>/CoconutResources/version.json          {"<moduleId>": "<version>"}
///   <AppSupport>/CoconutResources/.staging_<moduleId>/  staging (cleared on entry/failure)
/// All state lives on disk (sandbox + version.json); stored properties are
/// immutable, so the type is freely Sendable.
public final class CoconutUpdateManager: Sendable {

    public static let shared = CoconutUpdateManager()

    private let tag = "CoconutUpdate"
    private let bundleRoot = "coconut-web"
    private let sandboxRootName = "CoconutResources"
    private let versionFileName = "version.json"
    private let manifestFileName = "manifest.json"
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Models

    public struct RemoteManifest: Codable {
        public var moduleId: String = ""
        public var version: String = ""
        public var entry: String = ""
        public var files: [String] = []
        public var md5: String = ""
        public var fileHashes: [String: String] = [:]

        public init(moduleId: String = "", version: String = "", entry: String = "",
                    files: [String] = [], md5: String = "", fileHashes: [String: String] = [:]) {
            self.moduleId = moduleId
            self.version = version
            self.entry = entry
            self.files = files
            self.md5 = md5
            self.fileHashes = fileHashes
        }
    }

    public struct UpdateCheckResult {
        public let available: Bool
        public let currentVersion: String
        public let remoteVersion: String
        public let manifest: RemoteManifest?
        public let error: String?

        static func unavailable(current: String, remote: String = "",
                                manifest: RemoteManifest? = nil, error: String? = nil) -> UpdateCheckResult {
            UpdateCheckResult(available: false, currentVersion: current,
                              remoteVersion: remote, manifest: manifest, error: error)
        }
    }

    public struct UpdateResult {
        public let success: Bool
        public let moduleId: String
        public let version: String
        public let error: String?

        static func ok(_ moduleId: String, _ version: String) -> UpdateResult {
            UpdateResult(success: true, moduleId: moduleId, version: version, error: nil)
        }
        static func failed(_ moduleId: String, _ version: String, _ error: String) -> UpdateResult {
            UpdateResult(success: false, moduleId: moduleId, version: version, error: error)
        }
    }

    // MARK: - Update API

    /// Fetch the remote manifest and decide whether an update is available.
    public func checkUpdate(moduleId: String, manifestUrl: String) async -> UpdateCheckResult {
        let current = currentVersion(moduleId: moduleId)
        guard let url = URL(string: manifestUrl) else {
            return .unavailable(current: current, error: "Invalid manifest URL: \(manifestUrl)")
        }
        let manifest: RemoteManifest
        do {
            let (data, _) = try await session.data(from: url)
            manifest = try JSONDecoder().decode(RemoteManifest.self, from: data)
        } catch {
            Logger.shared.e(tag, "Failed to fetch/parse manifest: \(error.localizedDescription)")
            return .unavailable(current: current, error: "Failed to fetch or parse manifest")
        }
        guard manifest.moduleId == moduleId else {
            return .unavailable(current: current, remote: manifest.version, manifest: manifest,
                                error: "moduleId mismatch: expected=\(moduleId) got=\(manifest.moduleId)")
        }
        let available = Self.decideUpdate(sandboxVersion: sandboxVersions()[moduleId],
                                          bundledVersion: bundledManifestVersion(moduleId: moduleId),
                                          remoteVersion: manifest.version)
        return UpdateCheckResult(available: available, currentVersion: current,
                                 remoteVersion: manifest.version, manifest: manifest, error: nil)
    }

    /// Download every manifest file, verify its md5, then atomically swap the
    /// module directory. On any failure the staging directory is removed and
    /// the previously installed version is left untouched.
    public func performUpdate(manifest: RemoteManifest, baseUrl: String) async -> UpdateResult {
        let moduleId = manifest.moduleId

        if let validationError = Self.validateManifest(manifest) {
            return .failed(moduleId, manifest.version, validationError)
        }

        let root = sandboxRoot()
        let staging = root.appendingPathComponent(".staging_\(moduleId)", isDirectory: true)
        try? FileManager.default.removeItem(at: staging)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

            for file in manifest.files {
                guard let fileUrl = URL(string: Self.joinUrl(baseUrl, file)) else {
                    throw UpdateError.badUrl(file)
                }
                let (data, _) = try await session.data(from: fileUrl)
                let expected = (manifest.fileHashes[file] ?? "").lowercased()
                let actual = Self.md5Hex(data)
                guard actual == expected else {
                    throw UpdateError.md5Mismatch(file: file, expected: expected, actual: actual)
                }
                let target = staging.appendingPathComponent(file)
                try FileManager.default.createDirectory(
                    at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: target)
            }

            try Self.swapStaged(sandboxRoot: root, moduleId: moduleId)
            var versions = sandboxVersions()
            versions[moduleId] = manifest.version
            saveVersions(versions)
            Logger.shared.i(tag, "Update applied: \(moduleId) v\(manifest.version)")
            return .ok(moduleId, manifest.version)
        } catch {
            Logger.shared.e(tag, "performUpdate failed: \(error)")
            try? FileManager.default.removeItem(at: staging)
            let message = (error as? UpdateError)?.description ?? error.localizedDescription
            return .failed(moduleId, manifest.version, message)
        }
    }

    /// Remove the sandbox copy of a module and its version entry, falling back
    /// to the bundled package.
    public func rollback(moduleId: String) async -> Bool {
        let moduleDir = sandboxRoot().appendingPathComponent(moduleId, isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: moduleDir.path) {
                try FileManager.default.removeItem(at: moduleDir)
            }
            var versions = sandboxVersions()
            versions.removeValue(forKey: moduleId)
            saveVersions(versions)
            Logger.shared.i(tag, "Rolled back \(moduleId) to bundled version")
            return true
        } catch {
            Logger.shared.e(tag, "rollback failed: \(error)")
            return false
        }
    }

    enum UpdateError: Error, CustomStringConvertible {
        case badUrl(String)
        case md5Mismatch(file: String, expected: String, actual: String)

        var description: String {
            switch self {
            case .badUrl(let file): return "Invalid URL for \(file)"
            case .md5Mismatch(let file, let expected, let actual):
                return "MD5 mismatch for \(file): expected=\(expected) actual=\(actual)"
            }
        }
    }

    // MARK: - Version persistence

    func sandboxRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(sandboxRootName, isDirectory: true)
    }

    func currentVersion(moduleId: String) -> String {
        var current = "0.0.0"
        for v in [sandboxVersions()[moduleId], bundledManifestVersion(moduleId: moduleId)].compactMap({ $0 }) {
            if Self.compareVersions(v, current) > 0 { current = v }
        }
        return current
    }

    func sandboxVersions() -> [String: String] {
        let file = sandboxRoot().appendingPathComponent(versionFileName)
        guard let data = try? Data(contentsOf: file),
              let versions = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return versions
    }

    private func saveVersions(_ versions: [String: String]) {
        let root = sandboxRoot()
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(versions) {
            try? data.write(to: root.appendingPathComponent(versionFileName))
        }
    }

    /// Bundled package version. Candidate roots mirror CoconutSchemeHandler
    /// lookupFile: SPM resource bundle first, then Bundle.main.
    func bundledManifestVersion(moduleId: String) -> String? {
        var candidateRoots: [URL] = []
        for owner in [Bundle(for: CoconutUpdateManager.self), Bundle.main] {
            if let spmBundleURL = owner.url(forResource: "CoconutSDK_CoconutSDK", withExtension: "bundle"),
               let spmBundle = Bundle(url: spmBundleURL), let root = spmBundle.resourceURL {
                candidateRoots.append(root)
            }
            if let root = owner.resourceURL {
                candidateRoots.append(root)
            }
        }
        for root in candidateRoots {
            let manifestUrl = root.appendingPathComponent(bundleRoot, isDirectory: true)
                .appendingPathComponent(moduleId, isDirectory: true)
                .appendingPathComponent(manifestFileName)
            if let data = try? Data(contentsOf: manifestUrl),
               let manifest = try? JSONDecoder().decode(RemoteManifest.self, from: data),
               manifest.moduleId == moduleId {
                return manifest.version
            }
        }
        return nil
    }

    static func joinUrl(_ baseUrl: String, _ path: String) -> String {
        baseUrl.hasSuffix("/") ? baseUrl + path : baseUrl + "/" + path
    }

    // MARK: - Pure helpers (aligned with Android companion functions)

    /// Compare two dotted version strings. Non-numeric segments parse as 0.
    public static func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.split(separator: ".").map { Int($0) ?? 0 }
        let parts2 = v2.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(parts1.count, parts2.count) {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 != p2 { return p1 - p2 }
        }
        return 0
    }

    /// Reject paths that could escape the module directory when written
    /// from a (potentially hostile) remote manifest.
    public static func isSafePackagePath(_ path: String) -> Bool {
        if path.isEmpty || path.hasPrefix("/") || path.contains("\\") { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    /// An update is available only when the remote version is strictly
    /// greater than both the sandbox version and the bundled version.
    public static func decideUpdate(sandboxVersion: String?, bundledVersion: String?, remoteVersion: String) -> Bool {
        var current = "0.0.0"
        for v in [sandboxVersion, bundledVersion].compactMap({ $0 }) {
            if compareVersions(v, current) > 0 { current = v }
        }
        return compareVersions(remoteVersion, current) > 0
    }

    /// Fail-closed manifest validation: non-empty file list, every file path
    /// safe, every file covered by a non-blank md5 entry.
    public static func validateManifest(_ manifest: RemoteManifest) -> String? {
        if manifest.files.isEmpty { return "manifest has no files" }
        for file in manifest.files {
            if !isSafePackagePath(file) { return "unsafe package path: \(file)" }
            guard let hash = manifest.fileHashes[file], !hash.isBlank else {
                return "missing fileHashes entry: \(file)"
            }
        }
        return nil
    }

    /// Atomic swap: drop the current module directory and rename the staging
    /// directory into its place. Throws on failure.
    public static func swapStaged(sandboxRoot: URL, moduleId: String) throws {
        let fm = FileManager.default
        let moduleDir = sandboxRoot.appendingPathComponent(moduleId, isDirectory: true)
        let staging = sandboxRoot.appendingPathComponent(".staging_\(moduleId)", isDirectory: true)
        if fm.fileExists(atPath: moduleDir.path) {
            try fm.removeItem(at: moduleDir)
        }
        try fm.moveItem(at: staging, to: moduleDir)
    }

    public static func md5Hex(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
