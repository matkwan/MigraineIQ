//
//  CyclePhase.swift
//  MigraineIQ
//
//  Menstrual cycle phase used for risk prediction and coaching context.
//  Phase 4 will compute this from HealthKit menstrual flow data;
//  for now it's defined here so AI types can reference it.
//

import Foundation

enum CyclePhase: String, Codable, CaseIterable, Hashable {
    case menstrual   // days 1-5 (approx) — highest estrogen-drop risk
    case follicular  // days 6-13
    case ovulatory   // days 14-15 (approx)
    case luteal      // days 16-28 (approx) — progesterone dominant
    case unknown     // no data or tracking not enabled
}
