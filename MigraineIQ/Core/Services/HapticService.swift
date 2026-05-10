//
//  HapticService.swift
//  MigraineIQ
//
//  Thin static wrapper around UIKit's haptic feedback generators.
//  Each call creates a fresh generator to avoid the one-time-fire
//  limitation of pre-prepared generators.
//
//  Usage:
//    HapticService.impact()          // medium impact (default)
//    HapticService.impact(.light)    // light tap
//    HapticService.success()         // confirmed save / completion
//    HapticService.error()           // validation failure / network error
//    HapticService.selection()       // chip toggle, picker change
//

import UIKit

enum HapticService {

    /// Physical impact — good for button taps and major UI transitions.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Three-pulse success pattern — use after a save, log, or purchase completes.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Error double-pulse — use for validation failures, network errors, or
    /// form submission rejections.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Subtle tick — use for chip toggles, segmented control changes,
    /// or any small discrete selection within a screen.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
