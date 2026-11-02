import XCTest
import Foundation

/// Fork-only: the estimated weekly bar for accounts without a weekly limit.
final class WeeklyEstimateTests: XCTestCase {
    /// Friday 2027-01-15 08:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = UUID()
    private let day: TimeInterval = 86_400

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    /// A usage response as the API returns it. Reset times are seconds from `now`.
    private func usage(
        session: Double? = nil, sessionResetsIn: TimeInterval = 3600,
        weekly: Double? = nil, weeklyResetsIn: TimeInterval? = nil,
        limits: [[String: Any]]? = nil
    ) throws -> UsageAPIResponse {
        var body: [String: Any] = [:]
        if let session {
            body["five_hour"] = ["utilization": session, "resets_at": iso(now.addingTimeInterval(sessionResetsIn))]
        }
        if weekly != nil || weeklyResetsIn != nil {
            var w: [String: Any] = [:]
            if let weekly { w["utilization"] = weekly }
            if let weeklyResetsIn { w["resets_at"] = iso(now.addingTimeInterval(weeklyResetsIn)) }
            body["seven_day"] = w
        }
        if let limits { body["limits"] = limits }
        let data = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(UsageAPIResponse.self, from: data)
    }

    func testOnlyAccountsWithoutWeeklyPercentageAreEstimated() throws {
        XCTAssertTrue(try usage(session: 20).lacksWeeklyLimit)
        XCTAssertTrue(try usage(session: 20, weeklyResetsIn: day).lacksWeeklyLimit)
        XCTAssertFalse(try usage(session: 20, weekly: 30, weeklyResetsIn: day).lacksWeeklyLimit)
        XCTAssertFalse(try usage(session: 20, limits: [["kind": "weekly_all", "percent": 30]]).lacksWeeklyLimit)
        XCTAssertFalse(try usage().lacksWeeklyLimit)
    }

    func testFlatZeroAfterNoPercentageStaysEstimated() throws {
        var book = WeeklyEstimateBook()
        // A real limit at 0%: not estimated.
        let zero = try usage(session: 30, weekly: 0, weeklyResetsIn: 7 * day)
        book.record(zero, for: account, now: now)
        XCTAssertFalse(book.estimatesWeekly(zero, for: account))

        // No percentage at all, then a flat 0% after the weekly reset: estimated,
        // and the session in progress counts.
        book.record(try usage(session: 27, weeklyResetsIn: -1), for: account, now: now)
        book.record(zero, for: account, now: now)
        XCTAssertTrue(book.estimatesWeekly(zero, for: account))
        XCTAssertEqual(book.estimate(for: account, usage: zero, now: now, calendar: calendar).percent, 3.9, accuracy: 0.001)

        // The first percentage above 0 means the limit is real.
        let real = try usage(session: 40, weekly: 2, weeklyResetsIn: 7 * day)
        book.record(real, for: account, now: now)
        XCTAssertFalse(book.estimatesWeekly(real, for: account))
        XCTAssertFalse(book.estimatesWeekly(zero, for: account))
    }

    func testRecordKeepsEachSessionsPeak() throws {
        var book = WeeklyEstimateBook()
        XCTAssertTrue(book.record(try usage(session: 30), for: account, now: now))
        // Same session, its reset time a few seconds off.
        XCTAssertTrue(book.record(try usage(session: 80, sessionResetsIn: 3620), for: account, now: now))
        XCTAssertFalse(book.record(try usage(session: 50, sessionResetsIn: 3610), for: account, now: now))
        XCTAssertEqual(book.entries[account.uuidString]?.sessionPeaks.values.sorted(), [80])
    }

    func testEstimateSumsThisWeeksSessions() throws {
        var book = WeeklyEstimateBook()
        book.choose(weekday: 5, hour: 15, for: account) // Thursday 15:00
        // Last week (before Thursday 14 Jan 15:00): not counted.
        book.record(try usage(session: 100, sessionResetsIn: -2 * day), for: account, now: now)
        // Two full sessions this week and the current one at half.
        book.record(try usage(session: 100, sessionResetsIn: -0.5 * day), for: account, now: now)
        book.record(try usage(session: 100, sessionResetsIn: -0.25 * day), for: account, now: now)
        let current = try usage(session: 50)
        book.record(current, for: account, now: now)

        let estimate = book.estimate(for: account, usage: current, now: now, calendar: calendar)
        XCTAssertEqual(estimate.sessions, 3)
        XCTAssertEqual(estimate.percent, 32.5, accuracy: 0.001)
        XCTAssertEqual(estimate.currentSessionPercent ?? -1, 6.5, accuracy: 0.001)
        XCTAssertEqual(estimate.week.source, .chosen)
        XCTAssertEqual(estimate.week.end, calendar.date(from: DateComponents(year: 2027, month: 1, day: 21, hour: 15)))
    }

    func testServerResetWinsWhenReported() throws {
        let reset = now.addingTimeInterval(2 * day)
        let sample = try usage(session: 10, limits: [["kind": "weekly_all", "resets_at": iso(reset)]])
        XCTAssertTrue(sample.lacksWeeklyLimit)
        var book = WeeklyEstimateBook()
        book.choose(weekday: 2, hour: 9, for: account)
        let week = book.week(for: account, usage: sample, now: now, calendar: calendar)
        XCTAssertEqual(week, .init(end: reset, source: .server))
    }

    func testLastServerResetIsCarriedForward() throws {
        var book = WeeklyEstimateBook()
        // Ten days ago the account still had a weekly limit.
        book.record(try usage(session: 5, weekly: 40, weeklyResetsIn: -10 * day), for: account, now: now)
        let week = book.week(for: account, usage: try usage(session: 5), now: now, calendar: calendar)
        XCTAssertEqual(week, .init(end: now.addingTimeInterval(4 * day), source: .remembered))
    }

    func testMondayMidnightUntilChosen() throws {
        let book = WeeklyEstimateBook()
        let week = book.week(for: account, usage: try usage(session: 5), now: now, calendar: calendar)
        XCTAssertEqual(week.source, .assumed)
        XCTAssertEqual(week.end, calendar.date(from: DateComponents(year: 2027, month: 1, day: 18)))
    }

    func testElapsedMarksHowMuchOfTheWeekPassed() throws {
        var book = WeeklyEstimateBook()
        book.choose(weekday: 2, hour: 20, for: account) // Monday 20:00 is 3.5 days away
        let estimate = book.estimate(for: account, usage: try usage(session: 0), now: now, calendar: calendar)
        XCTAssertEqual(estimate.elapsedPercent, 50, accuracy: 0.001)
        XCTAssertEqual(estimate.percent, 0)
        XCTAssertNil(estimate.currentSessionPercent)
    }

    func testOldSessionsAreDropped() throws {
        var book = WeeklyEstimateBook()
        book.record(try usage(session: 60, sessionResetsIn: -9 * day), for: account, now: now)
        book.record(try usage(session: 60), for: account, now: now)
        XCTAssertEqual(book.entries[account.uuidString]?.sessionPeaks.count, 1)
    }
}
