import SwiftUI

struct PopupView: View {
    let kind: ReminderKind
    let message: String
    let snoozeMinutes: Int
    let autoCloseSeconds: Int
    let full: Bool                       // hiệu ứng đầy đủ hay tối giản
    let onAction: (PopupAction) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var finished = false
    @State private var celebrating = false

    private var animated: Bool { full && !reduceMotion }
    private let radius: CGFloat = 28

    var body: some View {
        ZStack {
            card
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)

            if celebrating && animated {
                ConfettiView()
            }
        }
        .padding(60)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                                       : .spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .task {
            guard autoCloseSeconds > 0 else { return }
            try? await Task.sleep(nanoseconds: UInt64(autoCloseSeconds) * 1_000_000_000)
            if !Task.isCancelled { finish(.timeout) }
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 16) {
            icon
            Text(celebrating ? celebrateText : tr("\(kind.rawValue).title"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(celebrating ? " " : message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 60, alignment: .top)
            buttons
                .opacity(celebrating ? 0 : 1)
        }
        .padding(28)
        .frame(width: 400)
        .background(cardBackground)
        .overlay(alignment: .topTrailing) {
            if autoCloseSeconds > 0 && !celebrating {
                AutoCloseRing(seconds: autoCloseSeconds, color: kind.accent)
                    .padding(18)
                    .help(tr("autoclose.help"))
            }
        }
    }

    private var celebrateText: String {
        switch kind {
        case .stand: return tr("celebrate", ReminderEngine.shared.todayCount)
        case .water: return tr("celebrate.water", ReminderEngine.shared.todayWater)
        case .lunch: return tr("celebrate.lunch")
        default: return tr("celebrate.simple")
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [kind.accent.opacity(0.14), .clear],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(glowBorder)
            .shadow(color: kind.accent.opacity(0.35), radius: 30, y: 10)
    }

    private var glowBorder: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { tl in
            let angle = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    AngularGradient(colors: kind.colors + [kind.colors[0]],
                                    center: .center, angle: .degrees(angle)),
                    lineWidth: full ? 3 : 1.5
                )
        }
    }

    // MARK: Icon

    private var icon: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                if animated {
                    ForEach(0..<2) { i in
                        let p = (t + Double(i)).truncatingRemainder(dividingBy: 2.0) / 2.0
                        Circle()
                            .stroke(kind.accent.opacity(0.5 * (1 - p)), lineWidth: 2)
                            .frame(width: 84, height: 84)
                            .scaleEffect(1 + 0.8 * p)
                    }
                }
                Circle()
                    .fill(LinearGradient(colors: kind.colors,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: kind.accent.opacity(0.5), radius: 12, y: 4)
                Image(systemName: kind.symbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(y: animated ? CGFloat(sin(t * 3)) * 3 : 0)
            }
            .frame(width: 120, height: 120)
        }
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { finish(kind == .lunch ? .open : .done) } label: {
                    Text(tr(kind == .lunch ? "btn.open.lunch" : "btn.done.\(kind.rawValue)"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(colors: kind.colors))

                // Cơm: nút phụ là "Đã đặt"; các loại khác là "Nhắc lại sau N phút"
                Button { finish(kind == .lunch ? .done : .snooze) } label: {
                    Text(kind == .lunch ? tr("btn.done.lunch") : tr("btn.snooze", snoozeMinutes))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Button(tr("btn.skip")) { finish(.skip) }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Logic

    private func finish(_ action: PopupAction) {
        guard !finished else { return }
        finished = true
        onAction(action)

        if action == .done {
            if full { SoundPlayer.shared.playDone() }
            withAnimation(.easeOut(duration: 0.2)) { celebrating = true }
            let delay = animated ? 1.3 : 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onClose() }
        } else {
            onClose()
        }
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    let colors: [Color]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .background(Capsule().fill(LinearGradient(colors: colors,
                                                      startPoint: .leading, endPoint: .trailing)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.09)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Auto-close ring

struct AutoCloseRing: View {
    let seconds: Int
    let color: Color
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { tl in
            let p = min(1, tl.date.timeIntervalSince(start) / Double(seconds))
            Circle()
                .trim(from: 0, to: 1 - p)
                .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    private struct Piece {
        let vx: Double, vy: Double, w: Double, h: Double
        let spin: Double, phase: Double, hue: Double
    }

    private let pieces: [Piece] = (0..<70).map { _ in
        Piece(vx: Double.random(in: -260...260),
              vy: Double.random(in: -520 ... -180),
              w: Double.random(in: 6...10),
              h: Double.random(in: 10...16),
              spin: Double.random(in: -8...8),
              phase: Double.random(in: 0...6.28),
              hue: Double.random(in: 0...1))
    }
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                let life = 1.4
                guard t < life else { return }
                for p in pieces {
                    var c = ctx
                    c.opacity = max(0, 1 - t / life)
                    c.translateBy(x: size.width / 2 + p.vx * t,
                                  y: size.height / 2 + p.vy * t + 700 * t * t)
                    c.rotate(by: .radians(p.phase + p.spin * t))
                    c.fill(Path(CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)),
                           with: .color(Color(hue: p.hue, saturation: 0.75, brightness: 1)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
