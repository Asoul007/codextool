import Foundation

public struct OfficialCodexUsageReader {
    private let codexHome: URL
    private let fileManager: FileManager

    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let creditsURL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    private static let maxAuthBytes: UInt64 = 256 * 1024
    private static let maxResponseBytes = 1024 * 1024

    public init(codexHome: URL? = nil, fileManager: FileManager = .default) {
        if let codexHome {
            self.codexHome = codexHome
        } else if let envHome = ProcessInfo.processInfo.environment["CODEX_HOME"], !envHome.isEmpty {
            self.codexHome = URL(fileURLWithPath: envHome)
        } else {
            self.codexHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        }
        self.fileManager = fileManager
    }

    public func latestSnapshot() -> QuotaSnapshot? {
        guard let auth = loadAuth(),
              let usage = json(from: Self.usageURL, auth: auth) else {
            return nil
        }

        let credits = json(from: Self.creditsURL, auth: auth)
        let rateLimit = dictionary(usage["rate_limit"]) ?? dictionary(usage["rateLimit"]) ?? usage
        let fiveHourWindow = parseWindow(findWindow(
            in: rateLimit,
            names: ["primary_window", "primaryWindow", "short_window", "shortWindow", "five_hour_window", "fiveHourWindow", "5h", "primary"],
            expectedSeconds: 18_000
        ))
        let weeklyWindow = parseWindow(findWindow(
            in: rateLimit,
            names: ["secondary_window", "secondaryWindow", "weekly_window", "weeklyWindow", "week_window", "weekWindow", "weekly", "secondary"],
            expectedSeconds: 604_800
        ))

        guard fiveHourWindow != nil || weeklyWindow != nil else {
            return nil
        }

        let resetCredits = resetCredits(from: credits) ?? resetCredits(from: dictionary(usage["rate_limit_reset_credits"]) ?? dictionary(usage["rateLimitResetCredits"]))

        return QuotaSnapshot(
            fiveHourRemainingPercent: fiveHourWindow?.remainingPercent,
            fiveHourRemainingText: fiveHourWindow.map { "\($0.remainingPercent)% · \(resetLabel($0.resetsAt))重置" },
            weeklyRemainingPercent: weeklyWindow?.remainingPercent,
            weeklyRemainingText: weeklyWindow.map { "\($0.remainingPercent)% · \(resetLabel($0.resetsAt))重置" },
            resetOpportunities: resetCredits,
            nextFiveHourResetAt: fiveHourWindow?.resetsAt,
            weeklyResetAt: weeklyWindow?.resetsAt,
            planType: string(usage["plan_type"]) ?? string(usage["planType"]),
            source: .officialUsageSnapshot,
            capturedAt: Date()
        )
    }

    private func loadAuth() -> Auth? {
        let authURL = codexHome.appendingPathComponent("auth.json")
        guard let attributes = try? fileManager.attributesOfItem(atPath: authURL.path),
              let size = attributes[.size] as? UInt64,
              size <= Self.maxAuthBytes,
              let data = try? Data(contentsOf: authURL),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let tokens = dictionary(value["tokens"]) ?? value
        guard let accessToken = string(tokens["access_token"]) ?? string(tokens["accessToken"]) else {
            return nil
        }
        let accountID = string(tokens["account_id"]) ?? string(tokens["accountId"]) ?? accountIDFromJWT(accessToken)
        return Auth(accessToken: accessToken, accountID: accountID)
    }

    private func json(from url: URL, auth: Auth) -> [String: Any]? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        if let accountID = auth.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var output: [String: Any]?

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let data,
                  data.count <= Self.maxResponseBytes,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            output = object
        }.resume()

        _ = semaphore.wait(timeout: .now() + 15)
        return output
    }

    private func findWindow(in rateLimit: [String: Any], names: [String], expectedSeconds: Int) -> [String: Any]? {
        for name in names {
            if let value = dictionary(rateLimit[name]), let window = parseWindow(value) {
                if expectedSeconds == 0 || window.windowSeconds == 0 || abs(window.windowSeconds - expectedSeconds) <= 60 {
                    return value
                }
            }
        }

        for value in rateLimit.values {
            guard let item = dictionary(value),
                  let window = parseWindow(item),
                  expectedSeconds > 0,
                  abs(window.windowSeconds - expectedSeconds) <= 60 else {
                continue
            }
            return item
        }

        for key in ["windows", "limit_windows", "limitWindows", "limits", "buckets"] {
            guard let items = rateLimit[key] as? [[String: Any]] else { continue }
            for item in items {
                guard let window = parseWindow(item) else { continue }
                let matchesDuration = expectedSeconds > 0 && abs(window.windowSeconds - expectedSeconds) <= 60
                let matchesName = string(item["name"]) ?? string(item["type"]) ?? string(item["id"]) ?? string(item["window"]) ?? string(item["label"])
                let normalizedName = matchesName?.lowercased()
                let namedMatch = normalizedName.map { text in
                    names.contains { text == $0.lowercased() || text.contains($0.lowercased()) }
                } ?? false
                if matchesDuration || namedMatch {
                    return item
                }
            }
        }

        return nil
    }

    private func parseWindow(_ value: [String: Any]?) -> UsageWindow? {
        guard let value else { return nil }

        let remainingPercent: Double
        if let remaining = keyedNumber(value, keys: ["remaining_percent", "remainingPercent", "remaining_pct", "remainingPct", "remaining_ratio", "remainingRatio", "remaining"]) {
            remainingPercent = scaleRatioField(remaining.key, remaining.value) ? remaining.value * 100 : remaining.value
        } else if let used = keyedNumber(value, keys: ["used_percent", "usedPercent", "used_pct", "usedPct", "used_ratio", "usedRatio", "utilization", "used"]) {
            let usedPercent = scaleRatioField(used.key, used.value) ? used.value * 100 : used.value
            remainingPercent = 100 - usedPercent
        } else {
            return nil
        }

        return UsageWindow(
            remainingPercent: max(0, min(100, Int(round(remainingPercent)))),
            resetsAt: date(value, keys: ["reset_at", "resetAt", "resets_at", "resetsAt", "reset_time", "resetTime"]),
            windowSeconds: windowSeconds(value)
        )
    }

    private func resetCredits(from value: [String: Any]?) -> Int? {
        guard let value else { return nil }
        return integer(value, keys: ["available_count", "availableCount", "remaining", "count", "quantity"])
    }

    private func windowSeconds(_ value: [String: Any]) -> Int {
        if let seconds = integer(value, keys: ["limit_window_seconds", "limitWindowSeconds", "window_seconds", "windowSeconds", "duration_seconds", "durationSeconds", "period_seconds", "periodSeconds"]) {
            return seconds
        }
        if let minutes = integer(value, keys: ["window_minutes", "windowMinutes"]) {
            return minutes * 60
        }
        return 0
    }

    private func keyedNumber(_ value: [String: Any], keys: [String]) -> (key: String, value: Double)? {
        for key in keys {
            if let number = number(value[key]) {
                return (key, number)
            }
        }
        return nil
    }

    private func scaleRatioField(_ key: String, _ value: Double) -> Bool {
        key == "remaining_ratio" || key == "remainingRatio" || key == "used_ratio" || key == "usedRatio" || key == "utilization" || (!key.contains("percent") && !key.contains("pct") && value <= 1)
    }

    private func accountIDFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - payload.count % 4) % 4
        payload += String(repeating: "=", count: padding)
        guard let data = Data(base64Encoded: payload),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return string(value["https://api.openai.com/auth.chatgpt_account_id"]) ?? string(value["chatgpt_account_id"])
    }

    private func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private func string(_ value: Any?) -> String? {
        value as? String
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? UInt { return Double(value) }
        return nil
    }

    private func integer(_ value: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let int = value[key] as? Int { return int }
            if let uint = value[key] as? UInt { return Int(uint) }
            if let double = value[key] as? Double { return Int(double) }
        }
        return nil
    }

    private func date(_ value: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let text = value[key] as? String {
                if let date = ISO8601DateFormatter().date(from: text) {
                    return date
                }
            }
            if let double = number(value[key]) {
                return Date(timeIntervalSince1970: double)
            }
        }
        return nil
    }

    private func resetLabel(_ date: Date?) -> String {
        guard let date else { return "未知时间" }
        return Self.resetFormatter.string(from: date)
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private struct Auth {
    let accessToken: String
    let accountID: String?
}

private struct UsageWindow {
    let remainingPercent: Int
    let resetsAt: Date?
    let windowSeconds: Int
}
