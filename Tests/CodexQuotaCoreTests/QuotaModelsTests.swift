import XCTest
@testable import CodexQuotaCore

final class QuotaModelsTests: XCTestCase {
    func testDefaultSettingsEnableOrbAndMenuBar() {
        let settings = DisplaySettings()

        XCTAssertEqual(settings.activeModes, [.floatingOrb, .menuBar])
        XCTAssertEqual(settings.themeSkinId, "liquid_energy")
        XCTAssertEqual(settings.transparencyMode, .translucent)
        XCTAssertFalse(settings.menuBarShowsFiveHour)
        XCTAssertTrue(settings.menuBarShowsWeekly)
        XCTAssertTrue(settings.menuBarShowsReset)
        XCTAssertTrue(settings.alwaysOnTop)
        XCTAssertTrue(settings.snapToEdge)
    }

    func testTransparentModeKeepsVisibleContentButRemovesContainerChrome() {
        XCTAssertEqual(TransparencyMode.transparent.backgroundOpacity, 0.0)
        XCTAssertEqual(TransparencyMode.transparent.borderOpacity, 0.0)
        XCTAssertGreaterThan(TransparencyMode.highTranslucency.backgroundOpacity, 0.0)
        XCTAssertLessThan(TransparencyMode.highTranslucency.backgroundOpacity, TransparencyMode.translucent.backgroundOpacity)
    }

    func testThemePresetsIncludeRequiredSkins() {
        let names = Set(ThemeSkin.presets.map(\.name))

        XCTAssertTrue(names.contains("流光能量"))
        XCTAssertTrue(names.contains("赛博蓝"))
        XCTAssertTrue(names.contains("霓虹紫"))
        XCTAssertTrue(names.contains("琥珀橙"))
        XCTAssertFalse(names.contains("极光绿"))
        XCTAssertFalse(names.contains("纯黑玻璃"))
        XCTAssertFalse(names.contains("系统跟随"))
    }

    func testSettingsRoundTripThroughJSON() throws {
        let settings = DisplaySettings(
            activeModes: [.floatingOrb, .floatingCapsule, .developerHUD, .menuBar],
            themeSkinId: "neon_purple",
            transparencyMode: .highTranslucency,
            alwaysOnTop: false,
            snapToEdge: true,
            launchAtLogin: true
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(DisplaySettings.self, from: data)

        XCTAssertEqual(decoded, settings)
        XCTAssertFalse(decoded.activeModes.contains(.floatingCapsule))
    }

    func testSnapshotRoundTripKeepsPlanType() throws {
        let snapshot = QuotaSnapshot(
            weeklyRemainingPercent: 96,
            resetOpportunities: 0,
            planType: "plus",
            source: .officialUsageSnapshot
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(QuotaSnapshot.self, from: data)

        XCTAssertEqual(decoded.planType, "plus")
        XCTAssertEqual(decoded.weeklyRemainingPercent, 96)
    }
}
