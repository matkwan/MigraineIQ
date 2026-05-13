//
//  PaywallView.swift
//  MigraineIQ
//
//  Full-screen paywall presented as a sheet whenever a Pro feature is
//  accessed without an active subscription.
//
//  Present it like:
//    .sheet(isPresented: $showPaywall) { PaywallView() }
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var manager = SubscriptionManager.shared
    @State private var selectedPlan: String = SubscriptionManager.ProductID.annual
    @State private var loadFailed = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    featureList
                    planCards
                    ctaSection
                    footerLinks
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.Colors.background)

            // Close button — overlaid so no NavigationStack nav bar gap
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .font(.system(size: 22))
            }
            .padding(.top, AppTheme.Spacing.m)
            .padding(.trailing, AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.dark)
        .task {
            loadFailed = false
            // Load with a 10-second timeout so the spinner never runs forever.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await manager.loadProducts() }
                group.addTask {
                    try? await Task.sleep(for: .seconds(10))
                }
                // Cancel remaining tasks once either finishes first.
                await group.next()
                group.cancelAll()
            }
            if manager.products.isEmpty {
                loadFailed = true
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            // Gradient blob
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Colors.accent.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            .padding(.top, AppTheme.Spacing.s)

            Text("MigraineIQ Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text("Clinical-grade tracking powered by AI.\nBuilt for the doctor visit.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            trialBadge
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.bottom, AppTheme.Spacing.l)
    }

    private var trialBadge: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "gift.fill")
                .font(.system(size: 13))
            Text("7-day free trial — cancel anytime")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(AppTheme.Colors.riskLow)
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.Colors.riskLow.opacity(0.12), in: Capsule())
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            ForEach(ProFeature.all) { feature in
                HStack(spacing: AppTheme.Spacing.s) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(AppTheme.Typography.body.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text(feature.subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.bottom, AppTheme.Spacing.l)
    }

    // MARK: - Plan cards

    private var planCards: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            if loadFailed {
                // Products failed to load — show a retry option so the
                // user (and App Store reviewer) aren't stuck on a spinner.
                VStack(spacing: AppTheme.Spacing.s) {
                    Text("Couldn't load subscription options.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                    Button {
                        Task {
                            loadFailed = false
                            await manager.loadProducts()
                            if manager.products.isEmpty { loadFailed = true }
                        }
                    } label: {
                        Text("Try Again")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xl)
            } else if manager.products.isEmpty {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.xl)
            } else {
                ForEach(manager.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedPlan == product.id,
                        displayPrice: manager.displayPrice(for: product)
                    )
                    .onTapGesture { selectedPlan = product.id }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.m)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            // Error message
            if let error = manager.purchaseError {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.riskHigh)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.m)
            }

            // Purchase button
            Button {
                Task {
                    guard let product = manager.products.first(where: { $0.id == selectedPlan })
                    else { return }
                    let success = await manager.purchase(product)
                    if success { dismiss() }
                }
            } label: {
                Group {
                    if manager.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start Free Trial")
                            .font(AppTheme.Typography.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.Colors.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(manager.isPurchasing || manager.products.isEmpty)
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.top, AppTheme.Spacing.m)

            Text("Then \(selectedPriceDescription). Cancel anytime.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .padding(.bottom, AppTheme.Spacing.m)
    }

    private var selectedPriceDescription: String {
        guard let product = manager.products.first(where: { $0.id == selectedPlan }) else {
            return "the selected plan"
        }
        return manager.displayPrice(for: product)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Button("Restore Purchases") {
                Task { await manager.restorePurchases() }
            }
            Text("·").foregroundStyle(AppTheme.Colors.tertiaryText)
            Link("Terms", destination: URL(string: "https://codevibelab.com/terms")!)
            Text("·").foregroundStyle(AppTheme.Colors.tertiaryText)
            Link("Privacy", destination: URL(string: "https://codevibelab.com/privacy")!)
        }
        .font(AppTheme.Typography.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .padding(.bottom, AppTheme.Spacing.xl)
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let displayPrice: String

    var isAnnual: Bool { product.id == SubscriptionManager.ProductID.annual }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(isAnnual ? "Annual" : "Monthly")
                        .font(AppTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    if isAnnual {
                        Text("BEST VALUE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.riskLow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.riskLow.opacity(0.15),
                                        in: Capsule())
                    }
                }
                Text(displayPrice)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                if isAnnual {
                    Text("Save ~38% vs monthly")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.riskLow.opacity(0.85))
                }
            }
            Spacer()
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText,
                            lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(AppTheme.Colors.accent)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? AppTheme.Colors.accent : Color.clear,
                                lineWidth: 2)
                )
        )
    }
}

// MARK: - Pro feature list model

private struct ProFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String

    static let all: [ProFeature] = [
        ProFeature(icon: "waveform.path.ecg",
                   title: "AI Risk Forecast",
                   subtitle: "Unlimited predictions · Free tier: 3 per week"),
        ProFeature(icon: "sparkles",
                   title: "Personal Trigger Model",
                   subtitle: "Unlimited recomputes · Free tier: 1 per month"),
        ProFeature(icon: "bubble.left.and.text.bubble.right",
                   title: "AI Coach",
                   subtitle: "\"Why did I get a migraine yesterday?\" answered with your data"),
        ProFeature(icon: "doc.text.fill",
                   title: "Doctor-Ready PDF Reports",
                   subtitle: "MIDAS + HIT-6 + ICHD-3, ready for your neurologist"),
        ProFeature(icon: "heart.fill",
                   title: "HealthKit Integration",
                   subtitle: "Sleep, HRV, and cycle data improve your forecast"),
        ProFeature(icon: "moon.stars.fill",
                   title: "Nightly Background Forecast",
                   subtitle: "Wake up to a risk alert before your migraine starts"),
        ProFeature(icon: "mic.fill",
                   title: "Voice Transcription",
                   subtitle: "Dictate attack notes hands-free — no typing during a painful episode"),
    ]
}

// MARK: - Preview

#Preview {
    PaywallView()
}
