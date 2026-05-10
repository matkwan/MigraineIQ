//
//  NetworkMonitor.swift
//  MigraineIQ
//
//  Observable singleton that tracks device network reachability via
//  NWPathMonitor. Access `NetworkMonitor.shared.isConnected` from any
//  view or ViewModel — SwiftUI's @Observable tracking re-renders the
//  tree automatically when connectivity changes.
//
//  Usage (view):
//      let monitor = NetworkMonitor.shared
//      // Read monitor.isConnected in body — auto-tracked.
//
//  Usage (ViewModel):
//      guard NetworkMonitor.shared.isConnected else { ... }
//

import Foundation
import Network
import Observation

@Observable
final class NetworkMonitor {

    // MARK: - Shared

    static let shared = NetworkMonitor()

    // MARK: - State

    /// `true` when any usable interface is available (WiFi, Cellular, etc.).
    /// Starts optimistic (`true`) and is updated once the first NWPath
    /// evaluation completes (typically within milliseconds of app launch).
    private(set) var isConnected: Bool = true

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(
        label: "com.migraineiq.networkmonitor",
        qos: .utility
    )

    // MARK: - Init

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            // NWPathMonitor delivers on our private queue — hop to MainActor
            // so @Observable mutations are safe.
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
