import Foundation

public enum DisplayMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case floatingOrb = "floating_orb"
    case floatingCapsule = "floating_capsule"
    case developerHUD = "developer_hud"
    case menuBar = "menu_bar"

    public var id: String { rawValue }

    public static let configurableCases: [DisplayMode] = [.floatingOrb, .developerHUD, .menuBar]

    public var label: String {
        switch self {
        case .floatingOrb: return "悬浮球"
        case .floatingCapsule: return "悬浮胶囊"
        case .developerHUD: return "开发者 HUD"
        case .menuBar: return "菜单栏显示"
        }
    }
}

public enum TransparencyMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case opaque
    case translucent
    case highTranslucency = "high_translucency"
    case transparent

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .opaque: return "不透明"
        case .translucent: return "半透明"
        case .highTranslucency: return "高透明"
        case .transparent: return "全透明"
        }
    }

    public var backgroundOpacity: Double {
        switch self {
        case .opaque: return 0.94
        case .translucent: return 0.72
        case .highTranslucency: return 0.42
        case .transparent: return 0.0
        }
    }

    public var borderOpacity: Double {
        switch self {
        case .opaque: return 0.28
        case .translucent: return 0.34
        case .highTranslucency: return 0.48
        case .transparent: return 0.0
        }
    }
}

public struct ThemeSkin: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let primaryColor: String
    public let secondaryColor: String
    public let warningColor: String
    public let successColor: String
    public let glassTint: String

    public init(
        id: String,
        name: String,
        primaryColor: String,
        secondaryColor: String,
        warningColor: String,
        successColor: String,
        glassTint: String
    ) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.warningColor = warningColor
        self.successColor = successColor
        self.glassTint = glassTint
    }
}

public extension ThemeSkin {
    static let presets: [ThemeSkin] = [
        ThemeSkin(
            id: "liquid_energy",
            name: "流光能量",
            primaryColor: "#25E7FF",
            secondaryColor: "#A855F7",
            warningColor: "#FF8E8E",
            successColor: "#66F7D0",
            glassTint: "#030A16"
        ),
        ThemeSkin(
            id: "cyber_blue",
            name: "赛博蓝",
            primaryColor: "#22D3EE",
            secondaryColor: "#3B82F6",
            warningColor: "#F59E0B",
            successColor: "#22C55E",
            glassTint: "#07111F"
        ),
        ThemeSkin(
            id: "neon_purple",
            name: "霓虹紫",
            primaryColor: "#C084FC",
            secondaryColor: "#F472B6",
            warningColor: "#F59E0B",
            successColor: "#34D399",
            glassTint: "#12091F"
        ),
        ThemeSkin(
            id: "amber_orange",
            name: "琥珀橙",
            primaryColor: "#FB923C",
            secondaryColor: "#FACC15",
            warningColor: "#F97316",
            successColor: "#84CC16",
            glassTint: "#1D1007"
        )
    ]

    static func preset(id: String) -> ThemeSkin {
        presets.first { $0.id == id } ?? presets[0]
    }
}

public struct DisplaySettings: Codable, Equatable {
    public var schemaVersion: Int
    public var activeModes: [DisplayMode]
    public var themeSkinId: String
    public var transparencyMode: TransparencyMode
    public var customTheme: ThemeSkin?
    public var alwaysOnTop: Bool
    public var snapToEdge: Bool
    public var launchAtLogin: Bool
    public var menuBarShowsFiveHour: Bool
    public var menuBarShowsWeekly: Bool
    public var menuBarShowsReset: Bool

    public init(
        schemaVersion: Int = 2,
        activeModes: [DisplayMode] = [.floatingOrb, .menuBar],
        themeSkinId: String = "liquid_energy",
        transparencyMode: TransparencyMode = .translucent,
        customTheme: ThemeSkin? = nil,
        alwaysOnTop: Bool = true,
        snapToEdge: Bool = true,
        launchAtLogin: Bool = false,
        menuBarShowsFiveHour: Bool = false,
        menuBarShowsWeekly: Bool = true,
        menuBarShowsReset: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.activeModes = activeModes.filter { $0 != .floatingCapsule }
        self.themeSkinId = themeSkinId
        self.transparencyMode = transparencyMode
        self.customTheme = customTheme
        self.alwaysOnTop = alwaysOnTop
        self.snapToEdge = snapToEdge
        self.launchAtLogin = launchAtLogin
        self.menuBarShowsFiveHour = menuBarShowsFiveHour
        self.menuBarShowsWeekly = menuBarShowsWeekly
        self.menuBarShowsReset = menuBarShowsReset
    }

    public var activeTheme: ThemeSkin {
        themeSkinId == "custom" ? (customTheme ?? ThemeSkin.preset(id: "liquid_energy")) : ThemeSkin.preset(id: themeSkinId)
    }
}

public extension DisplaySettings {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case activeModes
        case themeSkinId
        case transparencyMode
        case customTheme
        case alwaysOnTop
        case snapToEdge
        case launchAtLogin
        case menuBarShowsFiveHour
        case menuBarShowsWeekly
        case menuBarShowsReset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        activeModes = (try container.decodeIfPresent([DisplayMode].self, forKey: .activeModes) ?? [.floatingOrb, .menuBar]).filter { $0 != .floatingCapsule }
        themeSkinId = try container.decodeIfPresent(String.self, forKey: .themeSkinId) ?? "liquid_energy"
        transparencyMode = try container.decodeIfPresent(TransparencyMode.self, forKey: .transparencyMode) ?? .translucent
        customTheme = try container.decodeIfPresent(ThemeSkin.self, forKey: .customTheme)
        alwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? true
        snapToEdge = try container.decodeIfPresent(Bool.self, forKey: .snapToEdge) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        menuBarShowsFiveHour = try container.decodeIfPresent(Bool.self, forKey: .menuBarShowsFiveHour) ?? false
        menuBarShowsWeekly = try container.decodeIfPresent(Bool.self, forKey: .menuBarShowsWeekly) ?? true
        menuBarShowsReset = try container.decodeIfPresent(Bool.self, forKey: .menuBarShowsReset) ?? true
    }
}

public enum QuotaSource: String, Codable, Equatable {
    case manual
    case cliStatusImport = "cli_status_import"
    case officialUsageSnapshot = "official_usage_snapshot"
    case localCodexHistory = "local_codex_history"
}

public struct QuotaSnapshot: Codable, Equatable {
    public var fiveHourRemainingPercent: Int?
    public var fiveHourRemainingText: String?
    public var weeklyRemainingPercent: Int?
    public var weeklyRemainingText: String?
    public var resetOpportunities: Int?
    public var nextFiveHourResetAt: Date?
    public var weeklyResetAt: Date?
    public var planType: String?
    public var source: QuotaSource
    public var capturedAt: Date

    public init(
        fiveHourRemainingPercent: Int? = nil,
        fiveHourRemainingText: String? = nil,
        weeklyRemainingPercent: Int? = nil,
        weeklyRemainingText: String? = nil,
        resetOpportunities: Int? = nil,
        nextFiveHourResetAt: Date? = nil,
        weeklyResetAt: Date? = nil,
        planType: String? = nil,
        source: QuotaSource = .officialUsageSnapshot,
        capturedAt: Date = Date()
    ) {
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.fiveHourRemainingText = fiveHourRemainingText
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyRemainingText = weeklyRemainingText
        self.resetOpportunities = resetOpportunities
        self.nextFiveHourResetAt = nextFiveHourResetAt
        self.weeklyResetAt = weeklyResetAt
        self.planType = planType
        self.source = source
        self.capturedAt = capturedAt
    }
}
