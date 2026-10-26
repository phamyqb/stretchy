import SwiftUI
import AppKit
import Combine

@main
struct StretchyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var engine = ReminderEngine.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var awake = KeepAwake.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: engine.isPaused ? "pause.circle" : (engine.isOffHours ? "moon.zzz" : "figure.stand"))
                if awake.isActive { Image(systemName: "cup.and.saucer.fill") }
                if !engine.menuTitle.isEmpty {
                    Text(engine.menuTitle).monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // không hiện icon trên Dock

        // Giao diện Sáng/Tối/Hệ thống (phát lại giá trị hiện tại ngay khi subscribe)
        AppSettings.shared.$theme
            .receive(on: DispatchQueue.main)
            .sink { theme in
                switch theme {
                case "light": NSApp.appearance = NSAppearance(named: .aqua)
                case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
                default:      NSApp.appearance = nil
                }
            }
            .store(in: &cancellables)

        ReminderEngine.shared.start()
    }
}
