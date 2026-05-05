//
//  AppTheme.swift
//  MigraineIQ
//
//  Single source of truth for colours, spacing, and typography. Adjust
//  values here rather than hard-coding hex values across views.
//
//  Palette rationale: dark, low-luminance UI is critical for migraine
//  sufferers — bright screens during photophobia trigger pain. Default
//  colour scheme is dark; we use a deep navy background with a calm violet
//  accent that reads as clinical-trustworthy without being clinical-cold.
//

import SwiftUI

enum AppTheme {

    // MARK: - Colours -----------------------------------------------------

    enum Colors {
        // Backgrounds
        static let background       = Color(hex: "#0D0D1A")  // near-black with blue tint
        static let cardBackground   = Color(hex: "#1A1A2E")
        static let elevatedSurface  = Color(hex: "#262640")

        // Foregrounds
        static let primaryText      = Color(hex: "#F5F5FA")
        static let secondaryText    = Color(hex: "#A0A0B8")
        static let tertiaryText     = Color(hex: "#6B6B85")

        // Brand accent — calm violet
        static let accent           = Color(hex: "#8B7FFF")
        static let accentMuted      = Color(hex: "#6B5FCC")

        // Risk / status semantics
        static let riskLow          = Color(hex: "#4ADE80")  // soft green
        static let riskModerate     = Color(hex: "#FBBF24")  // amber
        static let riskElevated     = Color(hex: "#FB923C")  // orange
        static let riskHigh         = Color(hex: "#F87171")  // soft red (not harsh)

        // MOH guardian semantics
        static let mohSafe          = riskLow
        static let mohApproaching   = riskModerate
        static let mohAtRisk        = riskElevated
        static let mohOveruse       = riskHigh

        // Pain intensity scale (0–10)
        static func intensity(_ level: Int) -> Color {
            switch level {
            case 0...3: return riskLow
            case 4...6: return riskModerate
            case 7...8: return riskElevated
            default:     return riskHigh
            }
        }
    }

    // MARK: - Typography --------------------------------------------------

    enum Typography {
        static let largeTitle  = Font.system(size: 34, weight: .bold,    design: .rounded)
        static let title       = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let headline    = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body        = Font.system(size: 16, weight: .regular,  design: .default)
        static let caption     = Font.system(size: 13, weight: .regular,  design: .default)
        static let monoNumeric = Font.system(size: 16, weight: .medium,   design: .monospaced)
    }

    // MARK: - Spacing -----------------------------------------------------

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let s:   CGFloat = 12
        static let m:   CGFloat = 16
        static let l:   CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner radii -----------------------------------------------

    enum Radius {
        static let card:    CGFloat = 16
        static let pill:    CGFloat = 999
        static let surface: CGFloat = 24
    }
}
