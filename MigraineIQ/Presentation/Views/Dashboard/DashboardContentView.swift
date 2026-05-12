//
//  DashboardContentView.swift
//  MigraineIQ
//
//  Today tab. Shows the AI risk card (Phase 2), ongoing attack (if any),
//  and the 5 most recent attacks. Phase 3 adds the MOH gauge.
//

import SwiftUI

struct DashboardContentView: View {
    @State var viewModel: DashboardViewModel
    @State private var eventToEdit: HeadacheEvent? = nil
    @State private var eventToDelete: HeadacheEvent? = nil
    @State private var showDeleteConfirmation = false
    /// Controls the new-attack sheet opened by the floating + button.
    @State private var showNewAttack = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    riskSection
                    mohSection
                    ongoingSection
                    recentSection
                }
                .padding(AppTheme.Spacing.m)
                // Extra bottom padding so the last card clears the FAB.
                .padding(.bottom, 80)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadDashboard() }
            .refreshable { await viewModel.loadDashboard(force: true) }
            .onAppear {
                Task { await viewModel.loadAttacks() }
                Task { await viewModel.loadRisk() }
            }
            // Value-based navigation (tap)
            .navigationDestination(for: HeadacheEvent.self) { event in
                HeadacheDetailView(event: event)
            }
            // Programmatic navigation (context menu Edit)
            .navigationDestination(item: $eventToEdit) { event in
                HeadacheDetailView(event: event)
            }
            .confirmationDialog(
                "Delete this attack?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let event = eventToDelete {
                        Task { await viewModel.delete(event) }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove the attack from your history. This cannot be undone.")
            }
            .overlay {
                if case .loading = viewModel.viewState, viewModel.recentAttacks.isEmpty {
                    ProgressView().tint(AppTheme.Colors.accent)
                }
            }
            // ── Floating + button ────────────────────────────────────────
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button {
                        showNewAttack = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(AppTheme.Colors.accent)
                            .clipShape(Circle())
                            .shadow(
                                color: AppTheme.Colors.accent.opacity(0.45),
                                radius: 10, x: 0, y: 4
                            )
                    }
                    .padding(.trailing, AppTheme.Spacing.m)
                    .padding(.bottom, AppTheme.Spacing.s)
                }
                .background(.clear)
            }
            // ── New-attack sheet ─────────────────────────────────────────
            .sheet(isPresented: $showNewAttack) {
                NavigationStack {
                    HeadacheDetailView(event: HeadacheEvent(startedAt: Date()), isNew: true)
                }
                .preferredColorScheme(.dark)
                .onDisappear {
                    Task { await viewModel.loadAttacks() }
                }
            }
            // ── Widget / Watch deep-link handler ─────────────────────────
            // `migraineiq://quicklog` sets pendingQuickLog = true after
            // switching the tab to Today (tab 0). We open the attack sheet
            // and clear the flag so a second tap works correctly.
            .onChange(of: AppState.shared.pendingQuickLog) { _, pending in
                guard pending else { return }
                AppState.shared.pendingQuickLog = false
                showNewAttack = true
            }
        }
    }

    // MARK: - Risk section --------------------------------------------------

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Today's risk")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            switch viewModel.riskState {
            case .unavailable:
                RiskUnavailableCard()

            case .noData:
                RiskNoDataCard()

            case .locked:
                ProLockedCard(
                    icon: "waveform.path.ecg",
                    title: "Weekly limit reached",
                    message: "Free plan includes 3 risk forecasts per week. Upgrade to Pro for unlimited daily forecasts."
                )

            case .loading:
                RiskLoadingCard()

            case .loaded(let alert):
                RiskCard(alert: alert)

            case .failed(let message):
                RiskErrorCard(message: message) {
                    Task { await viewModel.loadRisk() }
                }
            }
        }
    }

    // MARK: - MOH section --------------------------------------------------

    @ViewBuilder
    private var mohSection: some View {
        if let moh = viewModel.mohRisk {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                MOHGaugeView(assessment: moh)
            }
        }
    }

    // MARK: - Ongoing section -----------------------------------------------

    @ViewBuilder
    private var ongoingSection: some View {
        if let ongoing = viewModel.ongoingAttack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Text("Ongoing attack")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                NavigationLink(value: ongoing) {
                    AttackCard(event: ongoing, accent: AppTheme.Colors.intensity(ongoing.intensity))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { eventToEdit = ongoing } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        eventToDelete = ongoing
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Recent section ------------------------------------------------

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Recent")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            if viewModel.recentAttacks.isEmpty && viewModel.viewState == .success {
                EmptyStateView(
                    icon: "waveform.path.ecg",
                    title: "No attacks logged yet",
                    message: "Tap the + button below to record your first migraine."
                )
            } else {
                ForEach(viewModel.recentAttacks) { event in
                    NavigationLink(value: event) {
                        AttackCard(event: event, accent: AppTheme.Colors.intensity(event.intensity))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { eventToEdit = event } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            eventToDelete = event
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Risk card variants ------------------------------------------------

private struct RiskCard: View {
    let alert: PredictiveAlert

    var body: some View {
        let accent = alert.riskLevel.color

        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {

            // Score + level badge
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                Text("\(alert.riskScore)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                Text("%")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(accent)

                Spacer()

                Text(alert.riskLevel.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, AppTheme.Spacing.s)
                    .padding(.vertical, AppTheme.Spacing.xxs + 2)
                    .background(accent.opacity(0.18))
                    .foregroundStyle(accent)
                    .clipShape(Capsule())
            }

            // Primary contributing factors
            if !alert.primaryFactors.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs + 2) {
                    ForEach(alert.primaryFactors.prefix(3), id: \.self) { factor in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                            Circle()
                                .fill(accent)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(factor)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                }
            }

            // Recommended action
            if !alert.recommendedAction.isEmpty {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accent.opacity(0.8))
                    Text(alert.recommendedAction)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .padding(AppTheme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card - 4, style: .continuous))
            }

            // Expiry footer
            Divider().background(AppTheme.Colors.elevatedSurface)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(expiryLabel(for: alert.expiresAt))
                    .font(.system(size: 11))
            }
            .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func expiryLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let timeStr = date.formatted(date: .omitted, time: .shortened)

        if calendar.isDateInToday(date) {
            return "Valid until \(timeStr)"
        } else if calendar.isDateInTomorrow(date) {
            return "Valid until tomorrow, \(timeStr)"
        } else if date < now {
            return "Forecast expired — pull down to refresh"
        } else {
            let dayStr = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            return "Valid until \(dayStr), \(timeStr)"
        }
    }
}

// MARK: - Pro locked card (shared across Dashboard + Insights) ----------------

struct ProLockedCard: View {
    let icon: String
    let title: String
    let message: String
    @State private var showPaywall = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.Colors.accent)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Button("Upgrade to Pro") {
                    showPaywall = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .padding(.top, 2)
            }
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .strokeBorder(AppTheme.Colors.accent.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

private struct RiskLoadingCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            ProgressView()
                .tint(AppTheme.Colors.accent)
            Text("Calculating your 24-hour risk…")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

private struct RiskNoDataCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("No data yet")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Text("Log your first attack and the AI will start forecasting your personal 24-hour risk.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

private struct RiskUnavailableCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "brain.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("AI not configured")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Text("Set up your AI proxy in Settings to see your personal risk forecast.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

private struct RiskErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.Colors.riskModerate)
                Text("Couldn't load risk forecast")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Button("Try again", action: onRetry)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - Attack card (unchanged from Phase 1) ------------------------------

private struct AttackCard: View {
    let event: HeadacheEvent
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.m) {
            VStack {
                Text("\(event.intensity)")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(.white)
                Text("/10")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 56, height: 56)
            .background(accent)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(event.classification.displayName)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(event.startedAt, format: .relative(presentation: .named))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                if !event.symptoms.isEmpty {
                    Text(event.symptoms.map(\.displayName).sorted().joined(separator: " · "))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - RiskLevel display helpers (Presentation layer only) ---------------

private extension PredictiveAlert.RiskLevel {
    var displayName: String {
        switch self {
        case .low:      return "Low risk"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        case .high:     return "High risk"
        }
    }

    var color: Color {
        switch self {
        case .low:      return AppTheme.Colors.riskLow
        case .moderate: return AppTheme.Colors.riskModerate
        case .elevated: return AppTheme.Colors.riskElevated
        case .high:     return AppTheme.Colors.riskHigh
        }
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview("AI configured — high risk") {
//    DashboardContentView(viewModel: {
//        let mockMed = MockMedicationRepository()
//        mockMed.stubbedDistinctDays[.triptan] = 8
//        let vm = DashboardViewModel(
//            headacheRepository: MockHeadacheRepository(),
//            medicationRepository: mockMed,
//            aiInsightsRepository: {
//                let mock = MockAIInsightsRepository()
//                mock.stubbedAlert = .mockHighRisk
//                return mock
//            }()
//        )
//        return vm
//    }())
//    .background(AppTheme.Colors.background)
//    .preferredColorScheme(.dark)
//}
//
//#Preview("AI not configured") {
//    DashboardContentView(viewModel: {
//        let mock = MockHeadacheRepository()
//        mock.stubbedRecent = HeadacheEvent.mockList
//        return DashboardViewModel(
//            headacheRepository: mock,
//            medicationRepository: MockMedicationRepository()
//        )
//    }())
//    .background(AppTheme.Colors.background)
//    .preferredColorScheme(.dark)
//}
