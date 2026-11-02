import SwiftUI

// Fork-only: pieces of the estimated weekly bar shared by both dashboards.

extension Theme {
    /// The estimated weekly bar's color, set apart from every real limit bar.
    static let estimated = Color.adaptive(light: Color(hexRGB: "#1E8C82")!, dark: Color(hexRGB: "#4CC3B5")!)

    @MainActor static let estimatedTooltip: LocalizedStringKey = "Estimate: this account reports no weekly limit. Each full 5-hour session counts as about 13 percent of the week, and only sessions CCSwitcher saw while open are counted. The line marks how much of the week has gone by: stay at or behind it to last the week."
}

extension WeeklyEstimate.Result {
    /// "≈ 3.8%", so it never reads like a real percentage. One decimal: a
    /// whole 5-hour session moves it only 13 points.
    var percentText: String {
        "≈ " + (percent / 100).formatted(.percent.precision(.fractionLength(0...1)).locale(L10n.locale))
    }

    /// Same countdown wording as the other rows ("Thu 3:00 PM", "5 hr 3 min").
    var resetText: String? {
        UsageWindow(utilization: nil, resetsAt: ISO8601DateFormatter().string(from: week.end)).resetTimeString
    }
}

/// Lets the user pick the weekday and hour an account's week resets. Hidden
/// when the server already reports it.
struct WeeklyResetMenu: View {
    let account: Account
    let week: WeeklyEstimate.Week

    @EnvironmentObject private var appState: AppState

    private struct Weekday: Identifiable {
        let id: Int
        let name: String
    }

    var body: some View {
        if week.source != .server {
            Menu {
                Picker("Reset day", selection: weekday) {
                    ForEach(weekdays) { Text($0.name).tag($0.id) }
                }
                Picker("Reset hour", selection: hour) {
                    ForEach(0..<24, id: \.self) { Text(hourName($0)).tag($0) }
                }
            } label: {
                Image(systemName: week.source == .assumed ? "calendar.badge.exclamationmark" : "calendar")
                    .font(.caption)
                    .foregroundStyle(week.source == .assumed ? Theme.warning : Theme.estimated)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(week.source == .assumed ? Self.pickTooltip : Self.chosenTooltip)
        }
    }

    private static let pickTooltip: LocalizedStringKey = "Pick the day and hour this account's week resets (Monday 00:00 until you do)"
    private static let chosenTooltip: LocalizedStringKey = "Day and hour this account's week resets"

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = L10n.locale
        return calendar
    }

    private var weekday: Binding<Int> {
        Binding(
            get: { calendar.component(.weekday, from: week.end) },
            set: { appState.chooseWeeklyReset(for: account, weekday: $0, hour: calendar.component(.hour, from: week.end)) }
        )
    }

    private var hour: Binding<Int> {
        Binding(
            get: { calendar.component(.hour, from: week.end) },
            set: { appState.chooseWeeklyReset(for: account, weekday: calendar.component(.weekday, from: week.end), hour: $0) }
        )
    }

    /// The week's days in the locale's order, starting on its first weekday.
    private var weekdays: [Weekday] {
        let symbols = calendar.weekdaySymbols
        return (0..<7).map { offset in
            let number = (calendar.firstWeekday - 1 + offset) % 7 + 1
            let name = symbols[number - 1]
            return Weekday(id: number, name: name.prefix(1).uppercased() + name.dropFirst())
        }
    }

    private func hourName(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
