import Foundation

public struct LocalCodexUsageReader {
    private let codexHome: URL
    private let fileManager: FileManager

    public init(codexHome: URL? = nil, fileManager: FileManager = .default) {
        self.codexHome = codexHome ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        self.fileManager = fileManager
    }

    public func latestSnapshot(now: Date = Date()) -> QuotaSnapshot? {
        let roots = [
            codexHome.appendingPathComponent("sessions"),
            codexHome.appendingPathComponent("archived_sessions")
        ]

        let files = roots.flatMap { rolloutFiles(under: $0) }
            .sorted { lhs, rhs in
                modificationDate(lhs) > modificationDate(rhs)
            }
            .prefix(80)

        for file in files {
            if let snapshot = latestSnapshot(in: file, now: now) {
                return snapshot
            }
        }

        return nil
    }

    private func rolloutFiles(under root: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.lastPathComponent.hasPrefix("rollout-"), url.pathExtension == "jsonl" else {
                return nil
            }
            return url
        }
    }

    private func latestSnapshot(in file: URL, now: Date) -> QuotaSnapshot? {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            return nil
        }

        for line in content.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard line.contains("\"rate_limits\""),
                  let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  let rateLimits = payload["rate_limits"] as? [String: Any],
                  rateLimits["limit_id"] as? String == "codex" else {
                continue
            }

            if let snapshot = snapshot(from: rateLimits, timestamp: object["timestamp"] as? String, now: now) {
                return snapshot
            }
        }

        return nil
    }

    private func snapshot(from rateLimits: [String: Any], timestamp: String?, now: Date) -> QuotaSnapshot? {
        let limits = [
            rateLimits["primary"] as? [String: Any],
            rateLimits["secondary"] as? [String: Any]
        ].compactMap { $0 }

        guard !limits.isEmpty else { return nil }

        let fiveHourLimit = limits.first { Int(number($0["window_minutes"]) ?? -1) == 300 }
        let weeklyLimit = limits.first { Int(number($0["window_minutes"]) ?? -1) == 10080 }

        let fiveHourUsed = number(fiveHourLimit?["used_percent"])
        let weeklyUsed = number(weeklyLimit?["used_percent"])
        let fiveHourRemaining = fiveHourUsed.map { max(0, min(100, Int(round(100 - $0)))) }
        let weeklyRemaining = weeklyUsed.map { max(0, min(100, Int(round(100 - $0)))) }
        let fiveHourReset = dateFromUnixSeconds(fiveHourLimit?["resets_at"])
        let weeklyReset = dateFromUnixSeconds(weeklyLimit?["resets_at"])

        guard fiveHourRemaining != nil || weeklyRemaining != nil else {
            return nil
        }

        return QuotaSnapshot(
            fiveHourRemainingPercent: fiveHourRemaining,
            fiveHourRemainingText: fiveHourRemaining.map { "\($0)% · \(resetLabel(fiveHourReset))重置" },
            weeklyRemainingPercent: weeklyRemaining,
            weeklyRemainingText: weeklyRemaining.map { "\($0)% · \(resetLabel(weeklyReset))重置" },
            resetOpportunities: nil,
            nextFiveHourResetAt: fiveHourReset,
            weeklyResetAt: weeklyReset,
            source: .localCodexHistory,
            capturedAt: isoDate(timestamp) ?? now
        )
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }

    private func dateFromUnixSeconds(_ value: Any?) -> Date? {
        if let number = value as? Double {
            return Date(timeIntervalSince1970: number)
        }
        if let number = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(number))
        }
        return nil
    }

    private func resetLabel(_ date: Date?) -> String {
        guard let date else { return "未知时间" }
        return Self.resetFormatter.string(from: date)
    }

    private func isoDate(_ timestamp: String?) -> Date? {
        guard let timestamp else { return nil }
        return ISO8601DateFormatter().date(from: timestamp)
    }

    private func modificationDate(_ url: URL) -> Date {
        ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate) ?? .distantPast
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}
