import Foundation

public enum StatusParserError: Error, Equatable {
    case noQuotaFieldsFound
}

public struct StatusParser {
    public init() {}

    public func parse(_ text: String, now: Date = Date()) throws -> QuotaSnapshot {
        let fiveHour = percent(afterAnyOf: ["5小时", "5 小时", "5-hour", "five hour"], in: text)
        let weekly = percent(afterAnyOf: ["一周", "周", "weekly", "week"], in: text)
        let resets = integer(afterAnyOf: ["重置机会", "reset opportunities", "resets", "reset"], in: text)
        let weeklyReset = chineseMonthDay(afterAnyOf: ["1周", "1 周", "一周", "周"], in: text, now: now)

        guard fiveHour != nil || weekly != nil || resets != nil else {
            throw StatusParserError.noQuotaFieldsFound
        }

        return QuotaSnapshot(
            fiveHourRemainingPercent: fiveHour,
            fiveHourRemainingText: fiveHour.map { "\($0)% remaining" },
            weeklyRemainingPercent: weekly,
            weeklyRemainingText: weekly.map { value in
                if let weeklyReset {
                    return "\(value)% · \(Self.monthDayFormatter.string(from: weeklyReset))重置"
                }
                return "\(value)% remaining"
            },
            resetOpportunities: resets,
            weeklyResetAt: weeklyReset,
            source: .cliStatusImport,
            capturedAt: now
        )
    }

    private func percent(afterAnyOf labels: [String], in text: String) -> Int? {
        for label in labels {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            let pattern = "\(escaped)[^\\n\\r%]{0,80}?(\\d{1,3})\\s*%"
            if let value = firstInt(pattern: pattern, in: text), (0...100).contains(value) {
                return value
            }
        }
        return nil
    }

    private func integer(afterAnyOf labels: [String], in text: String) -> Int? {
        for label in labels {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            let pattern = "\(escaped)[^\\n\\r\\d]{0,40}(\\d{1,3})"
            if let value = firstInt(pattern: pattern, in: text) {
                return value
            }
        }
        return nil
    }

    private func firstInt(pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[swiftRange])
    }

    private func chineseMonthDay(afterAnyOf labels: [String], in text: String, now: Date) -> Date? {
        for label in labels {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            let pattern = "\(escaped)[^\\n\\r]{0,80}?(\\d{1,2})\\s*月\\s*(\\d{1,2})\\s*日"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text)),
                  match.numberOfRanges > 2,
                  let monthRange = Range(match.range(at: 1), in: text),
                  let dayRange = Range(match.range(at: 2), in: text),
                  let month = Int(text[monthRange]),
                  let day = Int(text[dayRange]) else {
                continue
            }

            var components = Calendar.current.dateComponents([.year], from: now)
            components.month = month
            components.day = day
            components.hour = 0
            components.minute = 0
            return Calendar.current.date(from: components)
        }
        return nil
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}
