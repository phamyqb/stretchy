import SwiftUI
import AppKit
import ServiceManagement

enum SettingsTab: Hashable { case general, reminders, schedule, lunch, awake, popup, sound, about }

final class SettingsNav: ObservableObject {
    static let shared = SettingsNav()
    @Published var tab: SettingsTab = .general
}

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(tab: SettingsTab? = nil) {
        if let tab { SettingsNav.shared.tab = tab }
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Stretchy"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var awake = KeepAwake.shared
    @ObservedObject var nav = SettingsNav.shared
    @State private var launchRefresh = false

    var body: some View {
        TabView(selection: $nav.tab) {
            general.tabItem { Label(tr("tab.general"), systemImage: "gearshape") }.tag(SettingsTab.general)
            reminders.tabItem { Label(tr("tab.reminders"), systemImage: "bell") }.tag(SettingsTab.reminders)
            schedule.tabItem { Label(tr("tab.schedule"), systemImage: "calendar.badge.clock") }.tag(SettingsTab.schedule)
            lunch.tabItem { Label(tr("tab.lunch"), systemImage: "fork.knife") }.tag(SettingsTab.lunch)
            keepAwake.tabItem { Label(tr("tab.awake"), systemImage: "cup.and.saucer") }.tag(SettingsTab.awake)
            popup.tabItem { Label(tr("tab.popup"), systemImage: "rectangle.on.rectangle") }.tag(SettingsTab.popup)
            sound.tabItem { Label(tr("tab.sound"), systemImage: "speaker.wave.2") }.tag(SettingsTab.sound)
            about.tabItem { Label(tr("tab.about"), systemImage: "info.circle") }.tag(SettingsTab.about)
        }
        .frame(width: 680, height: 400)
    }

    // MARK: Tabs

    private var general: some View {
        Form {
            Picker(tr("set.language"), selection: $settings.language) {
                Text(tr("lang.system")).tag("system")
                Text("English").tag("en")
                Text("Tiếng Việt").tag("vi")
            }
            Picker(tr("set.theme"), selection: $settings.theme) {
                Text(tr("theme.system")).tag("system")
                Text(tr("theme.light")).tag("light")
                Text(tr("theme.dark")).tag("dark")
            }
            Toggle(tr("set.launch"), isOn: launchBinding)
            Toggle(tr("set.menuCountdown"), isOn: $settings.showMenuCountdown)
        }
        .formStyle(.grouped)
    }

    private var reminders: some View {
        Form {
            minutesStepper("set.sit", $settings.sitMinutes, 5...120, step: 5)
            minutesStepper("set.stand", $settings.standMinutes, 1...30)
            minutesStepper("set.snooze", $settings.snoozeMinutes, 1...15)

            Toggle(tr("set.eyes"), isOn: $settings.eyeEnabled)
            if settings.eyeEnabled {
                minutesStepper("set.eyesEvery", $settings.eyeMinutes, 10...60, step: 5)
            }

            Toggle(tr("set.water"), isOn: $settings.waterEnabled)
            if settings.waterEnabled {
                minutesStepper("set.waterEvery", $settings.waterMinutes, 15...180, step: 15)
            }

            Picker(tr("set.idle"), selection: $settings.idleMinutes) {
                Text(tr("off")).tag(0)
                ForEach([3, 5, 10, 15], id: \.self) { Text(tr("set.minutes", $0)).tag($0) }
            }
        }
        .formStyle(.grouped)
    }

    private var schedule: some View {
        Form {
            Toggle(tr("set.schedule"), isOn: $settings.scheduleEnabled)

            if settings.scheduleEnabled {
                DatePicker(tr("set.scheduleFrom"),
                           selection: timeBinding($settings.scheduleStart),
                           displayedComponents: .hourAndMinute)
                DatePicker(tr("set.scheduleTo"),
                           selection: timeBinding($settings.scheduleEnd),
                           displayedComponents: .hourAndMinute)

                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("set.scheduleDays"))
                    HStack(spacing: 5) {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            dayChip(day)
                        }
                    }
                }
            }

            Text(tr("set.scheduleHint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var lunch: some View {
        Form {
            Toggle(tr("set.lunch"), isOn: $settings.lunchEnabled)

            if settings.lunchEnabled {
                TextField(tr("set.lunchURL"), text: $settings.lunchURL, prompt: Text("https://…"))
                    .textFieldStyle(.roundedBorder)
                DatePicker(tr("set.lunchFrom"),
                           selection: timeBinding($settings.lunchStart),
                           displayedComponents: .hourAndMinute)
                DatePicker(tr("set.lunchTo"),
                           selection: timeBinding($settings.lunchEnd),
                           displayedComponents: .hourAndMinute)
                minutesStepper("set.lunchRepeat", $settings.lunchRepeatMinutes, 1...30)
                Picker(tr("set.lunchOpen"), selection: $settings.lunchOpenMode) {
                    Text(tr("lunch.open.browser")).tag("browser")
                    Text(tr("lunch.open.webview")).tag("webview")
                }
                HStack {
                    Button(tr("set.testPopup")) { ReminderEngine.shared.preview(.lunch) }
                    Button(tr("menu.lunch.open")) { LunchOrder.open() }
                        .disabled(!settings.lunchConfigured)
                }
            }

            Text(settings.lunchStart >= settings.lunchEnd ? tr("set.lunchRangeError") : tr("set.lunchHint"))
                .font(.footnote)
                .foregroundStyle(settings.lunchStart >= settings.lunchEnd ? Color.red : Color.secondary)
        }
        .formStyle(.grouped)
    }

    private var keepAwake: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: awake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .foregroundStyle(awake.isActive ? Color.orange : Color.secondary)
                    Text(awakeStatus)
                    Spacer()
                    if awake.isActive {
                        Button(tr("awake.stop")) { awake.stop() }
                    }
                }
            }

            Section(tr("awake.quick")) {
                HStack {
                    Button(tr("awake.30")) { awake.start(minutes: 30) }
                    Button(tr("awake.60")) { awake.start(minutes: 60) }
                    Button(tr("awake.120")) { awake.start(minutes: 120) }
                    Button(tr("awake.forever")) { awake.startIndefinitely() }
                }
            }

            Section {
                Stepper(value: $settings.keepAwakeCustomMinutes, in: 1...1440, step: 5) {
                    HStack {
                        Text(tr("awake.custom"))
                        Spacer()
                        Text(tr("set.minutes", settings.keepAwakeCustomMinutes))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                Button(tr("awake.start")) { awake.start(minutes: settings.keepAwakeCustomMinutes) }

                DatePicker(tr("awake.until"),
                           selection: timeBinding($settings.keepAwakeUntil),
                           displayedComponents: .hourAndMinute)
                Button(tr("awake.start")) { awake.start(untilMinuteOfDay: settings.keepAwakeUntil) }
            }

            Text(tr("awake.hint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var awakeStatus: String {
        guard awake.isActive else { return tr("awake.off") }
        guard let end = awake.endDate else { return tr("awake.on.forever") }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: currentLanguage() == "vi" ? "vi_VN" : "en_US")
        return tr("awake.on.until", f.string(from: end))
    }

    private var popup: some View {
        Form {
            Picker(tr("set.position"), selection: $settings.popupPosition) {
                Text(tr("pos.center")).tag(PopupPosition.center)
                Text(tr("pos.topRight")).tag(PopupPosition.topRight)
            }
            Picker(tr("set.effects"), selection: $settings.popupEffects) {
                Text(tr("fx.full")).tag(PopupEffects.full)
                Text(tr("fx.minimal")).tag(PopupEffects.minimal)
            }
            Picker(tr("set.autoclose"), selection: $settings.autoCloseSeconds) {
                Text(tr("autoclose.never")).tag(0)
                ForEach([15, 30, 60, 120], id: \.self) { Text(tr("set.seconds", $0)).tag($0) }
            }
            Button(tr("set.testPopup")) { ReminderEngine.shared.preview(.stand) }
        }
        .formStyle(.grouped)
    }

    private var sound: some View {
        Form {
            Toggle(tr("set.sound"), isOn: $settings.soundEnabled)
            Picker(tr("set.soundName"), selection: $settings.soundName) {
                ForEach(SoundPlayer.names, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: settings.soundName) { _, _ in SoundPlayer.shared.play() }
            HStack {
                Text(tr("set.volume"))
                Slider(value: $settings.soundVolume, in: 0...1)
            }
            Button(tr("btn.preview")) { SoundPlayer.shared.play() }
        }
        .formStyle(.grouped)
        .disabled(false)
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.stand")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: ReminderKind.stand.colors,
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("Stretchy").font(.title.bold())
            Text("v1.0").foregroundStyle(.secondary)
            Text(tr("about.text")).multilineTextAlignment(.center)
            Text(tr("about.disclaimer")).font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private func minutesStepper(_ key: String, _ value: Binding<Int>,
                                _ range: ClosedRange<Int>, step: Int = 1) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(tr(key))
                Spacer()
                Text(tr("set.minutes", value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dayChip(_ day: Int) -> some View {
        let on = settings.scheduleDays.contains(day)
        return Button {
            if on { settings.scheduleDays.removeAll { $0 == day } }
            else { settings.scheduleDays.append(day) }
        } label: {
            Text(weekdaySymbol(day))
                .font(.caption.weight(.medium))
                .frame(width: 44, height: 26)
                .background(Capsule().fill(on ? Color.accentColor : Color.primary.opacity(0.10)))
                .foregroundStyle(on ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func weekdaySymbol(_ day: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: currentLanguage() == "vi" ? "vi_VN" : "en_US")
        return f.shortWeekdaySymbols[day - 1]
    }

    /// Chuyển "số phút từ 0:00" <-> Date để dùng với DatePicker
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { _ = launchRefresh; return SMAppService.mainApp.status == .enabled },
            set: { on in
                do {
                    if on { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    NSLog("Stretchy: launch-at-login failed: \(error)")
                }
                launchRefresh.toggle()
            }
        )
    }
}
