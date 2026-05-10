//
//  OnboardingContentView.swift
//  MigraineIQ
//
//  3-step onboarding flow:
//    1. Carousel  — 3 swipeable feature cards (TabView paging)
//    2. Name      — optional first-name input
//    3. Notify    — system notification permission request
//
//  On completion, calls AppState.shared.completeOnboarding() which flips
//  hasCompletedOnboarding = true, causing AppRootView to swap in RootTabView.
//

import SwiftUI
import UserNotifications

struct OnboardingContentView: View {

    // MARK: - State

    @State private var step: Step = .carousel
    @State private var carouselPage: Int = 0
    @State private var nameInput: String = ""
    @State private var isRequestingPermission: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            switch step {
            case .carousel:
                carouselView
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            case .name:
                nameView
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            case .notification:
                notificationView
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .preferredColorScheme(.dark)
    }

    // MARK: - Step 1: Carousel

    private var carouselView: some View {
        VStack(spacing: 0) {
            // Paged cards
            TabView(selection: $carouselPage) {
                ForEach(CarouselPage.all.indices, id: \.self) { index in
                    CarouselPageView(page: CarouselPage.all[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Page dots
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(CarouselPage.all.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == carouselPage
                              ? AppTheme.Colors.accent
                              : AppTheme.Colors.tertiaryText.opacity(0.5))
                        .frame(width: index == carouselPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: carouselPage)
                }
            }
            .padding(.bottom, AppTheme.Spacing.l)

            // CTA
            primaryButton(
                label: carouselPage < CarouselPage.all.count - 1 ? "Next" : "Get Started",
                action: {
                    if carouselPage < CarouselPage.all.count - 1 {
                        withAnimation { carouselPage += 1 }
                    } else {
                        withAnimation { step = .name }
                    }
                }
            )
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }

    // MARK: - Step 2: Name

    private var nameView: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(AppTheme.Colors.accent)

                Text("What should we call you?")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Your name personalises your experience.\nYou can change this anytime in Settings.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            // Name field
            TextField("First name (optional)", text: $nameInput)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .tint(AppTheme.Colors.accent)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textContentType(.givenName)
                .padding(AppTheme.Spacing.m)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                .padding(.horizontal, AppTheme.Spacing.m)

            Spacer()

            VStack(spacing: AppTheme.Spacing.s) {
                primaryButton(label: "Continue") {
                    AppState.shared.userName = nameInput.trimmingCharacters(in: .whitespaces)
                    withAnimation { step = .notification }
                }

                skipButton(label: "Skip") {
                    withAnimation { step = .notification }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }

    // MARK: - Step 3: Notification permission

    private var notificationView: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Spacer()

            VStack(spacing: AppTheme.Spacing.m) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppTheme.Colors.accent)
                }

                Text("Stay ahead of your migraines")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text("MigraineIQ can alert you when your risk is elevated — before the headache starts. We only send what matters.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.Spacing.l)

            // Feature chips
            VStack(spacing: AppTheme.Spacing.xs) {
                notifFeatureRow(icon: "exclamationmark.triangle.fill",
                                color: AppTheme.Colors.riskElevated,
                                text: "High-risk alerts before symptoms start")
                notifFeatureRow(icon: "pill.fill",
                                color: AppTheme.Colors.riskHigh,
                                text: "Medication overuse warnings")
            }
            .padding(.horizontal, AppTheme.Spacing.m)

            Spacer()

            VStack(spacing: AppTheme.Spacing.s) {
                primaryButton(label: isRequestingPermission ? "Requesting…" : "Enable Notifications") {
                    requestNotificationPermission()
                }
                .disabled(isRequestingPermission)

                skipButton(label: "Not now") {
                    AppState.shared.completeOnboarding()
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }

    private func notifFeatureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    // MARK: - Notification permission

    private func requestNotificationPermission() {
        isRequestingPermission = true
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isRequestingPermission = false
                AppState.shared.completeOnboarding()
            }
        }
    }

    // MARK: - Shared button helpers

    private func primaryButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(AppTheme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func skipButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.s)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step enum

    private enum Step {
        case carousel, name, notification
    }
}

// MARK: - Carousel page model

private struct CarouselPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String

    static let all: [CarouselPage] = [
        CarouselPage(
            icon: "waveform.path.ecg",
            iconColor: AppTheme.Colors.accent,
            title: "Track Every Attack",
            body: "Log intensity, location, symptoms, and aura in seconds — even with eyes half-closed."
        ),
        CarouselPage(
            icon: "brain.head.profile",
            iconColor: AppTheme.Colors.riskModerate,
            title: "AI Predicts Your Risk",
            body: "Your personal AI combines sleep, weather, and history to forecast migraines 24 hours ahead."
        ),
        CarouselPage(
            icon: "sparkles",
            iconColor: AppTheme.Colors.riskLow,
            title: "Discover Your Triggers",
            body: "Confidence-scored trigger detection reveals exactly what's driving your attacks."
        ),
    ]
}

// MARK: - Carousel page view

private struct CarouselPageView: View {
    let page: CarouselPage

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.iconColor.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)

                Image(systemName: page.icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(page.iconColor)
            }

            VStack(spacing: AppTheme.Spacing.m) {
                Text(page.title)
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.l)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.m)
    }
}

// MARK: - Preview

#Preview("Carousel") {
    OnboardingContentView()
}
