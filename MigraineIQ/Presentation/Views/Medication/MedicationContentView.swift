//
//  MedicationContentView.swift
//  MigraineIQ
//
//  Medication history for the last 30 days, grouped by calendar day.
//  Swipe-to-delete on each row. "+" toolbar button pushes LogDoseView.
//

import SwiftUI

struct MedicationContentView: View {
    @State var viewModel: MedicationViewModel
    @State private var showLogDose = false
    @State private var doseToEdit: MedicationDose? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.m) {
                switch viewModel.viewState {
                case .loading:
                    loadingCard

                case .empty:
                    emptyCard

                case .failed(let message):
                    errorCard(message)

                case .loaded(let doses):
                    ForEach(grouped(doses), id: \.0) { label, group in
                        daySection(label: label, doses: group)
                    }
                }
            }
            .padding(AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(AppTheme.Colors.accent)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showLogDose = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
        .navigationDestination(isPresented: $showLogDose) {
            LogDoseView()
        }
        .sheet(item: $doseToEdit) { dose in
            NavigationStack {
                LogDoseView(editing: dose)
            }
            .preferredColorScheme(.dark)
            .onDisappear { Task { await viewModel.load() } }
        }
        .onAppear { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Day section

    private func daySection(label: String, doses: [MedicationDose]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .kerning(0.8)
                .padding(.leading, AppTheme.Spacing.xs)

            VStack(spacing: 0) {
                ForEach(doses) { dose in
                    DoseRow(
                        dose: dose,
                        onEdit: { doseToEdit = dose },
                        onDelete: { Task { await viewModel.delete(dose) } }
                    )

                    if dose.id != doses.last?.id {
                        Divider()
                            .background(AppTheme.Colors.elevatedSurface)
                            .padding(.leading, AppTheme.Spacing.m)
                    }
                }
            }
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    // MARK: - Status cards

    private var loadingCard: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            ProgressView().tint(AppTheme.Colors.accent)
            Text("Loading medication history…")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var emptyCard: some View {
        EmptyStateView(
            icon: "pills",
            title: "No medications logged",
            message: "Tap + to log a dose."
        )
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.riskHigh)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await viewModel.load() } }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.m)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    // MARK: - Day grouping

    /// Groups doses (newest-first) into labelled day buckets.
    private func grouped(_ doses: [MedicationDose]) -> [(String, [MedicationDose])] {
        let calendar = Calendar.current
        let today     = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var result: [(String, [MedicationDose])] = []
        var current: (String, [MedicationDose])? = nil

        for dose in doses {
            let day   = calendar.startOfDay(for: dose.takenAt)
            let label: String
            if day == today           { label = "Today" }
            else if day == yesterday  { label = "Yesterday" }
            else                      { label = dose.takenAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }

            if current?.0 == label {
                current!.1.append(dose)
            } else {
                if let c = current { result.append(c) }
                current = (label, [dose])
            }
        }
        if let c = current { result.append(c) }
        return result
    }
}

// MARK: - DoseRow

private struct DoseRow: View {
    let dose: MedicationDose
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            // Class badge
            Text(dose.medicationClass.shortLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(dose.medicationClass.mohBadgeColor)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medicationName)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(dose.purpose.displayName)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)

                    if let mg = dose.doseMilligrams {
                        Text("·")
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                        Text("\(Int(mg)) mg")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }
            }

            Spacer()

            Text(dose.takenAt.formatted(date: .omitted, time: .shortened))
                .font(AppTheme.Typography.monoNumeric)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.s)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - MedicationClass display helpers

private extension MedicationClass {
    /// Short badge label — keeps the chip compact.
    var shortLabel: String {
        switch self {
        case .triptan:              return "Triptan"
        case .ergot:                return "Ergot"
        case .opioid:               return "Opioid"
        case .combinationAnalgesic: return "Combo"
        case .nsaid:                return "NSAID"
        case .simpleAnalgesic:      return "Analgesic"
        case .cgrpAcute:            return "CGRP"
        case .cgrpPreventive:       return "CGRP prev."
        case .betaBlocker:          return "β-blocker"
        case .anticonvulsant:       return "Anticonv."
        case .antidepressant:       return "Antidepr."
        case .botox:                return "Botox"
        case .other:                return "Other"
        }
    }

    /// Badge colour reflects MOH risk level.
    var mohBadgeColor: Color {
        switch self {
        case .triptan, .ergot, .opioid, .combinationAnalgesic:
            return AppTheme.Colors.riskHigh
        case .nsaid, .simpleAnalgesic:
            return AppTheme.Colors.riskModerate
        default:
            return AppTheme.Colors.secondaryText.opacity(0.8)
        }
    }
}

// MARK: - DosePurpose display

private extension DosePurpose {
    var displayName: String {
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
//        MedicationContentView(
//            viewModel: {
//                let mock = MockMedicationRepository()
//                mock.stubbedDoses = MedicationDose.mockList
//                return MedicationViewModel(medicationRepository: mock)
//            }()
//        )
//    }
//    .preferredColorScheme(.dark)
//}
