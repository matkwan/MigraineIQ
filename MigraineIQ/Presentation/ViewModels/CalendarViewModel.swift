//
//  CalendarViewModel.swift
//  MigraineIQ
//
//  Drives the Calendar tab. Loads one month of CalendarDays at a time and
//  exposes month-navigation actions and a selected-day binding for the
//  day-detail sheet.
//

import Foundation
import Observation

@Observable
@MainActor
final class CalendarViewModel {

    // MARK: - View state

    enum ViewState: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    private(set) var viewState: ViewState = .idle

    // MARK: - Calendar data

    /// The first day of the month currently shown.
    private(set) var displayedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()

    /// All CalendarDays in the current grid (includes padding days from
    /// adjacent months so the grid is always a full set of weeks).
    private(set) var days: [CalendarDay] = []

    /// The day the user tapped — drives the detail sheet.
    var selectedDay: CalendarDay? = nil

    // MARK: - Monthly trigger summary
    //
    // Top triggers across the entire displayed month, for the heatmap
    // summary row shown below the calendar grid.

    private(set) var monthTriggerSummary: [(trigger: String, count: Int)] = []

    // MARK: - Dependencies

    private let useCase: BuildCalendarUseCase
    private let headacheRepository: HeadacheRepositoryProtocol

    // MARK: - Init

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.headacheRepository = headacheRepository
        self.useCase = BuildCalendarUseCase(headacheRepository: headacheRepository)
    }

    // MARK: - Data loading

    func loadMonth() async {
        viewState = .loading
        do {
            let loaded = try await useCase.execute(monthDate: displayedMonth)
            self.days = loaded
            self.monthTriggerSummary = computeMonthTriggerSummary(from: loaded)
            self.viewState = .success
        } catch {
            self.viewState = .failure(ErrorPresenter.userMessage(for: error))
        }
    }

    // MARK: - Month navigation

    func goToPreviousMonth() {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = prev
        Task { await loadMonth() }
    }

    func goToNextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        // Don't navigate into the future past the current month.
        let now = Date()
        let cal = Calendar.current
        if cal.compare(next, to: now, toGranularity: .month) == .orderedDescending { return }
        displayedMonth = next
        Task { await loadMonth() }
    }

    /// True when the displayed month is the current calendar month
    /// (prevents navigating forward into the future).
    var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Day selection

    func selectDay(_ day: CalendarDay) {
        guard day.hasAttacks else { return }
        selectedDay = day
    }

    // MARK: - Delete attack

    /// Hard-deletes the given attack, reloads the month, then dismisses the
    /// day-detail sheet (since the list has changed or is now empty).
    func delete(event: HeadacheEvent) async {
        do {
            try await headacheRepository.delete(id: event.id)
        } catch {
            // Surface error in future if needed; for now, just reload.
        }
        // Always reload so the grid stays consistent.
        do {
            let loaded = try await useCase.execute(monthDate: displayedMonth)
            self.days = loaded
            self.monthTriggerSummary = computeMonthTriggerSummary(from: loaded)
        } catch { /* ignore reload errors */ }

        // Dismiss the sheet — caller is responsible for re-tapping if they
        // want to see remaining attacks on that day.
        selectedDay = nil
    }

    // MARK: - Trigger summary

    private func computeMonthTriggerSummary(from days: [CalendarDay]) -> [(trigger: String, count: Int)] {
        let currentMonthDays = days.filter(\.isCurrentMonth)
        let raw = currentMonthDays
            .flatMap { $0.attacks }
            .flatMap(\.triggersSuspected)
            .reduce(into: [String: Int]()) { dict, t in dict[t, default: 0] += 1 }
        return raw.map { (trigger: $0.key, count: $0.value) }
                  .sorted { $0.count > $1.count }
                  .prefix(6)
                  .map { $0 }
    }

    // MARK: - Display helpers

    var displayedMonthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    /// Ordered weekday column headers (Sun/Mon … Sat/Sun based on locale).
    var weekdaySymbols: [String] {
        var cal = Calendar.current
        // Rotate the veryShortWeekdaySymbols so index 0 = firstWeekday
        let syms = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1  // 0-indexed
        return Array(syms[first...] + syms[..<first])
    }
}
