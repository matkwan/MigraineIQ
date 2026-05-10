//
//  QuickLogContentView.swift
//  MigraineIQ
//
//  Photophobia-first quick-log screen.
//
//  Design constraints (from PROJECT_PLAN.md):
//  • Pure black background — not the dark navy; actual Color.black.
//  • Button ≥80pt tall — reachable with minimal eye movement.
//  • Single dim accent — no saturated colours, no bright whites.
//  • No spinners, no looping animations, no repeated haptics.
//    (One UINotificationFeedbackGenerator .success on save is acceptable
//     but we skip it entirely here to stay safe for all photophobia levels.)
//

import SwiftUI

struct QuickLogContentView: View {
    @State var viewModel: QuickLogViewModel
    @State private var navigationPath: [HeadacheEvent] = []
    @State private var showMedications = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea()

                if case .failure(let message) = viewModel.viewState {
                    failureState(message: message)
                } else {
                    readyState
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMedications = true
                    } label: {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                    .accessibilityLabel("Log medication")
                }
            }
            .navigationDestination(for: HeadacheEvent.self) { event in
                HeadacheDetailView(event: event)
            }
            .sheet(isPresented: $showMedications) {
                MedicationView()
            }
            // Auto-push to HeadacheDetail as soon as the event is saved.
            .onChange(of: viewModel.viewState) { _, state in
                if case .saved(let event) = state {
                    navigationPath = [event]
                }
            }
            // Reset the quick-log button when the user returns from HeadacheDetail.
            .onChange(of: navigationPath) { _, path in
                if path.isEmpty { viewModel.reset() }
            }
            // Widget deep-link: `migraineiq://quicklog` sets this flag.
            // Fire logNow() and immediately clear so a second widget tap
            // works correctly.
            .onChange(of: AppState.shared.pendingQuickLog) { _, pending in
                guard pending else { return }
                AppState.shared.pendingQuickLog = false
                viewModel.logNow()
            }
        }
    }

    // MARK: - Ready state — the big button

    private var readyState: some View {
        VStack(spacing: 0) {
            logButton
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.top, AppTheme.Spacing.xxl)
            Spacer()
        }
    }

    private var logButton: some View {
        Button {
            viewModel.logNow()
        } label: {
            Text("I'm having a migraine")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.accentMuted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 88)
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                        .stroke(AppTheme.Colors.accentMuted.opacity(0.35), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Failure state

    private func failureState(message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Spacer()
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.riskHigh)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.l)
            Button("Try again") { viewModel.reset() }
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.accentMuted)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Ready") {
    QuickLogContentView(
        viewModel: QuickLogViewModel(headacheRepository: MockHeadacheRepository())
    )
}

#Preview("Saved") {
    let vm = QuickLogViewModel(headacheRepository: MockHeadacheRepository())
    // Simulate saved state for preview
    QuickLogContentView(viewModel: vm)
        .onAppear { vm.logNow() }
}
