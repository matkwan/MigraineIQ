//
//  MicButtonView.swift
//  MigraineIQ
//
//  Pro-only animated microphone button rendered inside the Notes section of
//  HeadacheDetailContentView. Shows different visual states:
//
//   • idle              — mic icon, accent tint
//   • requestingPermissions — spinning ProgressView
//   • recording         — stop icon + animated shrink ring + progress arc (0→1 over 58s)
//   • unavailable       — mic.slash icon, muted tint
//

import SwiftUI

struct MicButtonView: View {

    let service: SpeechRecognitionService

    // Pulsing scale for the recording ring
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background progress arc (recording state only)
            if case .recording = service.state {
                Circle()
                    .stroke(AppTheme.Colors.accent.opacity(0.15), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: service.sessionProgress)
                    .stroke(
                        service.sessionProgress > 0.8 ? Color.orange : Color.red,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: service.sessionProgress)

                // Pulse ring
                Circle()
                    .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .scaleEffect(pulseScale)
                    .opacity(2 - pulseScale)   // fades as it expands
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                            pulseScale = 1.4
                        }
                    }
                    .onDisappear { pulseScale = 1.0 }
            }

            // Button face
            buttonFace
                .frame(width: 36, height: 36)
                .background(buttonBackgroundColor)
                .clipShape(Circle())
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
    }

    // MARK: - Internal views

    @ViewBuilder
    private var buttonFace: some View {
        switch service.state {
        case .idle:
            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)

        case .unavailable:
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)

        case .requestingPermissions:
            ProgressView()
                .tint(AppTheme.Colors.accent)
                .scaleEffect(0.8)

        case .recording:
            Image(systemName: "stop.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var buttonBackgroundColor: Color {
        switch service.state {
        case .idle:                return AppTheme.Colors.accent.opacity(0.12)
        case .recording:           return Color.red
        case .requestingPermissions: return AppTheme.Colors.elevatedSurface
        case .unavailable:         return AppTheme.Colors.elevatedSurface
        }
    }
}
