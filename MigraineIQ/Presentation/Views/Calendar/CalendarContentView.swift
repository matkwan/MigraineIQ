//
//  CalendarContentView.swift
//  MigraineIQ
//
//  Monthly attack calendar with intensity-based colour overlay and a
//  trigger-detail sheet on day tap.
//
//  Layout:
//   ┌──────────────────────────────────┐
//   │  ← March 2025 →                 │  month header + nav arrows
//   │  S  M  T  W  T  F  S            │  weekday labels
//   │  [day cells — intensity colour]  │  calendar grid
//   │  ─────────────────────────────   │
//   │  TRIGGERS THIS MONTH             │  frequency bar chips
//   └──────────────────────────────────┘
//
//  Tap behaviour:
//   • Day with attacks  → DayDetailSheet (shows attacks + triggers + log-another button)
//   • Empty past day    → HeadacheDetailView pre-filled with noon on that date
//   • Future day        → no-op
//

import SwiftUI

struct CalendarContentView: View {
    @State var viewModel: CalendarViewModel

    /// Drives the back-date log sheet (empty-day tap or "log another" from DayDetailSheet).
    @State private var backdatedEvent: HeadacheEvent? = nil
    /// Drives the edit sheet — set when user swipes-to-edit an existing attack.
    @State private var attackToEdit: HeadacheEvent? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.l) {
                    monthNavigator
                    weekdayHeader
                    calendarGrid
                    if !viewModel.monthTriggerSummary.isEmpty {
                        triggerSummarySection
                    }
                }
                .padding(AppTheme.Spacing.m)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadMonth() }
            // Sheet 1: existing attack detail + log-another / edit / delete
            .sheet(item: $viewModel.selectedDay) { day in
                DayDetailSheet(
                    day: day,
                    onLogAnother: { event in
                        viewModel.selectedDay = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            backdatedEvent = event
                        }
                    },
                    onEdit: { attack in
                        viewModel.selectedDay = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            attackToEdit = attack
                        }
                    },
                    onDelete: { attack in
                        Task { await viewModel.delete(event: attack) }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
                .onDisappear { Task { await viewModel.loadMonth() } }
            }
            // Sheet 2: back-date log form (empty-day tap or "log another")
            .sheet(item: $backdatedEvent) { event in
                NavigationStack {
                    HeadacheDetailView(event: event, isNew: true)
                }
                .preferredColorScheme(.dark)
                .onDisappear { Task { await viewModel.loadMonth() } }
            }
            // Sheet 3: edit an existing attack
            .sheet(item: $attackToEdit) { attack in
                NavigationStack {
                    HeadacheDetailView(event: attack)
                }
                .preferredColorScheme(.dark)
                .onDisappear { Task { await viewModel.loadMonth() } }
            }
        }
    }

    // MARK: - Month navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(Circle())
            }

            Spacer()

            Text(viewModel.displayedMonthTitle)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .contentTransition(.numericText())

            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        viewModel.isCurrentMonth
                        ? AppTheme.Colors.tertiaryText
                        : AppTheme.Colors.accent
                    )
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(Circle())
            }
            .disabled(viewModel.isCurrentMonth)
        }
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.weekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.days) { day in
                DayCell(day: day)
                    .onTapGesture {
                        guard day.canLog else { return }
                        HapticService.selection()
                        if day.hasAttacks {
                            // Show existing attacks + option to log another
                            viewModel.selectDay(day)
                        } else {
                            // Empty past day — open log form pre-filled with noon on that date
                            backdatedEvent = HeadacheEvent(startedAt: noon(of: day.date))
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.displayedMonth)
    }

    private func noon(of date: Date) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    // MARK: - Monthly trigger summary

    private var triggerSummarySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("TRIGGERS THIS MONTH")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .kerning(0.8)

            VStack(spacing: AppTheme.Spacing.xs) {
                ForEach(viewModel.monthTriggerSummary, id: \.trigger) { item in
                    TriggerBar(
                        trigger: item.trigger,
                        count:   item.count,
                        max:     viewModel.monthTriggerSummary.first?.count ?? 1
                    )
                }
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let day: CalendarDay

    var body: some View {
        ZStack {
            // Background circle — filled with attack intensity colour
            Circle()
                .fill(background)
                .overlay(Circle().stroke(todayRing, lineWidth: 2))

            if day.hasAttacks {
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(size: 14, weight: day.isToday ? .bold : .regular))
                    .foregroundStyle(labelColor)
            } else {
                VStack(spacing: 0) {
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(.system(size: 14, weight: day.isToday ? .bold : .regular))
                        .foregroundStyle(labelColor)
                    // Subtle "+" hint on empty past days to signal tappability
                    if day.canLog && !day.isToday {
                        Text("+")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText.opacity(0.5))
                    }
                }
            }
        }
        .frame(height: 40)
        .opacity(day.isCurrentMonth ? 1 : 0.25)
    }

    private var background: Color {
        guard day.isCurrentMonth else { return .clear }
        switch day.riskIndicator {
        case .none:
            return day.isToday ? AppTheme.Colors.elevatedSurface : .clear
        case .attack(let intensity):
            return AppTheme.Colors.intensity(intensity).opacity(0.25)
        }
    }

    private var todayRing: Color {
        day.isToday ? AppTheme.Colors.accent.opacity(0.8) : .clear
    }

    private var labelColor: Color {
        guard day.isCurrentMonth else { return AppTheme.Colors.tertiaryText }
        switch day.riskIndicator {
        case .none:
            return day.isToday ? AppTheme.Colors.accent : AppTheme.Colors.secondaryText
        case .attack(let intensity):
            return AppTheme.Colors.intensity(intensity)
        }
    }
}

// MARK: - TriggerBar

private struct TriggerBar: View {
    let trigger: String
    let count:   Int
    let max:     Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Text(trigger)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.Colors.elevatedSurface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.Colors.accent.opacity(0.7))
                        .frame(
                            width: geo.size.width * CGFloat(count) / CGFloat(max),
                            height: 8
                        )
                        .animation(.spring(duration: 0.4), value: count)
                }
                .frame(height: 8)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text("\(count)×")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// MARK: - DayDetailSheet

private struct DayDetailSheet: View {
    let day: CalendarDay
    /// Called when the user wants to log a new attack on this day.
    var onLogAnother: (HeadacheEvent) -> Void = { _ in }
    /// Called when the user wants to edit an existing attack.
    var onEdit: (HeadacheEvent) -> Void = { _ in }
    /// Called when the user confirms deletion of an attack.
    var onDelete: (HeadacheEvent) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    /// Holds the attack pending a delete-confirmation dialog.
    @State private var attackToDelete: HeadacheEvent? = nil

    private var newEventForDay: HeadacheEvent {
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day.date) ?? day.date
        return HeadacheEvent(startedAt: noon)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                    intensitySummary
                    Divider().background(AppTheme.Colors.elevatedSurface)
                    attacksList
                    if !day.triggerFrequency.isEmpty {
                        Divider().background(AppTheme.Colors.elevatedSurface)
                        triggersSection
                    }
                    Divider().background(AppTheme.Colors.elevatedSurface)
                    logAnotherButton
                }
                .padding(AppTheme.Spacing.m)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
            .confirmationDialog(
                "Delete Attack",
                isPresented: Binding(
                    get: { attackToDelete != nil },
                    set: { if !$0 { attackToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let attack = attackToDelete {
                    Button("Delete", role: .destructive) {
                        onDelete(attack)
                        attackToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        attackToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently remove this attack entry.")
            }
        }
    }

    // MARK: Log another button

    private var logAnotherButton: some View {
        Button {
            onLogAnother(newEventForDay)
        } label: {
            Label("Log another attack on this day", systemImage: "plus.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(AppTheme.Colors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Intensity summary banner

    private var intensitySummary: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            // Peak intensity badge
            VStack(spacing: 4) {
                Text("\(day.maxIntensity)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.intensity(day.maxIntensity))
                    .contentTransition(.numericText())
                Text("peak NRS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .frame(width: 80)
            .padding(AppTheme.Spacing.s)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))

            // Attack count + classification summary
            VStack(alignment: .leading, spacing: 6) {
                Text(day.attacks.count == 1 ? "1 attack" : "\(day.attacks.count) attacks")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                let types = Set(day.attacks.map(\.classification.displayName))
                Text(types.joined(separator: ", "))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    // MARK: Individual attacks

    private var attacksList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("ATTACKS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .kerning(0.8)

            ForEach(day.attacks.sorted(by: { $0.startedAt < $1.startedAt })) { attack in
                AttackRow(attack: attack)
                    .onTapGesture { onEdit(attack) }
                    .contextMenu {
                        Button { onEdit(attack) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            attackToDelete = attack
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: Triggers section

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("SUSPECTED TRIGGERS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .kerning(0.8)

            // Wrap chips — simple flow using a fixed container
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: AppTheme.Spacing.xs)],
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(day.triggerFrequency, id: \.trigger) { item in
                    HStack(spacing: 4) {
                        Text(item.trigger)
                            .font(.system(size: 13, weight: .medium))
                        if item.count > 1 {
                            Text("×\(item.count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .padding(.horizontal, AppTheme.Spacing.s)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(AppTheme.Colors.accent.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - AttackRow

private struct AttackRow: View {
    let attack: HeadacheEvent

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            // Intensity indicator stripe
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AppTheme.Colors.intensity(attack.intensity))
                .frame(width: 4)
                .frame(height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(attack.startedAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)

                    Spacer()

                    // Intensity badge
                    Text("NRS \(attack.intensity)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.Colors.intensity(attack.intensity))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.intensity(attack.intensity).opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(attack.classification.displayName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                if let hours = attack.durationHours {
                    Text(String(format: "%.1f h duration", hours))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                } else {
                    Text("Ongoing")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.riskModerate)
                }
            }
        }
        .padding(AppTheme.Spacing.s)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    struct Wrapper: View {
        @State var vm = CalendarViewModel(headacheRepository: {
            let m = MockHeadacheRepository()
            m.stubbedRange = HeadacheEvent.mockList
            return m
        }())
        var body: some View {
            CalendarContentView(viewModel: vm)
                .task { await vm.loadMonth() }
        }
    }
    return Wrapper()
        .preferredColorScheme(.dark)
}
#endif


