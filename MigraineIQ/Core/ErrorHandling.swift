//
//  ErrorHandling.swift
//  MigraineIQ
//
//  App-wide error type and a small helper to convert any error into a
//  user-facing message. Domain Use Cases throw concrete errors; Presentation
//  catches them and renders via this helper so the message style is
//  consistent across the app.
//

import Foundation

/// Top-level error type. Wrap repository / use-case errors with the
/// appropriate case so the UI can decide retry vs. permanent failure.
enum AppError: LocalizedError {
    case dataPersistence(String)
    case network(String)
    case ai(String)
    case healthKitUnavailable
    case healthKitPermissionDenied
    case weatherUnavailable
    case validation(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .dataPersistence(let m):    return "Couldn't save your data: \(m)"
        case .network(let m):            return "Network problem: \(m)"
        case .ai(let m):                 return "AI service error: \(m)"
        case .healthKitUnavailable:      return "HealthKit isn't available on this device."
        case .healthKitPermissionDenied: return "HealthKit access was denied. You can change this in Settings → Health → Data Access & Devices."
        case .weatherUnavailable:        return "Couldn't load weather data right now."
        case .validation(let m):         return m
        case .unknown(let m):            return "Something went wrong: \(m)"
        }
    }
}

/// Convert any error into a user-facing string. Falls back to the raw
/// localized description if the error isn't an `AppError`.
enum ErrorPresenter {
    static func userMessage(for error: Error) -> String {
        if let app = error as? AppError {
            return app.errorDescription ?? "Something went wrong."
        }
        return error.localizedDescription
    }
}
