import Foundation

/// Provides today's coding activity stats from Claude Code session JSONL files.
/// All parsing is done by `SessionUsageStore`; this is a thin facade.
final class ActivityParser: Sendable {
    static let shared = ActivityParser()
    private init() {}

    /// Today's stats aggregated from the durable usage database.
    /// Caller must ensure `SessionUsageStore.shared.refreshFromFilesystem()`
    /// has been awaited at least once this cycle.
    func getTodayStats() async throws -> ActivityStats {
        return try await SessionUsageStore.shared.activityStatsToday()
    }
}
