import AppKit
import Combine

/// Bộ não của app: chu kỳ ngồi → đứng, nhắc nghỉ mắt, idle, sleep/wake, tạm dừng.
final class ReminderEngine: ObservableObject {
    static let shared = ReminderEngine()

    enum Phase { case sitting, standing }

    @Published private(set) var phase: Phase = .sitting
    @Published private(set) var menuTitle: String = ""
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var todayCount: Int = 0
    @Published private(set) var todayWater: Int = 0
    @Published private(set) var isOffHours: Bool = false

    private let settings = AppSettings.shared
    private var phaseEnd = Date()
    private var eyeEnd = Date()
    private var waterEnd = Date()
    private var prompting: ReminderKind?
    private var timer: Timer?
    private var sleepDate: Date?
    private var started = false
    private var currentDay = Calendar.current.startOfDay(for: Date())

    var isPaused: Bool { pausedUntil != nil }

    private init() { loadStats() }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        resetCycle()

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleepDate = Date()
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWake()
        }
        updateMenuTitle()
    }

    private func handleWake() {
        // Máy ngủ > 5 phút = coi như đã nghỉ → bắt đầu chu kỳ mới
        if let s = sleepDate, Date().timeIntervalSince(s) > 5 * 60 {
            dismissPopup()
            resetCycle(includingWater: false)
        }
        sleepDate = nil
    }

    // MARK: - Tick

    private func tick() {
        let now = Date()

        let today = Calendar.current.startOfDay(for: now)
        if today != currentDay {
            currentDay = today
            todayCount = 0
            todayWater = 0
            saveStats()
        }

        if let until = pausedUntil {
            if now >= until {
                pausedUntil = nil
                resetCycle()
            } else {
                updateMenuTitle()
                return
            }
        }

        if prompting != nil { return }

        // Ngoài khung giờ làm việc → tạm dừng mọi nhắc nhở; vào lại giờ làm thì bắt đầu chu kỳ mới
        if settings.isWithinSchedule(now) {
            if isOffHours {
                isOffHours = false
                resetCycle()
            }
        } else {
            if !isOffHours { isOffHours = true }
            updateMenuTitle()
            return
        }

        // Người dùng vắng mặt → coi như đã nghỉ, reset chu kỳ (không reset đồng hồ uống nước)
        let limit = Double(settings.idleMinutes) * 60
        if limit > 0 && idleSeconds() > limit {
            resetCycle(includingWater: false)
            return
        }

        if now >= phaseEnd {
            fire(phase == .sitting ? .stand : .sit)
            return
        }

        if settings.eyeEnabled && now >= eyeEnd {
            eyeEnd = now.addingTimeInterval(TimeInterval(settings.eyeMinutes * 60))
            fire(.eyes)
            return
        }

        if settings.waterEnabled && now >= waterEnd {
            waterEnd = now.addingTimeInterval(TimeInterval(settings.waterMinutes * 60))
            fire(.water)
            return
        }

        updateMenuTitle()
    }

    private func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                eventType: CGEventType(rawValue: ~0)!)
    }

    // MARK: - Prompting

    private func fire(_ kind: ReminderKind) {
        prompting = kind
        PopupController.shared.show(kind: kind) { [weak self] action in
            self?.handle(action, for: kind)
        }
        SoundPlayer.shared.playIfEnabled()
        updateMenuTitle()
    }

    func handle(_ action: PopupAction, for kind: ReminderKind) {
        let now = Date()
        prompting = nil
        let sit = TimeInterval(settings.sitMinutes * 60)
        let stand = TimeInterval(settings.standMinutes * 60)
        let snooze = TimeInterval(settings.snoozeMinutes * 60)

        switch kind {
        case .water:
            switch action {
            case .done:
                registerWater()
                waterEnd = now.addingTimeInterval(TimeInterval(settings.waterMinutes * 60))
            case .snooze, .timeout:
                waterEnd = now.addingTimeInterval(snooze)
            case .skip:
                waterEnd = now.addingTimeInterval(TimeInterval(settings.waterMinutes * 60))
            }
        case .eyes:
            if action == .snooze || action == .timeout {
                eyeEnd = now.addingTimeInterval(snooze)
            }
        case .stand:
            switch action {
            case .done:
                phase = .standing
                phaseEnd = now.addingTimeInterval(stand)
                registerChange()
            case .snooze, .timeout:
                phaseEnd = now.addingTimeInterval(snooze)
            case .skip:
                phaseEnd = now.addingTimeInterval(sit)
            }
        case .sit:
            switch action {
            case .done, .skip:
                phase = .sitting
                phaseEnd = now.addingTimeInterval(sit)
            case .snooze, .timeout:
                phaseEnd = now.addingTimeInterval(snooze)
            }
        }
        updateMenuTitle()
    }

    private func dismissPopup() {
        prompting = nil
        PopupController.shared.close()
    }

    // MARK: - Actions từ menu

    func changePostureNow() {
        dismissPopup()
        pausedUntil = nil
        handle(.done, for: phase == .sitting ? .stand : .sit)
    }

    /// Người dùng tự ghi nhận vừa uống nước (từ menu bar)
    func logWater() {
        registerWater()
        waterEnd = Date().addingTimeInterval(TimeInterval(settings.waterMinutes * 60))
    }

    func preview(_ kind: ReminderKind = .stand) {
        guard prompting == nil else { return }
        PopupController.shared.show(kind: kind) { _ in }   // không ảnh hưởng chu kỳ
        SoundPlayer.shared.playIfEnabled()
    }

    func pause(minutes: Int) {
        pause(until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func pauseUntilTomorrow() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        pause(until: cal.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(8 * 3600))
    }

    private func pause(until date: Date) {
        dismissPopup()
        pausedUntil = date
        updateMenuTitle()
    }

    func resume() {
        pausedUntil = nil
        resetCycle()
    }

    // MARK: - Helpers

    private func resetCycle(includingWater: Bool = true) {
        let now = Date()
        if phase != .sitting { phase = .sitting }
        phaseEnd = now.addingTimeInterval(TimeInterval(settings.sitMinutes * 60))
        eyeEnd = now.addingTimeInterval(TimeInterval(settings.eyeMinutes * 60))
        if includingWater {
            waterEnd = now.addingTimeInterval(TimeInterval(settings.waterMinutes * 60))
        }
        updateMenuTitle()
    }

    private func updateMenuTitle() {
        var t = ""
        if pausedUntil == nil && !isOffHours && settings.showMenuCountdown {
            let mins = max(0, Int(ceil(phaseEnd.timeIntervalSinceNow / 60)))
            t = "\(mins)m"
        }
        if t != menuTitle { menuTitle = t }
    }

    func statusText() -> String {
        if let until = pausedUntil {
            let f = DateFormatter()
            f.dateStyle = .none
            f.timeStyle = .short
            f.locale = Locale(identifier: currentLanguage() == "vi" ? "vi_VN" : "en_US")
            return tr("menu.status.pausedUntil", f.string(from: until))
        }
        if isOffHours { return tr("menu.status.offHours") }
        if prompting != nil { return tr("menu.status.prompting") }
        let mins = max(1, Int(ceil(phaseEnd.timeIntervalSinceNow / 60)))
        return tr(phase == .sitting ? "menu.status.sitting" : "menu.status.standing", mins)
    }

    // MARK: - Stats (đơn giản, lưu UserDefaults)

    private func registerChange() {
        todayCount += 1
        saveStats()
    }

    private func registerWater() {
        todayWater += 1
        saveStats()
    }

    private func saveStats() {
        let d = UserDefaults.standard
        d.set(currentDay.timeIntervalSince1970, forKey: "statsDay")
        d.set(todayCount, forKey: "statsCount")
        d.set(todayWater, forKey: "statsWater")
    }

    private func loadStats() {
        let d = UserDefaults.standard
        if d.double(forKey: "statsDay") == currentDay.timeIntervalSince1970 {
            todayCount = d.integer(forKey: "statsCount")
            todayWater = d.integer(forKey: "statsWater")
        }
    }
}
