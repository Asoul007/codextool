import CodexQuotaCore
import SwiftUI

struct FloatingOrbView: View {
    @ObservedObject var state: AppState

    private var visibleOrbMetrics: [(value: String, label: String, color: Color, percent: Int)] {
        let theme = state.theme
        var metrics: [(String, String, Color, Int)] = []
        if state.settings.menuBarShowsFiveHour {
            metrics.append((state.snapshot.fiveHourValueText, "5小时", theme.primary, state.snapshot.fiveHourPercent))
        }
        if state.settings.menuBarShowsWeekly {
            metrics.append((state.snapshot.weeklyValueText, "一周", theme.secondary, state.snapshot.weeklyPercent))
        }
        if state.settings.menuBarShowsReset {
            metrics.append((state.snapshot.resetValueText, "重置", theme.success, min(100, state.snapshot.resets * 34)))
        }
        return metrics
    }

    private var resetOrbMetric: (value: String, label: String, color: Color, percent: Int)? {
        guard state.settings.menuBarShowsReset else { return nil }
        let theme = state.theme
        return (state.snapshot.resetValueText, "重置", theme.success, min(100, state.snapshot.resets * 34))
    }

    var body: some View {
        let theme = state.theme
        if theme.id == "liquid_energy" {
            liquidOrb(theme: theme)
        } else {
            compactOrb(theme: theme)
        }
    }

    private func liquidOrb(theme: ThemeSkin) -> some View {
        ZStack {
            Circle()
                .fill(theme.glass.opacity(max(0.28, state.settings.transparencyMode.backgroundOpacity)))
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.secondary.opacity(0.18), .clear],
                        center: .bottomTrailing,
                        startRadius: 4,
                        endRadius: 112
                    )
                )
            Circle().stroke(theme.secondary.opacity(0.16), lineWidth: 10).padding(14)
            Circle().stroke(theme.primary.opacity(0.14), lineWidth: 7).padding(32)
            if let first = visibleOrbMetrics.first {
                OrbArc(percent: first.percent, color: first.color, lineWidth: 11, inset: 13)
            }
            if visibleOrbMetrics.count > 1 {
                OrbArc(percent: visibleOrbMetrics[1].percent, color: visibleOrbMetrics[1].color, lineWidth: 8, inset: 31)
            }
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
                .padding(5)

            VStack(spacing: 5) {
                Text("Codex")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Text("用量")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(state.snapshot.planBadgeText)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(theme.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.secondary.opacity(0.18)))
                        .overlay(Capsule().stroke(theme.secondary.opacity(0.5), lineWidth: 1))
                }
                if visibleOrbMetrics.isEmpty {
                    Text("未选指标")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: visibleOrbMetrics.count == 1 ? 0 : 8) {
                        ForEach(Array(visibleOrbMetrics.prefix(2).enumerated()), id: \.offset) { index, metric in
                            if index > 0 {
                                Text("·")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.28))
                            }
                            orbValue(metric.value, label: metric.label, color: metric.color)
                        }
                    }
                }
                if let resetOrbMetric,
                   !visibleOrbMetrics.prefix(2).contains(where: { $0.label == "重置" }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(resetOrbMetric.color)
                            .frame(width: 5, height: 5)
                        Text("重置 \(resetOrbMetric.value)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(resetOrbMetric.color)
                    }
                }
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 170, height: 170)
        .fixedSize()
    }

    private func compactOrb(theme: ThemeSkin) -> some View {
        ZStack {
            Circle()
                .fill(theme.glass.opacity(max(0.18, state.settings.transparencyMode.backgroundOpacity)))
                .overlay(Circle().stroke(theme.primary.opacity(0.28), lineWidth: 1))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.primary.opacity(0.2), .clear],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 92
                    )
                )
            if let first = visibleOrbMetrics.first {
                OrbArc(percent: first.percent, color: first.color, lineWidth: 9, inset: 9)
            }
            if visibleOrbMetrics.count > 1 {
                OrbArc(percent: visibleOrbMetrics[1].percent, color: visibleOrbMetrics[1].color, lineWidth: 7, inset: 24)
            }

            VStack(spacing: 4) {
                Text("Codex")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Text(visibleOrbMetrics.first?.value ?? "--")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(visibleOrbMetrics.first?.color ?? theme.secondary)
                    .minimumScaleFactor(0.72)
                if visibleOrbMetrics.isEmpty {
                    Text("未选指标")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(visibleOrbMetrics.dropFirst().prefix(2).enumerated()), id: \.offset) { _, metric in
                            Circle().fill(metric.color).frame(width: 4, height: 4)
                            Text("\(metric.label) \(metric.value)")
                        }
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .frame(width: 124, height: 124)
        .fixedSize()
    }

    private func orbValue(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(width: 48)
    }
}

struct FloatingCapsuleView: View {
    @ObservedObject var state: AppState

    var body: some View {
        let theme = state.theme
        GlassContainer(theme: theme, transparency: state.settings.transparencyMode, radius: 32) {
            HStack(spacing: 12) {
                capsuleMetric("5h", state.snapshot.fiveHourValueText, percent: state.snapshot.fiveHourPercent, color: theme.primary)
                divider
                capsuleMetric("W", state.snapshot.weeklyValueText, percent: state.snapshot.weeklyPercent, color: theme.secondary)
                divider
                capsuleMetric("R", state.snapshot.resetValueText, percent: min(100, state.snapshot.resets * 34), color: theme.success)
                HStack(spacing: 6) {
                    FloatingChromeButton(systemName: "xmark") {
                        state.closeMode(.floatingCapsule)
                    }
                    FloatingChromeButton(systemName: "power") {
                        state.quit()
                    }
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
        }
        .frame(width: 462, height: 64)
        .fixedSize()
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.16))
            .frame(width: 1, height: 34)
    }

    private func capsuleMetric(_ label: String, _ value: String, percent: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.18), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(percent, 100))) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(value.replacingOccurrences(of: "次", with: ""))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(width: 104, alignment: .leading)
    }
}

struct DeveloperHUDView: View {
    @ObservedObject var state: AppState
    @State private var isHUDHovered = false

    var body: some View {
        let theme = state.theme
        if theme.id == "liquid_energy" {
            liquidEnergyHUD(theme: theme)
        } else {
            standardHUD(theme: theme)
        }
    }

    private func standardHUD(theme: ThemeSkin) -> some View {
        GlassContainer(theme: theme, transparency: state.settings.transparencyMode, radius: 36) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(theme.secondary))
                    Text("Codex 用量")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    hudCloseButton
                }
                .foregroundStyle(.white.opacity(0.76))

                HStack(spacing: 10) {
                    if state.settings.menuBarShowsFiveHour {
                        MetricCapsule(
                            title: "5小时剩余",
                            percentText: state.snapshot.fiveHourValueText,
                            detail: state.snapshot.fiveHourDetailText,
                            badge: state.snapshot.fiveHourBadgeText,
                            color: theme.primary,
                            badgeColor: state.snapshot.fiveHourRemainingPercent == nil ? .white.opacity(0.65) : (state.snapshot.fiveHourPercent < 70 ? theme.warning : theme.success)
                        )
                    }
                    if state.settings.menuBarShowsWeekly {
                        MetricCapsule(
                            title: "一周剩余",
                            percentText: state.snapshot.weeklyValueText,
                            detail: state.snapshot.weeklyDetailText,
                            badge: state.snapshot.weeklyBadgeText,
                            color: theme.secondary,
                            badgeColor: state.snapshot.weeklyRemainingPercent == nil ? .white.opacity(0.65) : (state.snapshot.weeklyPercent < 70 ? theme.warning : theme.success)
                        )
                    }
                    if state.settings.menuBarShowsReset {
                        MetricCapsule(
                            title: "重置机会",
                            percentText: state.snapshot.resetValueText,
                            detail: state.snapshot.resetDetailText,
                            badge: state.snapshot.resetBadgeText,
                            color: Color(hex: theme.secondaryColor),
                            badgeColor: state.snapshot.resets > 0 ? theme.success : theme.warning
                        )
                    }
                }

                VStack(spacing: 0) {
                    if state.settings.menuBarShowsFiveHour {
                        DetailRow(icon: "clock", label: "下次 5 小时重置", value: state.snapshot.nextFiveHourResetAt.map { Self.timeFormatter.string(from: $0) } ?? "--", tint: theme.primary)
                        Divider().background(.white.opacity(0.08))
                    }
                    if state.settings.menuBarShowsWeekly {
                        DetailRow(icon: "calendar", label: "一周下次重置时间", value: state.snapshot.weeklyResetAt.map { Self.dateFormatter.string(from: $0) } ?? "--", tint: theme.secondary)
                        Divider().background(.white.opacity(0.08))
                    }
                    DetailRow(icon: "externaldrive", label: "数据来源", value: state.snapshot.sourceLabel, tint: theme.primary)
                    Divider().background(.white.opacity(0.08))
                    DetailRow(icon: "timer", label: "最后更新", value: Self.dateTimeFormatter.string(from: state.snapshot.capturedAt), tint: .white.opacity(0.7))
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.035)))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))

                HStack(spacing: 12) {
                    if state.settings.menuBarShowsFiveHour {
                        warningChip(state.snapshot.fiveHourRemainingPercent == nil ? "5小时用量待导入" : "5小时剩余偏低（\(state.snapshot.fiveHourPercent)%）", color: theme.warning)
                    }
                    if state.settings.menuBarShowsWeekly {
                        warningChip(state.snapshot.weeklyRemainingPercent == nil ? "一周用量待导入" : "一周剩余偏低（\(state.snapshot.weeklyPercent)%）", color: theme.secondary)
                    }
                }

            }
            .padding(22)
        }
        .frame(width: 710)
        .fixedSize()
        .onHover { isHUDHovered = $0 }
    }

    private func liquidEnergyHUD(theme: ThemeSkin) -> some View {
        GlassContainer(theme: theme, transparency: state.settings.transparencyMode, radius: 44) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 18, height: 18)
                        .shadow(color: theme.primary.opacity(0.9), radius: 11)
                    Text("Codex 用量")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(state.snapshot.planBadgeText)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(theme.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.secondary.opacity(0.14)))
                        .overlay(Capsule().stroke(theme.secondary.opacity(0.45), lineWidth: 1))
                    Spacer()
                    hudCloseButton
                }

                if state.settings.menuBarShowsFiveHour {
                    liquidMeter(
                        title: "5 小时用量",
                        percent: state.snapshot.fiveHourPercent,
                        value: state.snapshot.fiveHourValueText,
                        reset: state.snapshot.nextFiveHourResetAt.map { Self.dateTimeFormatter.string(from: $0) } ?? "--",
                        used: state.snapshot.fiveHourRemainingPercent.map { "已用 \(100 - $0)%" } ?? "待导入",
                        color: theme.primary
                    )
                }
                if state.settings.menuBarShowsWeekly {
                    liquidMeter(
                        title: "一周用量",
                        percent: state.snapshot.weeklyPercent,
                        value: state.snapshot.weeklyValueText,
                        reset: state.snapshot.weeklyResetAt.map { Self.dateTimeFormatter.string(from: $0) } ?? "--",
                        used: state.snapshot.weeklyRemainingPercent.map { "已用 \(100 - $0)%" } ?? "待导入",
                        color: theme.secondary
                    )
                }

                HStack(spacing: 16) {
                    Label("刚刚更新 · 自动刷新", systemImage: "arrow.clockwise.circle")
                        .foregroundStyle(theme.primary)
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 6, height: 6)
                    Spacer()
                    if state.settings.menuBarShowsReset {
                        resetOpportunityBadge(theme: theme)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
        }
        .frame(width: 640)
        .fixedSize()
        .onHover { isHUDHovered = $0 }
    }

    private var hudCloseButton: some View {
        FloatingChromeButton(systemName: "xmark") {
            state.closeMode(.developerHUD)
        }
        .opacity(isHUDHovered ? 1 : 0)
        .scaleEffect(isHUDHovered ? 1 : 0.92)
        .allowsHitTesting(isHUDHovered)
        .animation(.easeOut(duration: 0.16), value: isHUDHovered)
    }

    private func resetOpportunityBadge(theme: ThemeSkin) -> some View {
        let count = state.snapshot.resets
        let tint = count > 0 ? theme.primary : theme.warning

        return HStack(spacing: 10) {
            Image(systemName: count > 0 ? "bolt.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .black))
            Text("重置机会")
                .font(.system(size: 13, weight: .bold))
            Text(state.snapshot.resetValueText)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(tint.opacity(0.16)))
        .overlay(Capsule().stroke(tint.opacity(0.72), lineWidth: 1.4))
        .shadow(color: tint.opacity(0.46), radius: 11)
    }

    private func warningChip(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(color.opacity(0.13)))
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }

    private func liquidMeter(title: String, percent: Int, value: String, reset: String, used: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.white.opacity(0.55))
                    .help("\(title) 会按官方 Usage 快照或本机 Codex 状态自动更新")
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(value)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                Text(value == "--" ? "剩余未知" : "剩余 \(value)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            LiquidEnergyBar(percent: percent, color: color)
            HStack {
                Label("下次重置时间", systemImage: "clock")
                Text(reset)
                Spacer()
                Text(used)
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.64))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd（EEE）"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

struct HUDPillButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.75 : 1)))
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

struct FloatingChromeButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 25, height: 25)
                .background(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        switch systemName {
        case "xmark": return "关闭当前悬浮窗"
        case "power": return "退出应用"
        default: return ""
        }
    }
}
