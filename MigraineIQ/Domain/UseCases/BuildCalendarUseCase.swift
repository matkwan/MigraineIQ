//
//  BuildCalendarUseCase.swift
//  MigraineIQ
//
//  Builds the full grid of CalendarDays for a given month.
//
//  Grid rules:
//   • Always returns a complete set of weeks (rows of 7 days).
//   • Days before the 1st and after the last of the month are padding days
//     (isCurrentMonth = false). They are included so the grid always fills
//     an exact number of rows with no gaps.
//   • Each day's attacks are the HeadacheEvents whose `startedAt` falls on
//     that calendar day (using the device's current Calendar/time-zone).
//

import Foundation

struct BuildCalendarUseCase {

    private let headacheRepository: HeadacheRepositoryProtocol

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.headacheRepository = headacheRepository
    }

    // MARK: - Execute

    /// Returns every CalendarDay in the grid for the month containing `monthDate`.
    func execute(monthDate: Date) async throws -> [CalendarDay] {
        let calendar = Calendar.current

        // 1. Find the first and last day of the target month.
        let monthStart  = calendar.startOfMonth(for: monthDate)
        let monthEnd    = calendar.endOfMonth(for: monthDate)

        // 2. Fetch all attacks that started anywhere in the displayed month.
        let interval = DateInterval(start: monthStart, end: monthEnd)
        let attacks  = try await headacheRepository.fetch(in: interval)

        // 3. Group attacks by their calendar day.
        var byDay: [DateComponents: [HeadacheEvent]] = [:]
        for attack in attacks {
            let comps = calendar.dateComponents([.year, .month, .day], from: attack.startedAt)
            byDay[comps, default: []].append(attack)
        }

        // 4. Build the padded grid.
        return buildGrid(
            monthStart:  monthStart,
            monthEnd:    monthEnd,
            attacksByDay: byDay,
            calendar:    calendar
        )
    }

    // MARK: - Grid builder

    private func buildGrid(
        monthStart:   Date,
        monthEnd:     Date,
        attacksByDay: [DateComponents: [HeadacheEvent]],
        calendar:     Calendar
    ) -> [CalendarDay] {

        // The grid starts on the Sunday (or Monday, per locale) of the week
        // containing the 1st of the month.
        let gridStart = calendar.startOfWeek(for: monthStart)

        // The grid ends on the Saturday (or Sunday) of the week containing
        // the last day of the month. We always show at least 5 rows (35 cells).
        let gridEnd = calendar.endOfWeek(for: monthEnd)

        var days: [CalendarDay] = []
        var current = gridStart

        while current <= gridEnd {
            let comps = calendar.dateComponents([.year, .month, .day], from: current)
            let isCurrentMonth = calendar.isDate(current, equalTo: monthStart, toGranularity: .month)
            let dayAttacks = attacksByDay[comps] ?? []

            days.append(CalendarDay(
                date:           current,
                attacks:        dayAttacks,
                isCurrentMonth: isCurrentMonth
            ))

            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return days
    }
}

// MARK: - Calendar helpers

private extension Calendar {

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func endOfMonth(for date: Date) -> Date {
        guard let start  = self.date(from: dateComponents([.year, .month], from: date)),
              let oneMonthLater = self.date(byAdding: .month, value: 1, to: start),
              let lastMoment    = self.date(byAdding: .second, value: -1, to: oneMonthLater)
        else { return date }
        return lastMoment
    }

    /// Returns the first day of the week that contains `date`
    /// (respects firstWeekday from the locale).
    func startOfWeek(for date: Date) -> Date {
        var comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = firstWeekday
        return self.date(from: comps) ?? date
    }

    /// Returns the last day of the week that contains `date`.
    func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return self.date(byAdding: .day, value: 6, to: start) ?? date
    }
}
