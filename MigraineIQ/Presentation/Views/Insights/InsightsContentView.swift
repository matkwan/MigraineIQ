//
//  InsightsContentView.swift
//  MigraineIQ
//
//  Content view for the Insights tab. Shows personal trigger analysis
//  (sorted by confidence) and a link to the AI Coach chat screen.
//

import SwiftUI

struct InsightsContentView: View {
    @State var viewModel: TriggersViewModel
    @State var midasViewModel: MIDASTrendViewModel
    @State private var showCoach = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.m) {
                    MIDASTrendView(viewModel: midasViewModel)
                    triggersSection
                    coachLinkCard
                }
                .padding(AppTheme.Spacing.m)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Insights")
            .task { await viewModel.loadTriggers() }
            // Re-run on every tab visit so data filled in since the last
            // visit is picked up automatically (force: false respects the
            // loaded cache — only fires the API if results aren't already shown).
            .onAppear { Task { await viewModel.loadTriggers() } }
            .refreshable { await viewModel.loadTriggers(force: true) }
            .navigationDestination(isPresented: $showCoach) {
                AICoachView()
            }
        }
    }

    // MARK: - Triggers section

    @ViewBuilder
    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack {
                Text("Personal Triggers")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Spacer()
                refreshButton
            }

            switch viewModel.viewState {
            case .idle:
                EmptyView()

            case .loading:
                TriggerLoadingCard()

            case .loaded(let triggers):
                ForEach(triggers) { trigger in
                    TriggerRow(insight: trigger)
                }

            case .noMetadata(let count):
                StatusCard(
                    icon: "pencil.and.list.clipboard",
                    title: count == 0
                        ? "No trigger data yet"
                        : "\(count) of 3 attacks have triggers",
                    message: "For each attack, open it from the Today tab → Edit details → Suspected triggers. The same trigger must appear across at least 3 attacks before a pattern can be confirmed."
                )

            case .empty:
                StatusCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No repeated triggers found",
                    message: "Your attacks have trigger data, but no single trigger appeared 3 or more times. The same suspected trigger (e.g. \"poor sleep\") needs to show up across multiple attacks for a pattern to be confirmed."
                )

            case .unavailable:
                StatusCard(
                    icon: "brain",
                    title: "AI not configured",
                    message: "Add your proxy URL and secret to Config.xcconfig to enable trigger analysis."
                )

            case .locked:
                ProLockedCard(
                    icon: "sparkles",
                    title: "Monthly analysis used",
                    message: "Free plan includes 1 trigger analysis per month. Upgrade to Pro for unlimited recomputes."
                )

            case .failed(let message):
                ErrorCard(message: message) {
                    Task { await viewModel.loadTriggers() }
                }
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var refreshButton: some View {
        if viewModel.viewState != .unavailable && viewModel.viewState != .locked {
            Button {
                Task { await viewModel.loadTriggers(force: true) }
            } label: {
                if case .loading = viewModel.viewState {
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .scaleEffect(0.8)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.accent)
                        .labelStyle(.iconOnly)
                }
            }
            .disabled(viewModel.viewState == .loading)
        }
    }

    // MARK: - Coach link

    private var coachLinkCard: some View {
        let isPro = SubscriptionManager.shared.isProSubscriber
        return Button {
            if isPro { showCoach = true } else { showPaywall = true }
        } label: {
            HStack(spacing: AppTheme.Spacing.s) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.Colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask the Coach")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("Chat with your personal AI migraine coach")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                if isPro {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                } else {
                    Text("Pro")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .padding(.horizontal, AppTheme.Spacing.s)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(AppTheme.Spacing.m)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - TriggerRow

private struct TriggerRow: View {
    let insight: TriggerInsight

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            // Strength badge
            Text(insight.strengthBand.badgeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.xs)
                .padding(.vertical, AppTheme.Spacing.xxs)
                .background(insight.strengthBand.badgeColor)
                .clipShape(Capsule())

            // Trigger name + occurrence
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.trigger)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("\(insight.occurrenceCount) occurrence\(insight.occurrenceCount == 1 ? "" : "s")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()

            // Confidence percentage
            Text("\(Int(insight.confidence * 100))%")
                .font(AppTheme.Typography.monoNumeric)
                .foregroundStyle(insight.strengthBand.badgeColor)
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}

// MARK: - Loading / status sub-views

private struct TriggerLoadingCard: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            ProgressView()
                .tint(AppTheme.Colors.accent)
            Text("Analysing your attack history…")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppTheme.Spacing.s)
    }
}

private struct StatusCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.m)
    }
}

private struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.riskHigh)
                .multilineTextAlignment(.center)
            Button("Try again", action: onRetry)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.s)
    }
}

// MARK: - StrengthBand display helpers

private extension TriggerInsight.StrengthBand {
    var badgeLabel: String {
        switch self {
        case .weak:     return "Weak"
        case .moderate: return "Moderate"
        case .strong:   return "Strong"
        }
    }

    var badgeColor: Color {
        switch self {
        case .weak:     return AppTheme.Colors.tertiaryText
        case .moderate: return AppTheme.Colors.riskModerate
        case .strong:   return AppTheme.Colors.riskHigh
        }
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview("Loaded") {
//    InsightsContentView(
//        viewModel: {
//            let vm = TriggersViewModel(
//                headacheRepository: MockHeadacheRepository(),
//                aiInsightsRepository: {
//                    let m = MockAIInsightsRepository()
//                    m.stubbedTriggers = TriggerInsight.mockList
//                    return m
//                }()
//            )
//            return vm
//        }()
//    )
//    .environment(DependencyContainer.preview())
//}
//
//#Preview("Unavailable") {
//    InsightsContentView(
//        viewModel: TriggersViewModel(headacheRepository: MockHeadacheRepository())
//    )
//    .environment(DependencyContainer.preview())
//}
