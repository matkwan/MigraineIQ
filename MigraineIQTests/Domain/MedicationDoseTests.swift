//
//  MedicationDoseTests.swift
//  MigraineIQTests
//
//  Verifies the MOH thresholds attached to MedicationClass — these drive
//  the MOH Guardian feature and are clinically significant. Wrong values
//  here would mean missed warnings.
//

import Testing
@testable import MigraineIQ

@Suite("MedicationClass MOH thresholds")
struct MedicationDoseTests {

    @Test("triptan triggers MOH at 10 days/month")
    func triptanThreshold() {
        #expect(MedicationClass.triptan.mohThresholdDays == 10)
        #expect(MedicationClass.triptan.isMOHCausing)
    }

    @Test("ergot, opioid, combination analgesic also at 10 days")
    func acuteAt10Days() {
        for klass in [MedicationClass.ergot, .opioid, .combinationAnalgesic] {
            #expect(klass.mohThresholdDays == 10, "\(klass.rawValue) should be 10")
        }
    }

    @Test("NSAIDs and simple analgesics at 15 days")
    func analgesicsAt15Days() {
        #expect(MedicationClass.nsaid.mohThresholdDays == 15)
        #expect(MedicationClass.simpleAnalgesic.mohThresholdDays == 15)
    }

    @Test("CGRP and preventives are not MOH-causing")
    func cgrpAndPreventivesAreSafe() {
        for klass in [MedicationClass.cgrpAcute, .cgrpPreventive, .betaBlocker,
                      .anticonvulsant, .antidepressant, .botox] {
            #expect(klass.mohThresholdDays == nil, "\(klass.rawValue) should be MOH-safe")
            #expect(!klass.isMOHCausing)
        }
    }
}
