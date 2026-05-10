//
//  LogAttackComplication.swift
//  MigraineIQWatchWidget
//
//  WidgetKit complication that appears on the Apple Watch face.
//  Tapping any family opens the MigraineIQWatch app via the URL scheme
//  "migraineiqwatch://quicklog", which the watch app handles by immediately
//  calling logNow() so the user doesn't need a second tap.
//
//  Supported families
//  ─────────────────────────────────────────────────────────────────────────
//  • .accessoryCircular  — round slot (Infograph, Modular Compact, etc.)
//  • .accessoryCorner    — corner slot (Infograph only); uses widgetLabel
//  • .accessoryRectangular — wide banner (Modular, Infograph Modular, etc.)
//
//  Note: .systemSmall / .systemMedium are phone families and are NOT
//  included here. The phone widget lives in MigraineIQWidget.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline entry (static — no data needed)

struct WatchLogEntry: TimelineEntry {
    let date: Date
}

// MARK: - Provider

struct WatchLogProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchLogEntry {
        WatchLogEntry(date: Date())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (WatchLogEntry) -> Void) {
        completion(WatchLogEntry(date: Date()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<WatchLogEntry>) -> Void) {
        // Static content — never needs reloading.
        completion(Timeline(entries: [WatchLogEntry(date: Date())], policy: .never))
    }
}

// MARK: - Complication view

struct LogAttackComplicationView: View {

    @Environment(\.widgetFamily) private var family

    /// Accent violet — matches AppTheme.Colors.accent (#8B7FFF).
    private let accent = Color(red: 0.545, green: 0.498, blue: 1.0)

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    // Round slot: background disc + brain icon + "Log" label.
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                Text("Log")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // Corner slot: icon in the corner cell + text in the curved label band.
    private var cornerView: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(accent)
            .widgetLabel("Log Attack")
            .containerBackground(.clear, for: .widget)
    }

    // Rectangular banner: icon + two lines of text.
    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Log Attack")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("MigraineIQ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget declaration

struct LogAttackComplication: Widget {

    private let logURL = URL(string: "migraineiqwatch://quicklog")!

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.kieny.migraineiq.watchwidget.logattack",
            provider: WatchLogProvider()
        ) { _ in
            LogAttackComplicationView()
                .widgetURL(logURL)
        }
        .configurationDisplayName("Log Attack")
        .description("Tap to instantly log a migraine attack from your wrist.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular
        ])
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    LogAttackComplication()
} timeline: {
    WatchLogEntry(date: Date())
}
