import Foundation
import IOKit.pwr_mgt

/// Giữ máy không ngủ (kiểu `caffeinate`): chặn idle sleep của cả hệ thống lẫn màn hình.
/// Tự tắt khi hết thời lượng / tới giờ hẹn.
final class KeepAwake: ObservableObject {
    static let shared = KeepAwake()

    /// Đang bật?
    @Published private(set) var isActive = false
    /// Thời điểm tự tắt; nil = giữ cho đến khi tắt tay
    @Published private(set) var endDate: Date?

    private var displayAssertion: IOPMAssertionID = 0
    private var systemAssertion: IOPMAssertionID = 0
    private var timer: Timer?

    private init() {}

    // MARK: - API

    func start(minutes: Int) {
        activate(until: Date().addingTimeInterval(TimeInterval(max(1, minutes) * 60)))
    }

    /// Giữ thức đến giờ `minutesFromMidnight` kế tiếp (hôm nay, hoặc ngày mai nếu đã qua)
    func start(untilMinuteOfDay m: Int) {
        let cal = Calendar.current
        let now = Date()
        var target = cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: now) ?? now
        if target <= now { target = cal.date(byAdding: .day, value: 1, to: target) ?? target }
        activate(until: target)
    }

    func startIndefinitely() { activate(until: nil) }

    func stop() {
        timer?.invalidate()
        timer = nil
        release(&displayAssertion)
        release(&systemAssertion)
        endDate = nil
        isActive = false
    }

    func remainingText() -> String? {
        guard let end = endDate else { return nil }
        let mins = max(1, Int(ceil(end.timeIntervalSinceNow / 60)))
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
    }

    // MARK: - Internals

    private func activate(until date: Date?) {
        stop()
        let reason = "Stretchy: keep Mac awake" as CFString
        let ok1 = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                                              IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                              reason, &displayAssertion)
        let ok2 = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                              IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                              reason, &systemAssertion)
        guard ok1 == kIOReturnSuccess, ok2 == kIOReturnSuccess else {
            NSLog("Stretchy: cannot create power assertion (\(ok1), \(ok2))")
            stop()
            return
        }
        endDate = date
        isActive = true

        if let date {
            let t = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in self?.stop() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    private func release(_ id: inout IOPMAssertionID) {
        if id != 0 { IOPMAssertionRelease(id); id = 0 }
    }
}
