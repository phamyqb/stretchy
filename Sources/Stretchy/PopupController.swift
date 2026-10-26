import AppKit
import SwiftUI

/// Panel không viền, nổi trên mọi thứ, không cướp focus của app đang dùng.
final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PopupController {
    static let shared = PopupController()
    private var panel: PopupPanel?

    static func message(for kind: ReminderKind) -> String {
        let s = AppSettings.shared
        let n = Int.random(in: 1...3)
        switch (kind, n) {
        case (.stand, 1): return tr("stand.msg.1", s.sitMinutes)
        case (.stand, 2): return tr("stand.msg.2", s.standMinutes)
        default: return tr("\(kind.rawValue).msg.\(n)")
        }
    }

    func show(kind: ReminderKind, onAction: @escaping (PopupAction) -> Void) {
        close(animated: false)
        let s = AppSettings.shared

        let root = PopupView(
            kind: kind,
            message: PopupController.message(for: kind),
            snoozeMinutes: s.snoozeMinutes,
            autoCloseSeconds: s.autoCloseSeconds,
            full: s.popupEffects == .full,
            onAction: onAction,
            onClose: { [weak self] in self?.close() }
        )

        let hosting = NSHostingView(rootView: root)
        hosting.setFrameSize(hosting.fittingSize)

        let p = PopupPanel(contentRect: NSRect(origin: .zero, size: hosting.frame.size),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = hosting

        position(p, at: s.popupPosition)
        p.alphaValue = 1
        p.orderFrontRegardless()
        panel = p
    }

    private func position(_ p: NSPanel, at pos: PopupPosition) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        let size = p.frame.size
        switch pos {
        case .center:
            p.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2 + 40))
        case .topRight:
            // panel có 60pt đệm trong suốt quanh card
            p.setFrameOrigin(NSPoint(x: vf.maxX - size.width + 40, y: vf.maxY - size.height + 40))
        }
    }

    func close(animated: Bool = true) {
        guard let p = panel else { return }
        panel = nil
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                p.animator().alphaValue = 0
            }, completionHandler: { p.orderOut(nil) })
        } else {
            p.orderOut(nil)
        }
    }
}
