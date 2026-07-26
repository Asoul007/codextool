import CodexQuotaCore
import SwiftUI

struct GlassContainer<Content: View>: View {
    let theme: ThemeSkin
    let transparency: TransparencyMode
    let radius: CGFloat
    let content: Content

    init(
        theme: ThemeSkin,
        transparency: TransparencyMode,
        radius: CGFloat = 34,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.transparency = transparency
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.glass.opacity(transparency.backgroundOpacity))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                theme.primary.opacity(transparency.borderOpacity),
                                theme.secondary.opacity(transparency.borderOpacity * 0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: transparency == .transparent ? 0 : 1
                    )
            )
            .compositingGroup()
    }
}

struct QuotaRing: View {
    let title: String
    let valueText: String
    let percent: Int
    let color: Color
    var size: CGFloat = 104

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(percent, 100))) / 100)
                .stroke(
                    AngularGradient(colors: [color.opacity(0.35), color, color.opacity(0.65)], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.65), radius: 10)

            VStack(spacing: 3) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: size < 82 ? 10 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }
                Text(valueText)
                    .font(.system(size: size < 82 ? 20 : 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: size * 0.72)
        }
        .frame(width: size, height: size)
    }
}

struct OrbArc: View {
    let percent: Int
    let color: Color
    let lineWidth: CGFloat
    let inset: CGFloat

    var body: some View {
        Circle()
            .inset(by: inset)
            .trim(from: 0, to: CGFloat(max(0, min(percent, 100))) / 100)
            .stroke(
                AngularGradient(colors: [color.opacity(0.45), color, color.opacity(0.75)], center: .center),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-92))
            .shadow(color: color.opacity(0.48), radius: 8)
    }
}

struct MetricCapsule: View {
    let title: String
    let percentText: String
    let detail: String
    let badge: String
    let color: Color
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 14) {
            QuotaRing(title: "", valueText: percentText, percent: Int(percentText.filter(\.isNumber)) ?? 0, color: color, size: 82)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(badge)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(badgeColor)
                    .background(Capsule().fill(badgeColor.opacity(0.16)))
                    .overlay(Capsule().stroke(badgeColor.opacity(0.35), lineWidth: 1))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 210)
        .background(Capsule().fill(.white.opacity(0.045)))
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 22)
            Text(label)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
        .font(.system(size: 14))
        .padding(.vertical, 8)
    }
}

struct LiquidEnergyBar: View {
    let percent: Int
    let color: Color

    var body: some View {
        let clampedPercent = max(0, min(percent, 100))
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.22))
                        .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))

                    if clampedPercent > 0 {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.18), color.opacity(0.62), .white.opacity(0.24)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            LiquidWaveFill(amplitude: 7, wavelength: 88, phase: phase * 2.1, baseline: 0.46)
                                .fill(color.opacity(0.58))
                                .blendMode(.screen)
                            LiquidWaveFill(amplitude: 5, wavelength: 64, phase: phase * -2.8, baseline: 0.54)
                                .fill(.white.opacity(0.2))
                                .blendMode(.screen)
                            LiquidWaveLine(amplitude: 7, wavelength: 88, phase: phase * 2.1, baseline: 0.46)
                                .stroke(.white.opacity(0.62), lineWidth: 2)
                                .padding(.horizontal, 8)
                        }
                        .frame(width: max(42, geometry.size.width * CGFloat(clampedPercent) / 100))
                        .clipShape(Capsule())
                        .shadow(color: color.opacity(0.75), radius: 11)
                    }
                }
            }
        }
        .frame(height: 34)
    }
}

struct LiquidWaveFill: Shape {
    let amplitude: CGFloat
    let wavelength: CGFloat
    let phase: Double
    let baseline: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = rect.minY + rect.height * baseline
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: baseY))

        let step: CGFloat = 4
        var x = rect.minX
        while x <= rect.maxX {
            let progress = (x - rect.minX) / max(wavelength, 1)
            let y = baseY + sin(progress * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct LiquidWaveLine: Shape {
    let amplitude: CGFloat
    let wavelength: CGFloat
    let phase: Double
    let baseline: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = rect.minY + rect.height * baseline
        path.move(to: CGPoint(x: rect.minX, y: baseY))

        let step: CGFloat = 4
        var x = rect.minX
        while x <= rect.maxX {
            let progress = (x - rect.minX) / max(wavelength, 1)
            let y = baseY + sin(progress * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        return path
    }
}
