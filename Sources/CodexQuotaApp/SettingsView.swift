import CodexQuotaCore
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        let theme = state.theme
        ZStack {
            settingsBackground(theme: theme)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Codex 用量")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("选择悬浮形态、主题皮肤和透明度")
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        Spacer()
                        Button(action: state.openUsagePage) {
                            Text("打开 Usage")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.white.opacity(0.1)))
                                .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    section("显示形态") {
                        HStack(spacing: 10) {
                            ForEach(DisplayMode.configurableCases) { mode in
                                DisplayModeToggleButton(
                                    mode: mode,
                                    isActive: state.settings.activeModes.contains(mode),
                                    theme: theme
                                ) {
                                    state.toggleMode(mode)
                                }
                            }
                        }
                    }

                    section("指标显示") {
                        HStack(spacing: 12) {
                            menuBarContentToggle("5小时", keyPath: \.menuBarShowsFiveHour)
                            menuBarContentToggle("一周", keyPath: \.menuBarShowsWeekly)
                            menuBarContentToggle("重置机会", keyPath: \.menuBarShowsReset)
                        }
                        Text("只有勾选的指标会显示在菜单栏、HUD 和悬浮球里。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    section("主题皮肤") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(ThemeSkin.presets) { skin in
                                let isSelected = state.settings.themeSkinId == skin.id
                                Button {
                                    state.updateSettings {
                                        $0.themeSkinId = skin.id
                                        $0.customTheme = nil
                                    }
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: skin.primaryColor))
                                            .frame(width: 14, height: 14)
                                        Text(skin.name)
                                            .fontWeight(isSelected ? .black : .bold)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white)
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(.white.opacity(isSelected ? 0 : 0.075))
                                            .overlay {
                                                if isSelected {
                                                    LinearGradient(
                                                        colors: [
                                                            Color(hex: skin.primaryColor).opacity(0.46),
                                                            Color(hex: skin.secondaryColor).opacity(0.34)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                    .clipShape(Capsule())
                                                }
                                            }
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? Color(hex: skin.primaryColor).opacity(0.98) : .white.opacity(0.14),
                                                lineWidth: isSelected ? 2 : 1
                                            )
                                    )
                                    .shadow(color: isSelected ? Color(hex: skin.secondaryColor).opacity(0.34) : .clear, radius: 10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("透明度") {
                        Picker("透明度", selection: settingBinding(\.transparencyMode)) {
                            ForEach(TransparencyMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.primary)

                        Text("全透明会隐藏背景容器，但保留文字、进度环和点击热区。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    section("行为") {
                        Toggle("置顶显示", isOn: settingBinding(\.alwaysOnTop))
                        Toggle("靠近屏幕边缘时自动吸附", isOn: settingBinding(\.snapToEdge))
                        Toggle("开机启动", isOn: settingBinding(\.launchAtLogin))
                    }
                    .foregroundStyle(.white)

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
        }
        .frame(width: 640, height: 720)
        .preferredColorScheme(.dark)
    }

    private func settingsBackground(theme: ThemeSkin) -> some View {
        ZStack {
            Color(hex: "#070A10")
            RadialGradient(
                colors: [theme.primary.opacity(0.20), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )
            RadialGradient(
                colors: [theme.secondary.opacity(0.20), .clear],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
            content()
        }
    }

    private func settingBinding<Value>(_ keyPath: WritableKeyPath<DisplaySettings, Value>) -> Binding<Value> {
        Binding(
            get: { state.settings[keyPath: keyPath] },
            set: { value in
                state.updateSettings { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func menuBarContentToggle(_ title: String, keyPath: WritableKeyPath<DisplaySettings, Bool>) -> some View {
        Button {
            state.updateSettings { $0[keyPath: keyPath].toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: state.settings[keyPath: keyPath] ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(state.settings[keyPath: keyPath] ? state.theme.primary : .white.opacity(0.45))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(state.settings[keyPath: keyPath] ? state.theme.primary.opacity(0.18) : .white.opacity(0.055)))
            .overlay(Capsule().stroke(state.settings[keyPath: keyPath] ? state.theme.primary.opacity(0.55) : .white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

}

struct DisplayModeToggleButton: View {
    let mode: DisplayMode
    let isActive: Bool
    let theme: ThemeSkin
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? theme.primary.opacity(0.22) : .white.opacity(0.075))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isActive ? theme.primary : .white.opacity(0.58))
                }
                .frame(width: 30, height: 30)

                Text(shortLabel)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                ZStack(alignment: isActive ? .trailing : .leading) {
                    Capsule()
                        .fill(isActive ? theme.primary : .white.opacity(0.16))
                    Circle()
                        .fill(.white)
                        .padding(2.5)
                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    Text(isActive ? "开" : "关")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(isActive ? .black.opacity(0.55) : .white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: isActive ? .leading : .trailing)
                        .padding(.horizontal, 7)
                }
                .frame(width: 46, height: 24)
            }
            .padding(.horizontal, 10)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isActive ? theme.primary.opacity(0.2) : .white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isActive ? theme.primary.opacity(0.85) : .white.opacity(0.12), lineWidth: isActive ? 1.5 : 1)
            )
            .shadow(color: isActive ? theme.primary.opacity(0.16) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var shortLabel: String {
        switch mode {
        case .floatingOrb: return "悬浮球"
        case .floatingCapsule: return "胶囊"
        case .developerHUD: return "HUD"
        case .menuBar: return "菜单栏"
        }
    }

    private var icon: String {
        switch mode {
        case .floatingOrb: return "circle.circle"
        case .floatingCapsule: return "capsule"
        case .developerHUD: return "rectangle.roundedtop"
        case .menuBar: return "menubar.rectangle"
        }
    }
}

struct MenuPopoverView: View {
    @ObservedObject var state: AppState

    var body: some View {
        let theme = state.theme
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Codex 用量")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                if !headerSummary.isEmpty {
                    Text(headerSummary)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(theme.primary.opacity(0.13)))
                }
            }

            HStack(spacing: 12) {
                if state.settings.menuBarShowsFiveHour {
                    QuotaRing(title: "5小时", valueText: state.snapshot.fiveHourValueText, percent: state.snapshot.fiveHourPercent, color: theme.primary, size: 86)
                }
                if state.settings.menuBarShowsWeekly {
                    QuotaRing(title: "一周", valueText: state.snapshot.weeklyValueText, percent: state.snapshot.weeklyPercent, color: theme.secondary, size: 86)
                }
                if state.settings.menuBarShowsReset {
                    QuotaRing(title: "重置", valueText: state.snapshot.resetValueText, percent: min(100, state.snapshot.resets * 34), color: theme.success, size: 86)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                if state.settings.menuBarShowsFiveHour {
                    popoverInfoRow(icon: "clock", label: "下次 5 小时重置", value: state.snapshot.nextFiveHourResetAt.map { Self.dateTimeFormatter.string(from: $0) } ?? "--", tint: theme.primary)
                    Divider().background(.white.opacity(0.1))
                }
                if state.settings.menuBarShowsWeekly {
                    popoverInfoRow(icon: "calendar", label: "下次重置时间", value: state.snapshot.weeklyResetAt.map { Self.dateTimeFormatter.string(from: $0) } ?? "--", tint: theme.secondary)
                    Divider().background(.white.opacity(0.1))
                }
                popoverInfoRow(icon: "externaldrive", label: "来源", value: state.snapshot.sourceLabel, tint: theme.primary)
                Divider().background(.white.opacity(0.1))
                popoverInfoRow(icon: "clock.arrow.circlepath", label: "上次更新", value: Self.dateTimeFormatter.string(from: state.snapshot.capturedAt), tint: theme.success)
                Divider().background(.white.opacity(0.1))
                popoverInfoRow(icon: "bolt.circle", label: "自动更新", value: "每 30 秒同步", tint: theme.primary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))

            HStack {
                popoverButton("刷新", icon: "arrow.clockwise", tint: theme.secondary, action: state.refreshSnapshotTimestamp)
                popoverButton("设置", icon: "gearshape", tint: .white.opacity(0.14)) {
                    NotificationCenter.default.post(name: .codexQuotaOpenSettings, object: nil)
                }
                popoverButton("退出", icon: "power", tint: .white.opacity(0.14)) {
                    NSApp.terminate(nil)
                }
                Spacer()
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: theme.glassTint).opacity(0.94))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .compositingGroup()
    }

    private var headerSummary: String {
        if state.settings.menuBarShowsFiveHour {
            return "5h \(state.snapshot.fiveHourValueText)"
        }
        if state.settings.menuBarShowsWeekly {
            return "W \(state.snapshot.weeklyValueText)"
        }
        if state.settings.menuBarShowsReset {
            return "R \(state.snapshot.resetValueText)"
        }
        return ""
    }

    private func popoverInfoRow(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.vertical, 9)
    }

    private func popoverButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(tint))
        }
        .buttonStyle(.plain)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

extension Notification.Name {
    static let codexQuotaOpenSettings = Notification.Name("codexQuotaOpenSettings")
}
