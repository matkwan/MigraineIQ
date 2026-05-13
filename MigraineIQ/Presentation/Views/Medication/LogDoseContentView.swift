//
//  LogDoseContentView.swift
//  MigraineIQ
//
//  Form for logging a single medication dose. Sections:
//   1. Medication name  — free-text + "RECENT" suggestion chips
//   2. Class            — menu picker
//   3. Dose amount      — optional toggle + stepper
//   4. Purpose          — Acute / Preventive / Rescue chips
//   5. Time taken       — DatePicker
//   6. Notes            — optional TextEditor
//   7. Save button
//

import SwiftUI

struct LogDoseContentView: View {
    @Bindable var viewModel: LogDoseViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var speechService = SpeechRecognitionService()
    @State private var showPaywall = false
    @State private var isManuallyStopping = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.m) {
                nameSection
                classSection
                doseSection
                purposeSection
                timeSection
                notesSection
                actionSection
            }
            .padding(AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(viewModel.isEditing ? "Edit medication" : "Log medication")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveForm() }
                    .disabled(!viewModel.canSave || viewModel.saveState == .saving)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .task { await viewModel.loadRecentNames() }
        .onDisappear {
            if case .recording = speechService.state { speechService.stop() }
        }
        .confirmationDialog(
            "Delete this dose?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { viewModel.delete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the dose from your history.")
        }
        .onChange(of: viewModel.saveState) { _, state in
            if case .saved   = state { dismiss() }
            if case .deleted = state { dismiss() }
        }
    }

    // MARK: - 1. Name

    private var nameSection: some View {
        DoseCard(title: "Medication") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                TextField("e.g. Sumatriptan 50mg", text: $viewModel.medicationName)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .tint(AppTheme.Colors.accent)
                    .autocorrectionDisabled()

                // Recent name suggestions
                if !viewModel.recentNames.isEmpty {
                    Divider().background(AppTheme.Colors.elevatedSurface)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("RECENT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .kerning(0.6)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                ForEach(viewModel.recentNames, id: \.self) { name in
                                    Button {
                                        viewModel.medicationName = name
                                    } label: {
                                        Text(name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                            .padding(.horizontal, AppTheme.Spacing.xs)
                                            .padding(.vertical, AppTheme.Spacing.xxs)
                                            .background(AppTheme.Colors.elevatedSurface)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(AppTheme.Colors.tertiaryText.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 2. Class

    private var classSection: some View {
        DoseCard(title: "Class") {
            Picker("Medication class", selection: $viewModel.medicationClass) {
                ForEach(MedicationClass.allCases) { cls in
                    Text(cls.displayName).tag(cls)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. Dose amount (optional)

    private var doseSection: some View {
        DoseCard(title: "Dose amount") {
            VStack(spacing: AppTheme.Spacing.s) {
                Toggle("Record dose in mg", isOn: $viewModel.hasDose)
                    .tint(AppTheme.Colors.accent)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                if viewModel.hasDose {
                    Divider().background(AppTheme.Colors.elevatedSurface)

                    Stepper(
                        value: $viewModel.doseMilligrams,
                        in: 25...1000,
                        step: 25
                    ) {
                        HStack {
                            Text("Amount")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.primaryText)
                            Spacer()
                            Text("\(Int(viewModel.doseMilligrams)) mg")
                                .font(AppTheme.Typography.monoNumeric)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                    .tint(AppTheme.Colors.accent)
                }
            }
        }
    }

    // MARK: - 4. Purpose

    private var purposeSection: some View {
        DoseCard(title: "Purpose") {
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(DosePurpose.allCases, id: \.self) { purpose in
                    PurposeChip(
                        label: purpose.chipLabel,
                        isSelected: viewModel.purpose == purpose
                    ) {
                        viewModel.purpose = purpose
                    }
                }
            }
        }
    }

    // MARK: - 5. Time

    private var timeSection: some View {
        DoseCard(title: "Time taken") {
            DatePicker(
                "When",
                selection: $viewModel.takenAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 6. Notes

    private var notesSection: some View {
        DoseCard(title: "Notes", trailing: { micButton }) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {

                // ── Live transcript preview ───────────────────────────────
                if case .recording = speechService.state {
                    Text(speechService.partialTranscript.isEmpty
                         ? "Listening…"
                         : speechService.partialTranscript)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(speechService.partialTranscript.isEmpty
                                         ? AppTheme.Colors.tertiaryText
                                         : AppTheme.Colors.accent)
                        .padding(.horizontal, 5)
                        .transition(.opacity)
                }

                // ── Unavailable error ─────────────────────────────────────
                if case .unavailable(let message) = speechService.state {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.riskModerate)
                        Text(message)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        Spacer()
                        Button("Dismiss") { speechService.resetError() }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .padding(AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.riskModerate.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // ── Notes text editor ─────────────────────────────────────
                ZStack(alignment: .topLeading) {
                    if viewModel.notes.isEmpty {
                        Text("Any additional notes…")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $viewModel.notes)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .tint(AppTheme.Colors.accent)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 72)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: speechService.state) { oldState, newState in
            guard case .recording = oldState, case .idle = newState else { return }
            guard !isManuallyStopping else { return }
            appendTranscript(speechService.partialTranscript)
            speechService.clearTranscript()
        }
    }

    // MARK: - Mic button

    @ViewBuilder
    private var micButton: some View {
        if SubscriptionManager.shared.isProSubscriber {
            Button {
                if case .recording = speechService.state {
                    isManuallyStopping = true
                    let transcript = speechService.stop()
                    appendTranscript(transcript)
                    isManuallyStopping = false
                } else {
                    Task { await speechService.start() }
                }
            } label: {
                MicButtonView(service: speechService)
            }
            .buttonStyle(.plain)
            .disabled({
                if case .requestingPermissions = speechService.state { return true }
                return false
            }())
        } else {
            Button { showPaywall = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.accent.opacity(0.2))
                        .clipShape(Capsule())
                }
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .padding(.horizontal, AppTheme.Spacing.s)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.elevatedSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.Colors.tertiaryText.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Dictation + save helpers

    private func appendTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let separator = viewModel.notes.isEmpty ? "" : "\n"
        viewModel.notes += separator + trimmed
    }

    private func saveForm() {
        if case .recording = speechService.state {
            isManuallyStopping = true
            let transcript = speechService.stop()
            appendTranscript(transcript)
            isManuallyStopping = false
        }
        viewModel.save()
    }

    // MARK: - 7. Action

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Button {
                saveForm()
            } label: {
                Group {
                    if viewModel.saveState == .saving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Log dose")
                    }
                }
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(
                    viewModel.canSave
                        ? AppTheme.Colors.accent
                        : AppTheme.Colors.accent.opacity(0.35)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            }
            .disabled(!viewModel.canSave || viewModel.saveState == .saving)

            if case .failure(let message) = viewModel.saveState {
                Text(message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.riskHigh)
                    .multilineTextAlignment(.center)
                    .onTapGesture { viewModel.clearError() }
            }

            if viewModel.isEditing {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete Dose")
                        .font(AppTheme.Typography.body.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.riskHigh)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.m)
                        .background(AppTheme.Colors.riskHigh.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                }
                .disabled(viewModel.saveState == .saving)
            }
        }
    }
}

// MARK: - DoseCard

private struct DoseCard<Content: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content:  () -> Content

    init(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) where Trailing == EmptyView {
        self.title    = title
        self.trailing = { EmptyView() }
        self.content  = content
    }

    init(
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content:  @escaping () -> Content
    ) {
        self.title    = title
        self.trailing = trailing
        self.content  = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(alignment: .center) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .kerning(0.8)
                Spacer()
                trailing()
            }

            content()
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - PurposeChip

private struct PurposeChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryText)
                .padding(.horizontal, AppTheme.Spacing.s)
                .padding(.vertical, AppTheme.Spacing.xs)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AppTheme.Colors.accentMuted : AppTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                        .stroke(
                            isSelected ? Color.clear : AppTheme.Colors.tertiaryText.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DosePurpose chip labels

private extension DosePurpose {
    var chipLabel: String {
        switch self {
        case .acute:      return "Acute"
        case .preventive: return "Preventive"
        case .rescue:     return "Rescue"
        }
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        LogDoseContentView(
//            viewModel: LogDoseViewModel(
//                medicationRepository: {
//                    let m = MockMedicationRepository()
//                    m.stubbedDoses = MedicationDose.mockList
//                    return m
//                }()
//            )
//        )
//    }
//    .preferredColorScheme(.dark)
//}
