import Foundation

// Fork-only (build-propia): some accounts get a 5-hour limit but no weekly
// percentage in their usage response. For those the usage tab shows a weekly
// bar estimated from the 5-hour sessions the app has seen.

extension UsageAPIResponse {
    /// True when the server reports a 5-hour session but no weekly percentage.
    var lacksWeeklyLimit: Bool {
        fiveHour?.utilization != nil
            && sevenDay?.utilization == nil
            && !(limits ?? []).contains { $0.kind == "weekly_all" && $0.percent != nil }
    }

    /// The weekly reset the server reports, with or without a percentage.
    var weeklyResetDate: Date? {
        if let date = sevenDay?.resetsAtDate { return date }
        let entry = (limits ?? []).first { $0.kind == "weekly_all" && $0.resetsAt != nil }
        return entry.flatMap { UsageWindow(utilization: nil, resetsAt: $0.resetsAt).resetsAtDate }
    }
}

/// Weekly usage estimated from 5-hour sessions.
enum WeeklyEstimate {
    /// Share of the week one full 5-hour session uses: a full session is
    /// roughly 13% of the weekly limit. An estimate, not an exact figure.
    static let weeklySharePerSession = 0.13

    /// Where the end of the estimated week comes from.
    enum ResetSource: Equatable {
        /// The server reported a weekly reset time without a percentage.
        case server
        /// The user picked the weekday and hour.
        case chosen
        /// The last weekly reset the server reported, carried forward a week at a time.
        case remembered
        /// Nothing known yet: Monday 00:00 until the user picks.
        case assumed
    }

    struct Week: Equatable {
        let end: Date
        let source: ResetSource
        var start: Date { end.addingTimeInterval(-RateLimitWindow.sevenDaySeconds) }
    }

    struct Result: Equatable {
        /// Estimated share of the week used, 0–100 (it can pass 100).
        let percent: Double
        let week: Week
        /// How much of the week has gone by, 0–100.
        let elapsedPercent: Double
        /// 5-hour sessions counted this week.
        let sessions: Int
    }
}

/// What the app keeps per account to estimate its week, saved to
/// `~/Library/Application Support/CCSwitcher/weekly-estimate.json`.
struct WeeklyEstimateBook: Codable, Equatable {
    struct Entry: Codable, Equatable {
        /// Highest 5-hour utilization seen per session, keyed by the session's
        /// reset time in whole Unix seconds.
        var sessionPeaks: [String: Double] = [:]
        /// Last weekly reset the server reported for this account.
        var lastServerWeeklyReset: Date?
        /// Weekday (1 = Sunday … 7 = Saturday) and hour the user picked.
        var chosenWeekday: Int?
        var chosenHour: Int?
    }

    /// Keyed by account UUID string.
    var entries: [String: Entry] = [:]

    /// Folds one usage sample in. Returns whether anything changed.
    @discardableResult
    mutating func record(_ usage: UsageAPIResponse, for account: UUID, now: Date = Date()) -> Bool {
        let key = account.uuidString
        let old = entries[key] ?? Entry()
        var entry = old
        if let reset = usage.weeklyResetDate,
           abs((entry.lastServerWeeklyReset ?? .distantPast).timeIntervalSince(reset)) > 60 {
            entry.lastServerWeeklyReset = reset
        }
        if usage.lacksWeeklyLimit,
           let utilization = usage.fiveHour?.utilization, utilization > 0,
           let reset = usage.fiveHour?.resetsAtDate {
            let seconds = Int(reset.timeIntervalSince1970.rounded())
            // One session's reset time can come back a few seconds apart.
            let sessionKey = entry.sessionPeaks.keys.first { abs((Int($0) ?? 0) - seconds) <= 300 } ?? String(seconds)
            entry.sessionPeaks[sessionKey] = max(entry.sessionPeaks[sessionKey] ?? 0, utilization)
        }
        let cutoff = now.timeIntervalSince1970 - RateLimitWindow.sevenDaySeconds - 86_400
        entry.sessionPeaks = entry.sessionPeaks.filter { (Double($0.key) ?? 0) > cutoff }
        guard entry != old else { return false }
        entries[key] = entry
        return true
    }

    mutating func choose(weekday: Int, hour: Int, for account: UUID) {
        var entry = entries[account.uuidString] ?? Entry()
        entry.chosenWeekday = weekday
        entry.chosenHour = hour
        entries[account.uuidString] = entry
    }

    /// The week the estimate covers: it ends at the next weekly reset.
    func week(for account: UUID, usage: UsageAPIResponse, now: Date = Date(), calendar: Calendar = .current) -> WeeklyEstimate.Week {
        let entry = entries[account.uuidString] ?? Entry()
        if let reset = usage.weeklyResetDate, reset > now {
            return .init(end: reset, source: .server)
        }
        if let weekday = entry.chosenWeekday, let hour = entry.chosenHour,
           let end = calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: 0, second: 0, weekday: weekday),
                                       matchingPolicy: .nextTime) {
            return .init(end: end, source: .chosen)
        }
        if let last = entry.lastServerWeeklyReset {
            let weeks = max(0, (now.timeIntervalSince(last) / RateLimitWindow.sevenDaySeconds).rounded(.up))
            var end = last.addingTimeInterval(weeks * RateLimitWindow.sevenDaySeconds)
            if end <= now { end.addTimeInterval(RateLimitWindow.sevenDaySeconds) }
            return .init(end: end, source: .remembered)
        }
        let monday = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: 2),
                                       matchingPolicy: .nextTime)
        return .init(end: monday ?? now.addingTimeInterval(RateLimitWindow.sevenDaySeconds), source: .assumed)
    }

    func estimate(for account: UUID, usage: UsageAPIResponse, now: Date = Date(), calendar: Calendar = .current) -> WeeklyEstimate.Result {
        let week = week(for: account, usage: usage, now: now, calendar: calendar)
        let peaks = (entries[account.uuidString]?.sessionPeaks ?? [:]).compactMap { key, peak -> Double? in
            guard let seconds = Double(key) else { return nil }
            let reset = Date(timeIntervalSince1970: seconds)
            // Every session that ran during this week, the current one too.
            guard reset > week.start,
                  reset.addingTimeInterval(-RateLimitWindow.fiveHourSeconds) < week.end else { return nil }
            return peak
        }
        let elapsed = 1 - week.end.timeIntervalSince(now) / RateLimitWindow.sevenDaySeconds
        return .init(percent: peaks.reduce(0, +) * WeeklyEstimate.weeklySharePerSession,
                     week: week,
                     elapsedPercent: min(max(elapsed, 0), 1) * 100,
                     sessions: peaks.count)
    }

    // MARK: - File

    private static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        return support.appendingPathComponent("CCSwitcher/weekly-estimate.json")
    }

    static func load() -> WeeklyEstimateBook {
        guard let data = try? Data(contentsOf: url) else { return .init() }
        return (try? JSONDecoder().decode(WeeklyEstimateBook.self, from: data)) ?? .init()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let url = Self.url
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
