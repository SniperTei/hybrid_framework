import Foundation
import UIKit

public class ClipboardComponent: BaseComponent {

    override public var name: String { "clipboard" }
    override public var version: String { "1.0.0" }
    override public var pluginDescription: String { "Clipboard read/write component" }

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getText": return getText()
        case "setText": return try setText(params)
        case "hasText": return hasText()
        default: try functionNotSupportedError(function)
        }
    }

    private func getText() -> [String: Any] {
        let text = UIPasteboard.general.string ?? ""
        return success(["text": text, "hasText": !text.isEmpty])
    }

    private func setText(_ params: [String: Any]?) throws -> [String: Any] {
        let text = getParam(params, "text")
        if text.isEmpty { try error("200007", "Parameter 'text' is required") }
        UIPasteboard.general.string = text
        return success(["success": true])
    }

    private func hasText() -> [String: Any] {
        return success(["hasText": UIPasteboard.general.hasStrings])
    }
}
