//
//  MIDASTrendView.swift
//  MigraineIQ
//
//  A card showing the user's MIDAS disability score month-over-month
//  as a colour-coded bar chart (Swift Charts). Each bar's colour
//  corresponds to the MIDAS grade for that month:
//    Green  → Little or no disability  (0–5)
//    Amber  → Mild disability          (6–10)
//    Orange → Moderate disability      (11–20)
//    Red    → Severe disability        (21+)
//
//  The header shows the current grade badge and a trend arrow
//  (↓ improving / ↑ worsening) compared to the previous month.
//

import SwiftUI
import Charts

struct MIDASTrendView: View {
    @State var viewModel: MIDASTrendViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            header

            if viewModel.isLoading {
                loadingView
            } else if !viewModel.hasData {
                emptyView
            } else {
                chartView
                gradeLegend
            }
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DISABILITY TREND")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .kerning(0.8)
                Text("MIDAS score · last 6 months")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()

            if let current = viewModel.currentSnapshot {
                VStack(alignment: .trailing, spacing: 6) {
                    // Current grade pill
                    Text(current.score.grade.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppTheme.Spacing.s)
                        .padding(.vertical, 4)
                        .background(current.score.grade.gradeColor)
                        .clipShape(Capsule())

                    // Month-on-month trend indicator
                    if let delta = viewModel.trendDelta {
                        HStack(spacing: 3) {
                            Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(abs(delta)) pts")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(delta > 0 ? AppTheme.Colors.riskHigh : AppTheme.Colors.riskLow)
                    }
                }
            }
        }
    }

    // MARK: - Bar chart

    private var chartView: some View {
        Chart(viewModel.snapshots) { snapshot in
            BarMark(
                x: .value("Month", snapshot.month, unit: .month),
                y: .value("MIDAS", snapshot.score.totalScore)
            )
            .foregroundStyle(snapshot.score.grade.gradeColor)
            .cornerRadius(6)
            .annotation(position: .top, alignment: .center) {
                if snapshot.score.totalScore > 0 {
                    Text("\(snapshot.score.totalScore)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .font(.system(size: 11))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(AppTheme.Colors.elevatedSurface)
                AxisValueLabel()
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .font(.system(size: 11))
            }
        }
        .chartPlotStyle { plot in
            plot.background(AppTheme.Colors.background.opacity(0.4))
                .cornerRadius(8)
        }
        .frame(height: 180)
    }

    // MARK: - Grade legend

    private var gradeLegend: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            ForEach(MIDASScore.Grade.allCases, id: \.self) { grade in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(grade.gradeColor)
                        .frame(width: 10, height: 10)
                    Text(grade.shortLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
            Spacer()
        }
    }

    // MARK: - Loading / empty states

    private var loadingView: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            ProgressView().tint(AppTheme.Colors.accent)
            Text("Calculating…")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Text("No disability data yet")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text("Fill in the disability section when logging attacks to track your MIDAS score over time.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - MIDASScore.Grade display helpers (view-layer only)

private extension MIDASScore.Grade {
    var gradeColor: Color {
        switch self {
        case .littleOrNone: return AppTheme.Colors.riskLow
        case .mild:         return AppTheme.Colors.riskModerate
        case .moderate:     return AppTheme.Colors.riskElevated
        case .severe:       return AppTheme.Colors.riskHigh
        }
    }

    var shortLabel: String {
        switch self {
        case .littleOrNone: return "None"
        case .mild:         return "Mild"
        case .moderate:     return "Moderate"
        case .severe:       return "Severe"
        }
    }
}
