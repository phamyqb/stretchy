import SwiftUI

enum ReminderKind: String {
    case stand, sit, eyes, water

    var symbol: String {
        switch self {
        case .stand: return "figure.stand"
        case .sit: return "desktopcomputer"
        case .eyes: return "eye"
        case .water: return "drop.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .stand: return [.mint, .teal, .cyan]
        case .sit: return [.blue, .indigo, .cyan]
        case .eyes: return [.purple, .pink, .indigo]
        case .water: return [Color(red: 0.2, green: 0.75, blue: 1.0), .blue, .cyan]
        }
    }

    var accent: Color { colors[0] }
}

enum PopupAction { case done, snooze, skip, timeout }
enum PopupPosition: String, CaseIterable { case center, topRight }
enum PopupEffects: String, CaseIterable { case full, minimal }
