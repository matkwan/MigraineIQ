//
//  InsightsView.swift
//  MigraineIQ
//

import SwiftUI

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                Text("Triggers, patterns, and AI coach land here in Phase 2.")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding(AppTheme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                Spacer()
            }
            .padding(AppTheme.Spacing.m)
            .background(AppTheme.Colors.background)
            .navigationTitle("Insights")
        }
    }
}
