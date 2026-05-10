//
//  MOHGaugeView.swift
//  MigraineIQ
//
//  MOH Guardian card for the Dashboard. Shows the user's current
//  Medication Overuse Headache risk at a glance:
//
//  • Level badge (Safe / Approaching / At Risk / Overuse) — colour-coded.
//  • Progress bars for triptans and analgesics vs their ICHD-3 thresholds.
//  • Plain-language explanation from the use case.
//
//  Design principle: the card should be readable by someone with photophobia
//  — high contrast, no animation, information hierarchy clear at a glance.
//

import SwiftUI

struct MOHGaugeView: View {
    let assessment: MOHRiskAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {

            // Title + level badge
            HStack {
                Text("MOH Guardian")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Spacer()
                levelBadge
            }

            // Progress bars
            VStack(spacing: AppTheme.Spacing.xs) {
                ClassBar(
                    label: "Triptans",
                    days: assessment.triptanDaysThisMonth,
                    threshold: ClinicalConstants.MOH.acuteThresholdDays,
                    warningDays: ClinicalConstants.MOH.acuteWarningDays
                )
                ClassBar(
                    label: "Analgesics",
                    days: assessment.nsaidDaysThisMonth,
                    threshold: ClinicalConstants.MOH.analgesicThresholdDays,
                    warningDays: ClinicalConstants.MOH.analgesicWarningDays
                )
            }

            // Explanation
            Text(assessment.explanation)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .strokeBorder(assessment.level.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    // MARK: - Level badge

    private var levelBadge: some View {
        Text(assessment.level.displayName)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, AppTheme.Spacing.xxs + 2)
            .background(assessment.level.color.opacity(0.18))
            .foregroundStyle(assessment.level.color)
            .clipShape(Capsule())
    }
}

// MARK: - ClassBar

private struct ClassBar: View {
    let label: String
    let days: Int
    let threshold: Int
    let warningDays: Int

    private var fraction: Double {
        guard threshold > 0 else { return 0 }
        return min(Double(days) / Double(threshold), 1.0)
    }

    private var barColor: Color {
        if days >= threshold      { return AppTheme.Colors.mohOveruse }
        if days >= threshold - 1  { return AppTheme.Colors.mohAtRisk }
        if days >= warningDays    { return AppTheme.Colors.mohApproaching }
        return AppTheme.Colors.mohSafe
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Spacer()
                Text("\(days) / \(threshold) days")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppTheme.Colors.elevatedSurface)
                        .frame(height: 6)
                    // Fill
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction, height: 6)
                    // Warning marker line
                    let warningX = geo.size.width * Double(warningDays) / Double(threshold)
                    Rectangle()
                        .fill(AppTheme.Colors.secondaryText.opacity(0.35))
                        .frame(width: 1, height: 8)
                        .offset(x: warningX - 0.5, y: -1)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Level display helpers (Presentation layer only)

extension MOHRiskAssessment.Level {
    var displayName: String {
        switch self {
        case .safe:       return "Safe"
        case .approaching: return "Approaching"
        case .atRisk:     return "At Risk"
        case .overuse:    return "Overuse"
        }
    }

    var color: Color {
        switch self {
        case .safe:       return AppTheme.Colors.mohSafe
        case .approaching: return AppTheme.Colors.mohApproaching
        case .atRisk:     return AppTheme.Colors.mohAtRisk
        case .overuse:    return AppTheme.Colors.mohOveruse
        }
    }
}

// MARK: - Previews

#Preview("Safe") {
    MOHGaugeView(assessment: .mockSafe)
        .padding()
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.dark)
}

#Preview("Approaching") {
    MOHGaugeView(assessment: .mockApproaching)
        .padding()
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.dark)
}

#Preview("Overuse") {
    MOHGaugeView(assessment: .mockOveruse)
        .padding()
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.dark)
}
