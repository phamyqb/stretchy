import SwiftUI

struct MenuBarView: View {
    @ObservedObject var engine = ReminderEngine.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var awake = KeepAwake.shared

    var body: some View {
        Text(engine.statusText())
        Text(tr("menu.today", engine.todayCount))
        if settings.waterEnabled {
            Text(tr("menu.water", engine.todayWater))
        }

        Divider()

        Button(tr("menu.changeNow")) { engine.changePostureNow() }
        if settings.waterEnabled {
            Button(tr("menu.drankNow")) { engine.logWater() }
        }
        Button(tr("menu.remindNow")) { engine.preview() }

        Divider()

        if engine.isPaused {
            Button(tr("menu.resume")) { engine.resume() }
        } else {
            Menu(tr("menu.pause")) {
                Button(tr("menu.pause.30")) { engine.pause(minutes: 30) }
                Button(tr("menu.pause.60")) { engine.pause(minutes: 60) }
                Button(tr("menu.pause.day")) { engine.pauseUntilTomorrow() }
            }
        }

        Divider()

        if awake.isActive {
            Button(tr("awake.menu.stop", awake.remainingText() ?? "∞")) { awake.stop() }
        } else {
            Menu(tr("awake.menu")) {
                Button(tr("awake.30")) { awake.start(minutes: 30) }
                Button(tr("awake.60")) { awake.start(minutes: 60) }
                Button(tr("awake.120")) { awake.start(minutes: 120) }
                Button(tr("awake.forever")) { awake.startIndefinitely() }
                Divider()
                Button(tr("awake.menu.custom")) { SettingsWindowController.shared.show() }
            }
        }

        Divider()

        Button(tr("menu.settings")) { SettingsWindowController.shared.show() }
            .keyboardShortcut(",")
        Button(tr("menu.quit")) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
