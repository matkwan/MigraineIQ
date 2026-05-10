//
//  PredictionContext.swift
//  MigraineIQ
//
//  Input bundle for PredictMigraineRiskUseCase. Composes the user's
//  personalised trigger model, their recent attack history, and the
//  current contextual health signals into a single value that can
//  be serialised and sent to the AI proxy's /v1/predict endpoint.
//

import Foundation

struct PredictionContext: Codable, Hashable {
    /// The user's current personalised trigger list (from last trigger recompute).
    var knownTriggers: [TriggerInsight]
    /// Recent attacks — typically the last 7–14 days.
    var recentAttacks: [HeadacheEvent]
    /// Current health / environment snapshot.
    var currentContext: HealthContext

    init(
        knownTriggers: [TriggerInsight] = [],
        recentAttacks: [HeadacheEvent] = [],
        currentContext: HealthContext = .empty
    ) {
        self.knownTriggers = knownTriggers
        self.recentAttacks = recentAttacks
        self.currentContext = currentContext
    }
}
