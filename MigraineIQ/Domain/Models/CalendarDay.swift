//
//  CalendarDay.swift
//  MigraineIQ
//
//  A single day on the calendar: its date, any attacks that started on
//  that day, and derived helpers for colour-coding and trigger display.
//
//  Risk indicator rules (past days use actual data, future days are nil):
//   • No attacks → .none  (no colour badge)
//   • Attacks exist → .attack(maxIntensity) → maps to the app's colour scale
//   (The AI's forward-looking forecast lives in DashboardViewModel; the
//    calendar intentionally shows ground-truth past data only.)
//

import Foundation

struct CalendarDay: Identifiable, Hashable {

    let date: Date
    /// All attacks whose `startedAt` falls on `date` (same calendar day).
    let attacks: [HeadacheEvent]
    /// True when `date` is in the currently displayed month (false for the
    /// grey padding days at the start/end of the grid).
    let isCurrentMonth: Bool

    var id: Date { date }

    // MARK: - Risk indicator

    enum RiskIndicator: Hashable {
        case none                    // no attacks today
        case attack(intensity: Int)  // max NRS intensity across all attacks
    }

    var riskIndicator: RiskIndicator {
        guard !attacks.isEmpty else { return .none }
        let maxIntensity = attacks.map(\.intensity).max() ?? 0
        return .attack(intensity: maxIntensity)
    }

    // MARK: - Trigger helpers

    /// Frequency map: trigger name → count across all attacks on this day.
    /// Sorted by descending frequency so the top trigger is first.
    var triggerFrequency: [(trigger: String, count: Int)] {
        let raw = attacks
            .flatMap(\.triggersSuspected)
            .reduce(into: [String: Int]()) { dict, t in dict[t, default: 0] += 1 }
        return raw.map { (trigger: $0.key, count: $0.value) }
                  .sorted { $0.count > $1.count }
    }

    var hasTriggers: Bool {
        attacks.contains { !$0.triggersSuspected.isEmpty }
    }

    // MARK: - Convenience

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// True when `date` is strictly after today (user cannot log an attack
    /// in the future — there's nothing to log yet).
    var isFuture: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedDescending
    }

    /// True when a past (or today) attack can be logged on this day.
    var canLog: Bool { isCurrentMonth && !isFuture }

    var hasAttacks: Bool { !attacks.isEmpty }

    var maxIntensity: Int {
        attacks.map(\.intensity).max() ?? 0
    }
}
