import Foundation
import WebKit

/// WKURLSchemeHandler serving the offline H5 package via the `coconut://` scheme.
///
/// URL shape: `coconut://<moduleId>/<path>` — host is the module id, path is
/// the file path inside the package (aligned with Android's
/// `coconut-web/<moduleId>/<path>` asset layout).
///
/// Lookup order per file:
///   1. Sandbox overlay `<AppSupport>/CoconutResources/<moduleId>/<path>`
///      (hot-update layer; prepared for future update flows)
///   2. Bundle resource `coconut-web/<moduleId>/<path>` (built-in package)
///   3. 404 response (a scheme task must always receive a response, not just
///      didFailWithError, otherwise the page hangs)
public final class CoconutSchemeHandler: NSObject, WKURLSchemeHandler {

    private let tag = "CoconutScheme"
    private let bundleRoot = "coconut-web"
    private let sandboxRootName = "CoconutResources"

    /// In-flight scheme tasks. WKURLSchemeTask callbacks after webView(_:stop:)
    /// raise an Obj-C exception and crash, so every callback checks membership.
    private let lock = NSLock()
    private var activeTasks: Set<ObjectIdentifier> = []

    // MARK: - WKURLSchemeHandler

    public func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        lock.lock()
        activeTasks.insert(ObjectIdentifier(task))
        lock.unlock()

        let requestUrl = task.request.url

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let url = requestUrl
            let parsed = url.flatMap { Self.parseOfflinePath($0) }

            let data: Data
            let mimeType: String
            let status: Int

            if let parsed {
                if let found = self.lookupFile(moduleId: parsed.moduleId, path: parsed.path) {
                    data = found
                    mimeType = Self.mimeType(forPath: parsed.path)
                    status = 200
                    Logger.shared.d(self.tag, "Serving offline: \(parsed.moduleId)/\(parsed.path) (\(found.count) bytes)")
                } else {
                    data = Data("Not Found: coconut://\(parsed.moduleId)/\(parsed.path)".utf8)
                    mimeType = "text/plain"
                    status = 404
                    Logger.shared.e(self.tag, "Offline resource missing: \(parsed.moduleId)/\(parsed.path)")
                }
            } else {
                data = Data("Invalid coconut:// URL: \(url?.absoluteString ?? "nil")".utf8)
                mimeType = "text/plain"
                status = 400
            }

            let response = Self.makeResponse(for: url, mimeType: mimeType, status: status, data: data)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.isActive(task) else { return }
                task.didReceive(response)
                guard self.isActive(task) else { return }
                task.didReceive(data)
                guard self.isActive(task) else { return }
                task.didFinish()
            }
        }
    }

    public func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        lock.lock()
        activeTasks.remove(ObjectIdentifier(task))
        lock.unlock()
    }

    private func isActive(_ task: WKURLSchemeTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeTasks.contains(ObjectIdentifier(task))
    }

    // MARK: - File Lookup

    private func lookupFile(moduleId: String, path: String) -> Data? {
        // Path traversal guard: reject anything escaping the package root.
        guard !moduleId.contains("/") && !moduleId.contains(".."),
              !path.contains("..") else {
            return nil
        }

        // 1. Sandbox overlay (hot-update layer)
        if let sandbox = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(sandboxRootName, isDirectory: true)
            .appendingPathComponent(moduleId, isDirectory: true) {
            let file = sandbox.appendingPathComponent(path)
            if let data = try? Data(contentsOf: file) {
                return data
            }
        }

        // 2. SDK resource bundle (built-in package). SPM `.copy` preserves the
        //    coconut-web/<moduleId>/ structure inside the generated
        //    CoconutSDK_CoconutSDK.bundle; host apps embedding their own package
        //    flat in Bundle.main are also honored.
        var candidateRoots: [URL] = []
        for owner in [Bundle(for: CoconutSchemeHandler.self), Bundle.main] {
            if let spmBundleURL = owner.url(forResource: "CoconutSDK_CoconutSDK", withExtension: "bundle"),
               let spmBundle = Bundle(url: spmBundleURL), let root = spmBundle.resourceURL {
                candidateRoots.append(root)
            }
            if let root = owner.resourceURL {
                candidateRoots.append(root)
            }
        }
        for root in candidateRoots {
            if let data = try? Data(contentsOf: root
                .appendingPathComponent(bundleRoot, isDirectory: true)
                .appendingPathComponent(moduleId, isDirectory: true)
                .appendingPathComponent(path)) {
                return data
            }
        }

        return nil
    }

    // MARK: - Pure helpers (unit-testable without a WebView)

    /// Parses `coconut://demo/index.html` into ("demo", "index.html").
    /// Empty path resolves to the package entry "index.html".
    public static func parseOfflinePath(_ url: URL) -> (moduleId: String, path: String)? {
        guard url.scheme?.lowercased() == "coconut",
              let moduleId = url.host, !moduleId.isEmpty else {
            return nil
        }
        var path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty {
            path = "index.html"
        }
        return (moduleId, path)
    }

    /// MIME table aligned with Android OfflineResourceManager.getMimeType.
    public static func mimeType(forPath path: String) -> String {
        switch path.lowercased().split(separator: ".").last {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json", "map": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        default: return "application/octet-stream"
        }
    }

    public static func makeResponse(for url: URL?, mimeType: String, status: Int, data: Data) -> HTTPURLResponse {
        let header = ["Content-Type": mimeType,
                      "Content-Length": String(data.count),
                      "Cache-Control": "no-cache"]
        return HTTPURLResponse(
            url: url ?? URL(string: "coconut://invalid")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: header
        )!
    }
}
