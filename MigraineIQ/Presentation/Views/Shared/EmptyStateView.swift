//
//  EmptyStateView.swift
//  MigraineIQ
//
//  Reusable empty-state component used across Dashboard, Medication,
//  and Insights when there is no data to show.
//
//  Usage:
//    EmptyStateView(
//        icon: "waveform.path.ecg",
//        title: "No attacks logged yet",
//        message: "Tap the Log tab to record your first migraine."
//    )
//
//  Optional action button:
//    EmptyStateView(
//        icon: "pills",
//        title: "No medications logged",
//        message: "Tap + to add your first dose.",
//        actionLabel: "Log a dose",
//        action: { showLogDose = true }
//    )
//

import SwiftUI

struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.Colors.tertiaryText)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }

            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(AppTheme.Typography.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .padding(.horizontal, AppTheme.Spacing.m)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxl)
        .padding(.horizontal, AppTheme.Spacing.l)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EmptyStateView(
            icon: "waveform.path.ecg",
            title: "No attacks logged yet",
            message: "Tap the Log tab to record your first migraine."
        )
        EmptyStateView(
            icon: "pills",
            title: "No medications logged",
            message: "Tap + to add your first dose.",
            actionLabel: "Log a dose",
            action: {}
        )
    }
    .padding()
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.dark)
}
