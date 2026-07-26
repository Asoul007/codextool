import CodexQuotaCore
import SwiftUI

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        switch cleaned.count {
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        default:
            red = 0.2
            green = 0.7
            blue = 1.0
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension ThemeSkin {
    var primary: Color { Color(hex: primaryColor) }
    var secondary: Color { Color(hex: secondaryColor) }
    var warning: Color { Color(hex: warningColor) }
    var success: Color { Color(hex: successColor) }
    var glass: Color { Color(hex: glassTint) }
}

extension QuotaSnapshot {
    var fiveHourPercent: Int { fiveHourRemainingPercent ?? 0 }
    var weeklyPercent: Int { weeklyRemainingPercent ?? 0 }
    var resets: Int { resetOpportunities ?? 0 }
    var fiveHourValueText: String { fiveHourRemainingPercent.map { "\($0)%" } ?? "--" }
    var weeklyValueText: String { weeklyRemainingPercent.map { "\($0)%" } ?? "--" }
    var resetValueText: String { "\(resets)次" }
    var planBadgeText: String {
        let normalized = planType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
        return normalized?.isEmpty == false ? normalized! : "PLUS"
    }
    var fiveHourDetailText: String { fiveHourRemainingText ?? "未导入 5 小时用量" }
    var weeklyDetailText: String { weeklyRemainingText ?? "未导入一周用量" }
    var resetDetailText: String { "/ 3 次" }
    var fiveHourBadgeText: String { fiveHourRemainingPercent == nil ? "待导入" : (fiveHourPercent < 70 ? "偏低" : "充足") }
    var weeklyBadgeText: String { weeklyRemainingPercent == nil ? "待导入" : (weeklyPercent < 70 ? "偏低" : "充足") }
    var resetBadgeText: String { resets > 0 ? "充足" : "用尽" }

    var sourceLabel: String {
        switch source {
        case .manual: return "手动记录"
        case .cliStatusImport: return "/status 本地导入"
        case .officialUsageSnapshot: return "官方 Usage 实时同步"
        case .localCodexHistory: return "本机 Codex 用量记录"
        }
    }
}
