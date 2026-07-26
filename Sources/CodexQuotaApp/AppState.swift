import Combine
import CodexQuotaCore
import Foundation
import AppKit
import ServiceManagement

final class AppState: ObservableObject {
    @Published var settings: DisplaySettings
    @Published var snapshot: QuotaSnapshot
    @Published var importText: String = ""
    @Published var importError: String?

    private let store: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var isRefreshingUsage = false
    private var autoRefreshTimer: DispatchSourceTimer?

    init(store: SettingsStore = UserDefaultsSettingsStore()) {
        self.store = store
        self.settings = Self.normalizedSettings(store.loadSettings())
        self.snapshot = Self.normalizedSnapshot(store.loadSnapshot())

        $settings
            .dropFirst()
            .sink {
                store.saveSettings($0)
                LaunchAtLoginController.setEnabled($0.launchAtLogin)
            }
            .store(in: &cancellables)

        $snapshot
            .dropFirst()
            .sink { store.saveSnapshot($0) }
            .store(in: &cancellables)

        startAutoRefreshTimer()
    }

    var theme: ThemeSkin {
        settings.activeTheme
    }

    func updateSettings(_ transform: (inout DisplaySettings) -> Void) {
        var next = settings
        transform(&next)
        settings = Self.normalizedSettings(next)
    }

    func toggleMode(_ mode: DisplayMode) {
        updateSettings { settings in
            if settings.activeModes.contains(mode) {
                settings.activeModes.removeAll { $0 == mode }
            } else {
                settings.activeModes.append(mode)
            }
        }
    }

    func closeMode(_ mode: DisplayMode) {
        updateSettings { settings in
            settings.activeModes.removeAll { $0 == mode }
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func importStatusText() {
        do {
            snapshot = try StatusParser().parse(importText)
            importText = ""
            importError = nil
        } catch {
            importError = "没有识别到 5小时、一周或重置机会字段"
        }
    }

    func refreshSnapshotTimestamp() {
        refreshCodexUsage()
    }

    func refreshLocalCodexUsage() {
        refreshCodexUsage()
    }

    func refreshCodexUsage() {
        guard !isRefreshingUsage else { return }
        isRefreshingUsage = true
        DispatchQueue.global(qos: .userInitiated).async {
            let localSnapshot = LocalCodexUsageReader().latestSnapshot()
            let officialSnapshot = OfficialCodexUsageReader().latestSnapshot()
            let nextSnapshot = Self.merged(official: officialSnapshot, local: localSnapshot)

            DispatchQueue.main.async {
                self.isRefreshingUsage = false
                if let nextSnapshot {
                    self.snapshot = nextSnapshot
                    self.importError = nil
                } else {
                    self.snapshot.capturedAt = Date()
                    self.importError = "没有找到本机 Codex 登录态或用量记录"
                }
            }
        }
    }

    func openUsagePage() {
        guard let url = URL(string: "https://chatgpt.com/codex/usage") else { return }
        NSWorkspace.shared.open(url)
    }

    deinit {
        autoRefreshTimer?.cancel()
    }

    private func startAutoRefreshTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 30, repeating: 30, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in
            self?.refreshCodexUsage()
        }
        timer.resume()
        autoRefreshTimer = timer
    }
}

fileprivate extension AppState {
    static func normalizedSettings(_ settings: DisplaySettings) -> DisplaySettings {
        var next = settings
        next.activeModes.removeAll { $0 == .floatingCapsule }
        if next.schemaVersion < 2 {
            next.themeSkinId = "liquid_energy"
            next.customTheme = nil
            next.menuBarShowsFiveHour = false
            next.menuBarShowsWeekly = true
            next.menuBarShowsReset = true
            next.schemaVersion = 2
        }
        let validThemeIds = Set(ThemeSkin.presets.map(\.id))
        if next.themeSkinId != "custom", !validThemeIds.contains(next.themeSkinId) {
            next.themeSkinId = "liquid_energy"
        }
        if next.themeSkinId != "custom" {
            next.customTheme = nil
        }
        return next
    }

    static func normalizedSnapshot(_ snapshot: QuotaSnapshot) -> QuotaSnapshot {
        return snapshot
    }

    static func merged(official: QuotaSnapshot?, local: QuotaSnapshot?) -> QuotaSnapshot? {
        guard var snapshot = official ?? local else { return nil }

        if let local {
            if snapshot.fiveHourRemainingPercent == nil {
                snapshot.fiveHourRemainingPercent = local.fiveHourRemainingPercent
                snapshot.fiveHourRemainingText = local.fiveHourRemainingText
                snapshot.nextFiveHourResetAt = local.nextFiveHourResetAt
            }
            if snapshot.weeklyRemainingPercent == nil {
                snapshot.weeklyRemainingPercent = local.weeklyRemainingPercent
                snapshot.weeklyRemainingText = local.weeklyRemainingText
                snapshot.weeklyResetAt = local.weeklyResetAt
            }
            if snapshot.resetOpportunities == nil {
                snapshot.resetOpportunities = local.resetOpportunities
            }
        }

        return snapshot
    }
}

enum LaunchAtLoginController {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Launch-at-login can fail for unsigned development builds. Keep the app usable.
            }
        }
    }
}

protocol SettingsStore {
    func loadSettings() -> DisplaySettings
    func saveSettings(_ settings: DisplaySettings)
    func loadSnapshot() -> QuotaSnapshot
    func saveSnapshot(_ snapshot: QuotaSnapshot)
}

final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let settingsKey = "codexQuota.settings"
    private let snapshotKey = "codexQuota.snapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> DisplaySettings {
        decode(DisplaySettings.self, key: settingsKey) ?? DisplaySettings()
    }

    func saveSettings(_ settings: DisplaySettings) {
        encode(settings, key: settingsKey)
    }

    func loadSnapshot() -> QuotaSnapshot {
        decode(QuotaSnapshot.self, key: snapshotKey) ?? QuotaSnapshot(capturedAt: Date())
    }

    func saveSnapshot(_ snapshot: QuotaSnapshot) {
        encode(snapshot, key: snapshotKey)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
