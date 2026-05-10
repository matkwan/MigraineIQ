//
//  HeadacheDetailContentView.swift
//  MigraineIQ
//
//  Full editing form for a HeadacheEvent. Pushed from QuickLog's
//  "Edit details" link. Dismisses back on successful save.
//
//  Sections (in order):
//   1. Intensity   — NRS slider 0–10, colour-coded
//   2. Type        — ICHD-3 classification picker
//   3. Pain location — multi-select chips
//   4. Pain quality  — multi-select chips
//   5. Symptoms      — multi-select chips
//   6. Aura          — toggle; when ON reveals aura-type chips + duration
//                      (Ticket 3.3 adds the full visual / sensory mapper)
//   7. Triggers      — free-text, comma-separated
//   8. Notes         — TextEditor
//   9. Disability    — three hour steppers
//  10. Accept button
//

import SwiftUI

struct HeadacheDetailContentView: View {
    @Bindable var viewModel: HeadacheDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.m) {
                copyFromLastCard
                intensitySection
                typeSection
                painLocationSection
                painQualitySection
                symptomsSection
                auraSection
                triggersSection
                notesSection
                disabilitySection
                actionSection
            }
            .padding(AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Edit attack")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .task { await viewModel.loadLastAttack() }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { viewModel.save() }
                    .disabled(viewModel.saveState == .saving)
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .confirmationDialog(
            "Delete this attack?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { viewModel.delete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the attack from your history. This cannot be undone.")
        }
        .onChange(of: viewModel.saveState) { _, newState in
            if case .saved    = newState { dismiss() }
            if case .deleted  = newState { dismiss() }
        }
    }

    // MARK: - Copy from last attack

    @ViewBuilder
    private var copyFromLastCard: some View {
        if let last = viewModel.lastAttack {
            HStack(spacing: AppTheme.Spacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST ATTACK")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .kerning(0.6)

                    HStack(spacing: 6) {
                        Text(last.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text("·")
                            .foregroundStyle(AppTheme.Colors.tertiaryText)

                        Text("Intensity \(last.intensity)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text("·")
                            .foregroundStyle(AppTheme.Colors.tertiaryText)

                        Text(last.classification.displayName)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button("Copy") {
                    viewModel.copyFromLastAttack()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .padding(.horizontal, AppTheme.Spacing.s)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            }
            .padding(AppTheme.Spacing.m)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(AppTheme.Colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - 1. Intensity

    private var intensitySection: some View {
        FormCard(title: "Pain intensity") {
            VStack(spacing: AppTheme.Spacing.s) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(viewModel.intensity)")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.Colors.intensity(viewModel.intensity))
                        .contentTransition(.numericText())
                    Text("/ 10")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                    Spacer()
                    Text(intensityLabel(viewModel.intensity))
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.intensity) },
                        set: { viewModel.intensity = Int($0) }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(AppTheme.Colors.intensity(viewModel.intensity))
            }
        }
    }

    private func intensityLabel(_ n: Int) -> String {
        switch n {
        case 0:     return "No pain"
        case 1...3: return "Mild"
        case 4...6: return "Moderate"
        case 7...9: return "Severe"
        default:    return "Worst possible"
        }
    }

    // MARK: - 2. Type

    private var typeSection: some View {
        FormCard(title: "Type") {
            Picker("Classification", selection: $viewModel.classification) {
                ForEach(ICHD3Classification.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. Pain location

    private var painLocationSection: some View {
        FormCard(title: "Pain location") {
            ChipGrid(
                items: PainLocation.allCases,
                label: \.displayName,
                isSelected: { viewModel.painLocations.contains($0) },
                onTap: { loc in
                    if viewModel.painLocations.contains(loc) {
                        viewModel.painLocations.remove(loc)
                    } else {
                        viewModel.painLocations.insert(loc)
                    }
                }
            )
        }
    }

    // MARK: - 4. Pain quality

    private var painQualitySection: some View {
        FormCard(title: "Pain quality") {
            ChipGrid(
                items: PainQuality.allCases,
                label: \.displayName,
                isSelected: { viewModel.painQuality.contains($0) },
                onTap: { q in
                    if viewModel.painQuality.contains(q) {
                        viewModel.painQuality.remove(q)
                    } else {
                        viewModel.painQuality.insert(q)
                    }
                }
            )
        }
    }

    // MARK: - 5. Symptoms

    private var symptomsSection: some View {
        FormCard(title: "Symptoms") {
            ChipGrid(
                items: Symptom.allCases,
                label: \.displayName,
                isSelected: { viewModel.symptoms.contains($0) },
                onTap: { s in
                    if viewModel.symptoms.contains(s) {
                        viewModel.symptoms.remove(s)
                    } else {
                        viewModel.symptoms.insert(s)
                    }
                }
            )
        }
    }

    // MARK: - 6. Aura

    private var auraSection: some View {
        FormCard(title: "Aura") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                Toggle("Had aura before this attack", isOn: $viewModel.hasAura)
                    .tint(AppTheme.Colors.accent)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                if viewModel.hasAura {
                    Divider().background(AppTheme.Colors.elevatedSurface)

                    // Duration stays on the main form; types/visual/sensory live in AuraMapperView.
                    HStack {
                        Text("Duration")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Spacer()
                        Stepper(
                            value: $viewModel.auraDurationMinutes,
                            in: 0...180,
                            step: 5
                        ) {
                            Text(viewModel.auraDurationMinutes == 0
                                 ? "Not recorded"
                                 : "\(viewModel.auraDurationMinutes) min")
                                .font(AppTheme.Typography.monoNumeric)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .tint(AppTheme.Colors.accent)
                    }

                    Divider().background(AppTheme.Colors.elevatedSurface)

                    NavigationLink {
                        AuraMapperView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("Types, visual & sensory details")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.primaryText)
                            Spacer()
                            if viewModel.auraHasDetails {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.riskLow)
                            }
                            Image(systemName: "chevron.right")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 7. Triggers

    private var triggersSection: some View {
        FormCard(title: "Suspected triggers") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                TextField(
                    "e.g. red wine, poor sleep, stress",
                    text: $viewModel.triggerText
                )
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .tint(AppTheme.Colors.accent)
                .autocorrectionDisabled()

                if !viewModel.parsedTriggers.isEmpty {
                    FlowRow(items: Array(viewModel.parsedTriggers).sorted()) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .padding(.horizontal, AppTheme.Spacing.xs)
                            .padding(.vertical, AppTheme.Spacing.xxs)
                            .background(AppTheme.Colors.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text("Separate multiple triggers with commas")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)

                // Suggestion chips — frequently used triggers from past attacks
                // that haven't already been entered in this session.
                if !viewModel.availableSuggestions.isEmpty {
                    Divider()
                        .background(AppTheme.Colors.elevatedSurface)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("FROM PAST ATTACKS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .kerning(0.6)

                        FlowRow(items: viewModel.availableSuggestions) { suggestion in
                            Button {
                                viewModel.addSuggestion(suggestion)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(suggestion)
                                        .font(.system(size: 12, weight: .medium))
                                }
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
        .task { await viewModel.loadSuggestions() }
    }

    // MARK: - 8. Notes

    private var notesSection: some View {
        FormCard(title: "Notes") {
            ZStack(alignment: .topLeading) {
                if viewModel.notes.isEmpty {
                    Text("Anything else worth recording…")
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
                    .frame(minHeight: 88)
            }
        }
    }

    // MARK: - 9. Disability impact

    private var disabilitySection: some View {
        FormCard(title: "Disability impact") {
            VStack(spacing: AppTheme.Spacing.s) {
                HourStepperRow(
                    label: "Missed work / school",
                    hours: $viewModel.missedWorkHours
                )
                Divider().background(AppTheme.Colors.elevatedSurface)
                HourStepperRow(
                    label: "Reduced productivity",
                    hours: $viewModel.reducedProductivityHours
                )
                Divider().background(AppTheme.Colors.elevatedSurface)
                HourStepperRow(
                    label: "Bed rest",
                    hours: $viewModel.bedRestHours
                )
            }
        }
    }

    // MARK: - 10. Action

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Button {
                viewModel.save()
            } label: {
                Group {
                    if viewModel.saveState == .saving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Accept")
                    }
                }
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(AppTheme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            }
            .disabled(viewModel.saveState == .saving)

            if case .failure(let message) = viewModel.saveState {
                Text(message)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.riskHigh)
                    .multilineTextAlignment(.center)
                    .onTapGesture { viewModel.clearSaveError() }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete Attack")
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

// MARK: - FormCard

private struct FormCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .kerning(0.8)

            content()
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - ChipGrid

private struct ChipGrid<T: Hashable>: View {
    let items: [T]
    let label: (T) -> String
    let isSelected: (T) -> Bool
    let onTap: (T) -> Void

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: AppTheme.Spacing.xs)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.xs) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(label(item))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            isSelected(item) ? .white : AppTheme.Colors.secondaryText
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, AppTheme.Spacing.s)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected(item)
                                ? AppTheme.Colors.accentMuted
                                : AppTheme.Colors.elevatedSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                                .stroke(
                                    isSelected(item)
                                        ? Color.clear
                                        : AppTheme.Colors.tertiaryText.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - HourStepperRow

private struct HourStepperRow: View {
    let label: String
    @Binding var hours: Double

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Spacer()
            Stepper(
                value: $hours,
                in: 0...24,
                step: 0.5
            ) {
                Text(hours == 0 ? "None" : "\(hoursFormatted) h")
                    .font(AppTheme.Typography.monoNumeric)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(minWidth: 56, alignment: .trailing)
            }
            .tint(AppTheme.Colors.accent)
        }
    }

    private var hoursFormatted: String {
        hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", hours)
            : String(format: "%.1f", hours)
    }
}

// MARK: - FlowRow (trigger tags)

private struct FlowRow<T, Content: View>: View {
    let items: [T]
    @ViewBuilder let rowContent: (T) -> Content

    var body: some View {
        // Simple left-to-right wrap using a fixed-width layout trick.
        // Replace with Layout API (iOS 16+) if exact wrapping is needed.
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: flowHeight)
    }

    // Compute approximate height for up to 2 rows of tags.
    private var flowHeight: CGFloat {
        items.isEmpty ? 0 : (items.count <= 4 ? 28 : 60)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                rowContent(item)
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item as AnyObject === items.last as AnyObject {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item as AnyObject === items.last as AnyObject {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        HeadacheDetailContentView(
//            viewModel: HeadacheDetailViewModel(
//                event: .mockOngoing,
//                headacheRepository: MockHeadacheRepository()
//            )
//        )
//    }
//    .preferredColorScheme(.dark)
//}
