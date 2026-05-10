//
//  AppDelegate.swift
//  MigraineIQ
//
//  UIKit application delegate used exclusively for lifecycle hooks that
//  SwiftUI doesn't provide a reliable equivalent for.
//
//  BGTaskScheduler requirement
//  ─────────────────────────────────────────────────────────────────────────
//  BGTaskScheduler.register(forTaskWithIdentifier:using:launchHandler:) MUST
//  be called before applicationDidFinishLaunching returns. In a pure SwiftUI
//  App struct, @State default values are evaluated before App.init() body
//  runs, so DependencyContainer() (which configures the coordinator) can
//  execute before any App.init() code. Using UIApplicationDelegate here
//  guarantees registration happens at the correct, earliest lifecycle point.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskCoordinator.registerHandler()
        // WatchSessionReceiver is activated inside DependencyContainer.init()
        // (after the repository is injected) to guarantee ordering.
        return true
    }
}
