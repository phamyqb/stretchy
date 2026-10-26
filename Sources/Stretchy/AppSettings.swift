import SwiftUI

private let ud = UserDefaults.standard
private func udInt(_ k: String, _ def: Int) -> Int { ud.object(forKey: k) as? Int ?? def }
private func udBool(_ k: String, _ def: Bool) -> Bool { ud.object(forKey: k) as? Bool ?? def }
private func udDouble(_ k: String, _ def: Double) -> Double { ud.object(forKey: k) as? Double ?? def }
private func udString(_ k: String, _ def: String) -> String { ud.string(forKey: k) ?? def }

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // General
    @Published var language: String { didSet { ud.set(language, forKey: "language") } }          // system | en | vi
    @Published var theme: String { didSet { ud.set(theme, forKey: "theme") } }                    // system | light | dark
    @Published var showMenuCountdown: Bool { didSet { ud.set(showMenuCountdown, forKey: "showMenuCountdown") } }

    // Reminders
    @Published var sitMinutes: Int { didSet { ud.set(sitMinutes, forKey: "sitMinutes") } }
    @Published var standMinutes: Int { didSet { ud.set(standMinutes, forKey: "standMinutes") } }
    @Published var snoozeMinutes: Int { didSet { ud.set(snoozeMinutes, forKey: "snoozeMinutes") } }
    @Published var eyeEnabled: Bool { didSet { ud.set(eyeEnabled, forKey: "eyeEnabled") } }
    @Published var eyeMinutes: Int { didSet { ud.set(eyeMinutes, forKey: "eyeMinutes") } }
    @Published var idleMinutes: Int { didSet { ud.set(idleMinutes, forKey: "idleMinutes") } }     // 0 = off
    @Published var waterEnabled: Bool { didSet { ud.set(waterEnabled, forKey: "waterEnabled") } }
    @Published var waterMinutes: Int { didSet { ud.set(waterMinutes, forKey: "waterMinutes") } }

    // Schedule (khung giờ làm việc) – tắt mặc định = nhắc cả ngày như trước
    @Published var scheduleEnabled: Bool { didSet { ud.set(scheduleEnabled, forKey: "scheduleEnabled") } }
    @Published var scheduleStart: Int { didSet { ud.set(scheduleStart, forKey: "scheduleStart") } }   // phút từ 0:00
    @Published var scheduleEnd: Int { didSet { ud.set(scheduleEnd, forKey: "scheduleEnd") } }
    @Published var scheduleDays: [Int] {                                                              // 1 = CN … 7 = T7
        didSet { ud.set(scheduleDays.map(String.init).joined(separator: ","), forKey: "scheduleDays") }
    }

    // Keep awake (giá trị mặc định cho mục "tuỳ chỉnh" / "hẹn giờ tắt")
    @Published var keepAwakeCustomMinutes: Int { didSet { ud.set(keepAwakeCustomMinutes, forKey: "keepAwakeCustomMinutes") } }
    @Published var keepAwakeUntil: Int { didSet { ud.set(keepAwakeUntil, forKey: "keepAwakeUntil") } }   // phút từ 0:00

    // Popup
    @Published var popupPosition: PopupPosition { didSet { ud.set(popupPosition.rawValue, forKey: "popupPosition") } }
    @Published var popupEffects: PopupEffects { didSet { ud.set(popupEffects.rawValue, forKey: "popupEffects") } }
    @Published var autoCloseSeconds: Int { didSet { ud.set(autoCloseSeconds, forKey: "autoCloseSeconds") } }  // 0 = never

    // Sound
    @Published var soundEnabled: Bool { didSet { ud.set(soundEnabled, forKey: "soundEnabled") } }
    @Published var soundName: String { didSet { ud.set(soundName, forKey: "soundName") } }
    @Published var soundVolume: Double { didSet { ud.set(soundVolume, forKey: "soundVolume") } }

    private init() {
        language = udString("language", "system")
        theme = udString("theme", "system")
        showMenuCountdown = udBool("showMenuCountdown", true)

        sitMinutes = udInt("sitMinutes", 45)
        standMinutes = udInt("standMinutes", 5)
        snoozeMinutes = udInt("snoozeMinutes", 5)
        eyeEnabled = udBool("eyeEnabled", true)
        eyeMinutes = udInt("eyeMinutes", 20)
        idleMinutes = udInt("idleMinutes", 5)
        waterEnabled = udBool("waterEnabled", true)
        waterMinutes = udInt("waterMinutes", 60)

        scheduleEnabled = udBool("scheduleEnabled", false)
        scheduleStart = udInt("scheduleStart", 9 * 60)
        scheduleEnd = udInt("scheduleEnd", 18 * 60)
        scheduleDays = udString("scheduleDays", "2,3,4,5,6").split(separator: ",").compactMap { Int($0) }

        keepAwakeCustomMinutes = udInt("keepAwakeCustomMinutes", 90)
        keepAwakeUntil = udInt("keepAwakeUntil", 18 * 60)

        popupPosition = PopupPosition(rawValue: udString("popupPosition", "center")) ?? .center
        popupEffects = PopupEffects(rawValue: udString("popupEffects", "full")) ?? .full
        autoCloseSeconds = udInt("autoCloseSeconds", 60)

        soundEnabled = udBool("soundEnabled", true)
        soundName = udString("soundName", "Glass")
        soundVolume = udDouble("soundVolume", 0.7)
    }
}

extension AppSettings {
    /// Có đang trong khung giờ làm việc không? (luôn true nếu tính năng này tắt)
    func isWithinSchedule(_ date: Date = Date()) -> Bool {
        guard scheduleEnabled else { return true }
        let c = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        var wd = c.weekday ?? 1
        let s = scheduleStart, e = scheduleEnd

        if s == e { return scheduleDays.contains(wd) }                    // cả ngày
        if s < e { return scheduleDays.contains(wd) && m >= s && m < e }  // ca thường
        // Ca qua đêm (vd 22:00 → 06:00): phần sau nửa đêm thuộc về ngày hôm trước
        if m >= s { return scheduleDays.contains(wd) }
        if m < e {
            wd = (wd == 1) ? 7 : wd - 1
            return scheduleDays.contains(wd)
        }
        return false
    }
}
