//
//  LogAttackWidget.swift
//  MigraineIQWidget
//
//  Lock-screen and Home-screen widget. Tapping any family opens the app
//  via "migraineiq://quicklog", which auto-fires QuickLog on the Log tab.
//
//  Supported families
//  ─────────────────────────────────────────────────────────────────────────
//  • .accessoryCircular    — Lock Screen round slot
//  • .accessoryRectangular — Lock Screen banner slot
//  • .systemSmall          — Home Screen small square
//

import WidgetKit
import SwiftUI

// MARK: - Timeline entry (static — no live data needed)

struct LogAttackEntry: TimelineEntry {
    let date: Date
}

// MARK: - Provider

struct LogAttackProvider: TimelineProvider {

    func placeholder(in context: Context) -> LogAttackEntry {
        LogAttackEntry(date: Date())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (LogAttackEntry) -> Void) {
        completion(LogAttackEntry(date: Date()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<LogAttackEntry>) -> Void) {
        // Static content — never needs updating.
        completion(Timeline(entries: [LogAttackEntry(date: Date())], policy: .never))
    }
}

// MARK: - Widget view

struct LogAttackWidgetView: View {

    @Environment(\.widgetFamily) private var family

    /// Accent violet — AppTheme.Colors.accent #8B7FFF.
    private let accent = Color(red: 0.545, green: 0.498, blue: 1.0)
    /// Near-black background — AppTheme.Colors.background #0D0D1A.
    private let background = Color(red: 0.051, green: 0.051, blue: 0.102)

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .systemSmall:
            smallView
        default:
            smallView
        }
    }

    // MARK: Lock Screen — round

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text("Log")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // MARK: Lock Screen — rectangular banner

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
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

    // MARK: Home Screen — small square

    private var smallView: some View {
        VStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(accent)
            Text("Log Attack")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("MigraineIQ")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(background, for: .widget)
    }
}

// MARK: - Widget declaration

struct LogAttackWidget: Widget {

    private let logURL = URL(string: "migraineiq://quicklog")!

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.kieny.migraineiq.widget.logattack",
            provider: LogAttackProvider()
        ) { _ in
            LogAttackWidgetView()
                .widgetURL(logURL)
        }
        .configurationDisplayName("Log Attack")
        .description("One tap to log a migraine attack.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall
        ])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    LogAttackWidget()
} timeline: {
    LogAttackEntry(date: Date())
}
