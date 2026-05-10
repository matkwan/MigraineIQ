//
//  MigraineIQWatchApp.swift
//  MigraineIQWatch
//
//  Watch App entry point. Presents LogAttackWatchView as the single scene.
//
//  Deep-link note
//  ─────────────────────────────────────────────────────────────────────────
//  The Watch complication (LogAttackComplication) sets a widgetURL of
//  "migraineiqwatch://quicklog". Tapping the complication opens this app
//  and fires onOpenURL below, which triggers an immediate logNow() on the
//  shared WatchLogModel so the user doesn't have to tap a second time.
//

import SwiftUI

@main
struct MigraineIQWatchApp: App {

    @State private var model = WatchLogModel()

    var body: some Scene {
        WindowGroup {
            LogAttackWatchView(model: model)
                // Complication tap → immediate log without an extra button press.
                .onOpenURL { url in
                    guard url.scheme == "migraineiqwatch",
                          url.host == "quicklog" else { return }
                    model.logNow()
                }
        }
    }
}
