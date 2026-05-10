//
//  LogAttackWatchView.swift
//  MigraineIQWatch
//
//  The single-screen Watch app UI. Shows a large tap target; on tap it
//  sends a WatchConnectivity message to the iPhone and displays a brief
//  confirmation before resetting.
//
//  Photophobia constraints (same as the phone quick-log):
//  • Pure black background.
//  • Accent: the app's violet (#8B7FFF ≈ rgb 0.545, 0.498, 1.0).
//  • No looping animations. The ProgressView on sending is the only motion.
//  • State auto-resets after 2.5 s (see WatchLogModel.scheduleReset).
//

import SwiftUI

struct LogAttackWatchView: View {

    var model: WatchLogModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            stateView
        }
        .animation(.easeInOut(duration: 0.2), value: model.state)
    }

    // MARK: - State views

    @ViewBuilder
    private var stateView: some View {
        switch model.state {
        case .ready:
            readyView
        case .sending:
            sendingView
        case .saved:
            savedView
        case .error(let hint):
            errorView(hint: hint)
        }
    }

    // Large tap target — the whole screen is the button.
    private var readyView: some View {
        Button {
            model.logNow()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color(red: 0.545, green: 0.498, blue: 1.0))
                Text("Log Attack")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sendingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text("Saving…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var savedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.green)
            Text("Logged")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func errorView(hint: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.orange)
            Text(hint)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }
}

// MARK: - Preview

#Preview {
    LogAttackWatchView(model: WatchLogModel())
}
