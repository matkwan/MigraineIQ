//
//  ReviewService.swift
//  MigraineIQ
//
//  Requests an App Store review at meaningful usage milestones.
//
//  Rules:
//  - Prompts at 3, 10, and 25 logged attacks.
//  - At most once per app version (Apple's own limit is 3× per 365 days,
//    but we further constrain to once per version to avoid annoying users
//    on minor updates).
//  - Call `recordAttackLogged()` from QuickLogViewModel after every
//    successful save. The counter is cumulative and never resets.
//
//  Usage:
//    ReviewService.shared.recordAttackLogged()
//

import Foundation
import StoreKit
import UIKit

final class ReviewService {

    // MARK: - Singleton

    static let shared = ReviewService()
    private init() {}

    // MARK: - Milestones

    private static let milestones: Set<Int> = [3, 10, 25]

    // MARK: - UserDefaults keys

    private enum Key {
        static let totalAttacks       = "review.totalAttacksLogged"
        static let lastVersionReviewed = "review.lastVersionReviewed"
    }

    // MARK: - Persisted counters

    private var totalAttacks: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalAttacks) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalAttacks) }
    }

    private var lastVersionReviewed: String {
        get { UserDefaults.standard.string(forKey: Key.lastVersionReviewed) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.lastVersionReviewed) }
    }

    // MARK: - Public API

    /// Increments the cumulative attack count and requests a review if
    /// the count has crossed a milestone for the first time this version.
    func recordAttackLogged() {
        totalAttacks += 1
        requestReviewIfEligible()
    }

    // MARK: - Private

    private func requestReviewIfEligible() {
        let count   = totalAttacks
        let version = currentAppVersion

        guard Self.milestones.contains(count) else { return }
        guard lastVersionReviewed != version  else { return }

        lastVersionReviewed = version

        Task { @MainActor in
            guard
                let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive })
                    as? UIWindowScene
            else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
