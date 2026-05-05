//
//  DashboardContentView.swift
//  MigraineIQ
//
//  Phase 1 dashboard. Shows the ongoing attack (if any) and the 5 most
//  recent. Phase 2 will replace the placeholder cards with the AI risk
//  forecast, the MOH gauge, and the trigger-of-the-week.
//

import SwiftUI

struct DashboardContentView: View {
    @State var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    todaySection
                    ongoingSection
                    recentSection
                }
                .padding(AppTheme.Spacing.m)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadDashboard() }
            .refreshable { await viewModel.loadDashboard() }
            .overlay {
                if case .loading = viewModel.viewState, viewModel.recentAttacks.isEmpty {
                    ProgressView().tint(AppTheme.Colors.accent)
                }
            }
        }
    }

    // MARK: - Sections ---------------------------------------------------

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Today's risk")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Coming in Phase 2")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("AI-powered 24h migraine risk forecast based on sleep, weather, and your personal trigger model.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .padding(AppTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    @ViewBuilder
    private var ongoingSection: some View {
        if let ongoing = viewModel.ongoingAttack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Text("Ongoing attack")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                AttackCard(event: ongoing, accent: AppTheme.Colors.intensity(ongoing.intensity))
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Recent")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            if viewModel.recentAttacks.isEmpty {
                Text("No attacks logged yet. Tap the Log tab to record your first.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .padding(AppTheme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            } else {
                ForEach(viewModel.recentAttacks) { event in
                    AttackCard(event: event, accent: AppTheme.Colors.intensity(event.intensity))
                }
            }
        }
    }
}

// MARK: - Reusable card --------------------------------------------------

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
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

#Preview {
    DashboardContentView(viewModel: {
        let mock = MockHeadacheRepository()
        mock.stubbedRecent = HeadacheEvent.mockList
        return DashboardViewModel(headacheRepository: mock)
    }())
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.dark)
}
