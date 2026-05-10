//
//  AuraMapperView.swift
//  MigraineIQ
//
//  Dedicated mapper pushed from the HeadacheDetail form when the user
//  reports having had aura. Three sections:
//
//   1. Types          — multi-select chips (AuraType.allCases)
//   2. Visual         — icon grid (VisualDisturbance.allCases)
//   3. Sensory body   — tappable overlay on figure.arms.open SF Symbol
//
//  All selections write directly back to HeadacheDetailViewModel via
//  @Bindable — no separate ViewModel needed.
//

import SwiftUI

struct AuraMapperView: View {
    @Bindable var viewModel: HeadacheDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.m) {
                typesSection
                visualSection
                sensorySection
            }
            .padding(AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Aura details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 1. Types

    private var typesSection: some View {
        AuraCard(title: "Aura type", icon: "brain.head.profile") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: AppTheme.Spacing.xs)],
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(AuraType.allCases) { type in
                    SelectableChip(
                        label: type.displayName,
                        isSelected: viewModel.auraTypes.contains(type)
                    ) {
                        viewModel.auraTypes.toggle(type)
                    }
                }
            }
        }
    }

    // MARK: - 2. Visual disturbances

    private var visualSection: some View {
        AuraCard(title: "Visual disturbances", icon: "eye") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: AppTheme.Spacing.xs)],
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(VisualDisturbance.allCases) { disturbance in
                    VisualDisturbanceChip(
                        disturbance: disturbance,
                        isSelected: viewModel.auraVisualDisturbances.contains(disturbance)
                    ) {
                        viewModel.auraVisualDisturbances.toggle(disturbance)
                    }
                }
            }
        }
    }

    // MARK: - 3. Sensory locations (body diagram)

    private var sensorySection: some View {
        AuraCard(title: "Sensory symptoms", icon: "hand.raised") {
            VStack(spacing: AppTheme.Spacing.m) {
                Text("Tap where you felt tingling, numbness, or pins & needles")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                BodyDiagram(selection: $viewModel.auraSensoryLocations)
                    .frame(maxWidth: .infinity)

                // Legend
                if !viewModel.auraSensoryLocations.isEmpty {
                    FlowChips(
                        items: Array(viewModel.auraSensoryLocations)
                            .sorted { $0.displayName < $1.displayName }
                    ) { loc in
                        Text(loc.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .padding(.horizontal, AppTheme.Spacing.xs)
                            .padding(.vertical, AppTheme.Spacing.xxs)
                            .background(AppTheme.Colors.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.top, AppTheme.Spacing.xs)
                }
            }
        }
    }
}

// MARK: - AuraCard

private struct AuraCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .kerning(0.8)
            }
            content()
        }
        .padding(AppTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - SelectableChip

private struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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

// MARK: - VisualDisturbanceChip (icon + label)

private struct VisualDisturbanceChip: View {
    let disturbance: VisualDisturbance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: disturbance.sfSymbol)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryText)
                Text(disturbance.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, AppTheme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - BodyDiagram

private struct BodyDiagram: View {
    @Binding var selection: Set<SensoryLocation>

    /// Fixed canvas — positions below are relative to this.
    private let W: CGFloat = 200
    private let H: CGFloat = 260

    var body: some View {
        ZStack {
            // Base figure
            Image(systemName: "figure.arms.open")
                .font(.system(size: 130))
                .foregroundStyle(AppTheme.Colors.elevatedSurface)

            // Tappable location dots
            ForEach(SensoryLocation.allCases) { loc in
                let pos = position(for: loc)
                let selected = selection.contains(loc)

                Button {
                    selection.toggle(loc)
                } label: {
                    ZStack {
                        Circle()
                            .fill(selected ? AppTheme.Colors.accentMuted : AppTheme.Colors.cardBackground)
                            .frame(width: 28, height: 28)
                        Circle()
                            .stroke(
                                selected ? AppTheme.Colors.accent : AppTheme.Colors.tertiaryText.opacity(0.5),
                                lineWidth: selected ? 2 : 1
                            )
                            .frame(width: 28, height: 28)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .position(pos)
                .accessibilityLabel(loc.displayName)
            }
        }
        .frame(width: W, height: H)
    }

    /// Approximate anatomical positions relative to the W×H canvas.
    private func position(for loc: SensoryLocation) -> CGPoint {
        switch loc {
        case .faceLeft:   return CGPoint(x: W * 0.41, y: H * 0.07)
        case .faceRight:  return CGPoint(x: W * 0.59, y: H * 0.07)
        case .lipsTongue: return CGPoint(x: W * 0.50, y: H * 0.14)
        case .armLeft:    return CGPoint(x: W * 0.08, y: H * 0.33)
        case .armRight:   return CGPoint(x: W * 0.92, y: H * 0.33)
        case .legLeft:    return CGPoint(x: W * 0.38, y: H * 0.86)
        case .legRight:   return CGPoint(x: W * 0.62, y: H * 0.86)
        }
    }
}

// MARK: - FlowChips (selected-item tag row)

private struct FlowChips<T, Content: View>: View {
    let items: [T]
    @ViewBuilder let chip: (T) -> Content

    var body: some View {
        // Horizontal wrapping using fixed-width GeometryReader approach.
        GeometryReader { geo in
            self.build(width: geo.size.width)
        }
        .frame(height: items.count <= 3 ? 28 : 60)
    }

    private func build(width: CGFloat) -> some View {
        var x: CGFloat = 0
        var y: CGFloat = 0
        let spacing: CGFloat = 6
        let chipH: CGFloat = 24

        return ZStack(alignment: .topLeading) {
            ForEach(items.indices, id: \.self) { i in
                chip(items[i])
                    .fixedSize()
                    .alignmentGuide(.leading) { d in
                        if x + d.width > width {
                            x = 0
                            y -= chipH + spacing
                        }
                        let result = x
                        x += d.width + spacing
                        if i == items.count - 1 { x = 0; y = 0 }
                        return -result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = y
                        if i == items.count - 1 { y = 0 }
                        return result
                    }
            }
        }
    }
}

// MARK: - Set toggle helper

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}

// MARK: - VisualDisturbance SF Symbol mapping

private extension VisualDisturbance {
    var sfSymbol: String {
        switch self {
        case .scintillatingScotoma:  return "eye.trianglebadge.exclamationmark"
        case .fortificationSpectrum: return "waveform.path.ecg"
        case .blurredVision:         return "eye.slash"
        case .visualFieldLoss:       return "rectangle.slash"
        case .flashingLights:        return "bolt.fill"
        case .tunnel:                return "scope"
        case .kaleidoscope:          return "sparkles"
        }
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        AuraMapperView(
//            viewModel: HeadacheDetailViewModel(
//                event: {
//                    var e = HeadacheEvent.mockOngoing
//                    e.aura = AuraEvent(
//                        types: [.visual],
//                        visualDisturbances: [.fortificationSpectrum]
//                    )
//                    return e
//                }(),
//                headacheRepository: MockHeadacheRepository()
//            )
//        )
//    }
//    .preferredColorScheme(.dark)
//}
