import Foundation

/**
 * Container navigation-bar configuration (v3.5.0 container-nav).
 *
 * All fields are optional override slots: nil = inherit from the next level
 * down in the three-tier chain
 *
 *   forward header (per-call) > template subclass default > CoconutConfig.nav (global)
 *
 * merged field-by-field via `merge`. Resolved defaults come from `default`:
 * visible bar, AUTO title (syncs document.title), AUTO close policy
 * (× only when the WebView history is exhausted).
 *
 * JSON override shape (forward header):
 * `{"visible":false, "title":"订单详情"|"auto", "closePolicy":"always"|"auto",
 *   "leftButtonText":"取消", "rightButtonText":"分享"}`
 */
public struct NavConfig: Equatable {

    /// AUTO syncs document.title (KVO webView.title); FIXED shows static text.
    public enum TitleMode: Equatable {
        case auto
        case fixed(String)
    }

    public enum ClosePolicy: Equatable {
        case auto
        case always
    }

    public var visible: Bool?
    public var titleMode: TitleMode?
    public var closePolicy: ClosePolicy?
    public var leftButtonText: String?
    public var rightButtonText: String?

    public init(
        visible: Bool? = nil,
        titleMode: TitleMode? = nil,
        closePolicy: ClosePolicy? = nil,
        leftButtonText: String? = nil,
        rightButtonText: String? = nil
    ) {
        self.visible = visible
        self.titleMode = titleMode
        self.closePolicy = closePolicy
        self.leftButtonText = leftButtonText
        self.rightButtonText = rightButtonText
    }

    /**
     * Whether the close (×) button should show at this history state.
     * ALWAYS shows unconditionally; AUTO (and unresolved nil) only at the
     * stack root (canGoBack=false) so the user always has an exit.
     */
    public func shouldShowClose(canGoBack: Bool) -> Bool {
        switch closePolicy {
        case .always: return true
        default: return !canGoBack
        }
    }

    /// Full default: visible bar, AUTO title, AUTO close policy.
    public static func `default`() -> NavConfig {
        NavConfig(visible: true, titleMode: .auto, closePolicy: .auto)
    }

    /// Field-by-field merge; nil fields in `override` inherit from `base`.
    public static func merge(base: NavConfig, override: NavConfig) -> NavConfig {
        NavConfig(
            visible: override.visible ?? base.visible,
            titleMode: override.titleMode ?? base.titleMode,
            closePolicy: override.closePolicy ?? base.closePolicy,
            leftButtonText: override.leftButtonText ?? base.leftButtonText,
            rightButtonText: override.rightButtonText ?? base.rightButtonText
        )
    }

    /**
     * Parse a JSON override object. Returns nil on malformed JSON —
     * callers treat that as "no override" rather than crashing the launch.
     */
    public static func parseOverride(_ json: String) -> NavConfig? {
        guard let data = json.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        var config = NavConfig()
        if let visible = obj["visible"] as? Bool {
            config.visible = visible
        }
        if let title = obj["title"] as? String {
            if title.caseInsensitiveCompare("auto") == .orderedSame {
                config.titleMode = .auto
            } else {
                config.titleMode = .fixed(title)
            }
        }
        // "always" (case-insensitive) → ALWAYS; anything else inherits (nil)
        if let policy = obj["closePolicy"] as? String,
           policy.caseInsensitiveCompare("always") == .orderedSame {
            config.closePolicy = .always
        }
        if let left = obj["leftButtonText"] as? String {
            config.leftButtonText = left
        }
        if let right = obj["rightButtonText"] as? String {
            config.rightButtonText = right
        }
        return config
    }
}
