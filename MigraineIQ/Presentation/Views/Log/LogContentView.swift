//
//  LogContentView.swift
//  MigraineIQ
//
//  Quick-log scaffold. The real photophobia-first 1-tap experience lands
//  in Phase 3; this version proves the write path through the architecture.
//

import SwiftUI

struct LogContentView: View {
    @State var viewModel: LogViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    intensityCard
                    classificationCard
                    actionButton
                    statusFooter
                }
                .padding(AppTheme.Spacing.m)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Log attack")
        }
    }

    // MARK: - Sections ---------------------------------------------------

    private var intensityCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Intensity")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            HStack {
                Text("\(viewModel.draftIntensity)")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.Colors.intensity(viewModel.draftIntensity))
                Text("/10")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.draftIntensity) },
                    set: { viewModel.draftIntensity = Int($0) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(AppTheme.Colors.intensity(viewModel.draftIntensity))
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text("Type")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Picker("Type", selection: $viewModel.draftClassification) {
                ForEach(ICHD3Classification.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.accent)
        }
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var actionButton: some View {
        Button {
            Task { await viewModel.quickLog() }
        } label: {
            Text(viewModel.viewState == .saving ? "Saving…" : "Log this attack")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(AppTheme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .disabled(viewModel.viewState == .saving)
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch viewModel.viewState {
        case .saved:
            Text("Saved.").foregroundStyle(AppTheme.Colors.riskLow)
        case .failure(let message):
            Text(message).foregroundStyle(AppTheme.Colors.riskHigh)
        default:
            EmptyView()
        }
    }
}

#Preview {
    LogContentView(viewModel: LogViewModel(headacheRepository: MockHeadacheRepository()))
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.dark)
}
