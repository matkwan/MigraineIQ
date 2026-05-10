//
//  SettingsContentView.swift
//  MigraineIQ
//
//  Receives SettingsViewModel from SettingsView (shell). Pure rendering +
//  user-action dispatch — no environment reads, no direct HealthKit calls.
//

import SwiftUI
import StoreKit

struct SettingsContentView: View {

    @State var viewModel: SettingsViewModel
    @State private var showPaywall: Bool = false
    @Bindable private var appState = AppState.shared

    var body: some View {
        NavigationStack {
            List {
                profileSection
                subscriptionSection
                healthKitSection
                notificationsSection
                reportsSection
                supportSection
                appSection
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
        }
        .task {
            // Auto-request HealthKit on first launch for Pro subscribers.
            if SubscriptionManager.shared.isProSubscriber,
               viewModel.healthKitStatus == .notRequested {
                await viewModel.requestHealthKitAccess()
            }
            // Read notification status every time Settings opens.
            await viewModel.refreshNotificationStatus()
        }
    }

    // MARK: - Profile section

    private var profileSection: some View {
        Section {
            HStack(spacing: AppTheme.Spacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.Colors.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                TextField("Your name", text: $appState.userName)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .tint(AppTheme.Colors.accent)
                    .autocorrectionDisabled()
                    .textContentType(.givenName)
                    .submitLabel(.done)
            }
            .padding(.vertical, AppTheme.Spacing.xxs)
        } header: {
            Text("Profile")
        } footer: {
            Text("Used to personalise your experience.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
    }

    // MARK: - Notifications section

    private var notificationsSection: some View {
        Section {
            HStack(spacing: AppTheme.Spacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.Colors.riskModerate.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.riskModerate)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Migraine Alerts")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("Risk forecasts and MOH warnings")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                notificationStatusBadge
            }
            .padding(.vertical, AppTheme.Spacing.xxs)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.openSystemSettings() }
        } header: {
            Text("Notifications")
        } footer: {
            notificationFooter
        }
    }

    @ViewBuilder
    private var notificationStatusBadge: some View {
        switch viewModel.notificationStatus {
        case .authorized:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.riskLow)
                    .font(.system(size: 14))
                Text("Enabled")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.riskLow)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        case .denied:
            statusChip(label: "Disabled", color: AppTheme.Colors.riskModerate)
        case .unknown:
            statusChip(label: "Set up", color: AppTheme.Colors.accent)
        }
    }

    @ViewBuilder
    private var notificationFooter: some View {
        switch viewModel.notificationStatus {
        case .authorized:
            Text("Tap to manage alert settings in iOS Settings.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        case .denied:
            Text("Notifications are disabled. Tap to enable them in iOS Settings.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        case .unknown:
            Text("Tap to configure notification access in iOS Settings.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
    }

    // MARK: - Support section

    private var supportSection: some View {
        Section("Support") {
            // Rate the app
            Button {
                Task { @MainActor in
                    guard
                        let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive })
                            as? UIWindowScene
                    else { return }
                    SKStoreReviewController.requestReview(in: scene)
                }
            } label: {
                HStack(spacing: AppTheme.Spacing.s) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.Colors.riskLow.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.riskLow)
                    }
                    Text("Rate MigraineIQ")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
            }
            .buttonStyle(.plain)

            // Privacy policy
            Link(destination: URL(string: "https://codevibelab.com/privacy")!) {
                HStack(spacing: AppTheme.Spacing.s) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.Colors.tertiaryText.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                    Text("Privacy Policy")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
            }
        }
    }

    // MARK: - App section

    private var appSection: some View {
        Section {
            infoRow(
                label: "Version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
            )
            infoRow(
                label: "Install ID",
                value: InstallIdentity.current.prefix(8) + "…",
                mono: true
            )
        }
    }

    // MARK: - Subscription section

    private var subscriptionSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: AppTheme.Spacing.s) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.Colors.accent.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MigraineIQ Pro")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text(SubscriptionManager.shared.isProSubscriber
                             ? "Active — thank you!"
                             : "Unlock AI features & PDF reports")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(SubscriptionManager.shared.isProSubscriber
                                             ? AppTheme.Colors.riskLow
                                             : AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    if !SubscriptionManager.shared.isProSubscriber {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.riskLow)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
            }
            .buttonStyle(.plain)
            .disabled(SubscriptionManager.shared.isProSubscriber)
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - HealthKit section

    private var healthKitSection: some View {
        Section {
            healthKitRow
        } header: {
            Text("Data & Permissions")
        } footer: {
            healthKitFooter
        }
    }

    @ViewBuilder
    private var healthKitRow: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("HealthKit")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("Sleep, HRV & cycle data")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()

            healthKitStatusBadge
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
        // Free users: tap opens paywall.
        // Pro users: tap requests permission (if not yet asked) or opens iOS Settings.
        .contentShape(Rectangle())
        .onTapGesture {
            guard SubscriptionManager.shared.isProSubscriber else {
                showPaywall = true
                return
            }
            switch viewModel.healthKitStatus {
            case .notRequested:
                Task { await viewModel.requestHealthKitAccess() }
            case .requested:
                viewModel.openSystemSettings()
            case .unavailable:
                break
            }
        }
    }

    @ViewBuilder
    private var healthKitStatusBadge: some View {
        switch viewModel.healthKitStatus {
        case .unavailable:
            statusChip(label: "Unavailable", color: AppTheme.Colors.secondaryText)

        case .notRequested:
            if !SubscriptionManager.shared.isProSubscriber {
                // Teaser badge — tapping the row opens the paywall
                statusChip(label: "Pro", color: AppTheme.Colors.accent)
            } else if viewModel.isRequestingHealthKit {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
            } else {
                statusChip(label: "Connect", color: AppTheme.Colors.accent)
            }

        case .requested:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.riskLow)
                    .font(.system(size: 14))
                Text("Connected")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.riskLow)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }

    @ViewBuilder
    private var healthKitFooter: some View {
        switch viewModel.healthKitStatus {
        case .unavailable:
            Text("HealthKit is not available on this device.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)

        case .notRequested:
            if SubscriptionManager.shared.isProSubscriber {
                Text("Tap to connect your Apple Health data — sleep, heart rate variability, and menstrual cycle — to improve your risk forecasts.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            } else {
                Text("HealthKit integration is a Pro feature. Upgrade to let MigraineIQ read sleep, HRV, and cycle data to improve your forecasts.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }

        case .requested:
            if let error = viewModel.requestError {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.riskHigh)
            } else {
                Text("Tap to manage HealthKit access in iOS Settings.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Reports section

    private var reportsSection: some View {
        Section {
            if SubscriptionManager.shared.isProSubscriber {
                NavigationLink(destination: ReportView()) {
                    reportRowContent
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        reportRowContent
                        Spacer()
                        statusChip(label: "Pro", color: AppTheme.Colors.accent)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Reports")
        } footer: {
            if !SubscriptionManager.shared.isProSubscriber {
                Text("Clinical PDF reports are a Pro feature. Upgrade to generate doctor-ready summaries.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }

    private var reportRowContent: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Clinical Report")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("90-day PDF for your neurologist")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: some StringProtocol, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Spacer()
            Text(value)
                .font(mono ? AppTheme.Typography.monoNumeric : AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func statusChip(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Previews

#Preview("Not requested") {
    SettingsContentView(
        viewModel: SettingsViewModel(healthDataRepository: {
            let m = MockHealthDataRepository()
            m.stubbedIsAuthorized = false
            return m
        }())
    )
    .preferredColorScheme(.dark)
}

#Preview("Connected") {
    SettingsContentView(
        viewModel: SettingsViewModel(healthDataRepository: {
            let m = MockHealthDataRepository()
            m.stubbedIsAuthorized = true
            return m
        }())
    )
    .preferredColorScheme(.dark)
}

#Preview("Unavailable") {
    SettingsContentView(
        viewModel: SettingsViewModel(healthDataRepository: nil)
    )
    .preferredColorScheme(.dark)
}
