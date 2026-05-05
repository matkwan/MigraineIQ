//
//  Color+Hex.swift
//  MigraineIQ
//
//  Hex initialiser for SwiftUI.Color so the AppTheme palette stays readable.
//

import SwiftUI

extension Color {
    /// Initialise a Color from a hex string. Accepts "#RRGGBB", "RRGGBB",
    /// "#RRGGBBAA" or "RRGGBBAA". Falls back to .clear on invalid input.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            self = .clear
            return
        }

        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
