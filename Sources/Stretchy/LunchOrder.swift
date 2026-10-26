import AppKit
import WebKit

enum LunchOrder {
    /// Mở trang đặt cơm theo cách đã chọn (trình duyệt mặc định hoặc webview trong app)
    static func open() {
        let s = AppSettings.shared
        guard let url = s.lunchURLValue else { return }
        if s.lunchOpenMode == "webview" {
            LunchWebWindowController.shared.show(url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

final class LunchWebWindowController {
    static let shared = LunchWebWindowController()
    private var window: NSWindow?
    private var web: WKWebView?

    func show(_ url: URL) {
        if window == nil {
            let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
            let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable],
                               backing: .buffered, defer: false)
            win.contentView = w
            win.title = tr("lunch.window.title")
            win.isReleasedWhenClosed = false
            win.center()
            web = w
            window = win
        }
        web?.load(URLRequest(url: url))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
