//
//  DoctorReportPDFRenderer.swift
//  MigraineIQ
//
//  Renders a DoctorReport to a PDF file using PDFKit + UIGraphicsPDFRenderer.
//  Returns a file URL in the app's temporary directory.
//
//  Page layout (US Letter, 612 × 792 pts, 40pt margin)
//  ─────────────────────────────────────────────────────────────────────────
//  1. Header band — MigraineIQ branding + report title + period
//  2. Patient & metadata row
//  3. Summary statistics (4 stat cards)
//  4. MIDAS Disability Score section
//  5. HIT-6 Headache Impact section
//  6. MOH Risk section
//  7. Attack log table (paginated)
//  8. Medication log table (paginated)
//  9. Disclaimer footer on last page
//

import UIKit
import PDFKit

final class DoctorReportPDFRenderer {

    // MARK: - Layout constants

    private let pageW:    CGFloat = 612
    private let pageH:    CGFloat = 792
    private let margin:   CGFloat = 40
    private var contentW: CGFloat { pageW - margin * 2 }

    // MARK: - Colours

    private let navyColor    = UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1)
    private let accentColor  = UIColor(red: 0.54, green: 0.50, blue: 1.00, alpha: 1)
    private let bodyColor    = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
    private let subColor     = UIColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)
    private let ruleColor    = UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1)
    private let greenColor   = UIColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1)
    private let amberColor   = UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
    private let orangeColor  = UIColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1)
    private let redColor     = UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1)

    // MARK: - Public API

    /// Renders the report and returns a file URL in the temp directory.
    func render(report: DoctorReport) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = pdfRenderer.pdfData { ctx in
            // Mutable Y cursor; shared across all drawing calls.
            var y: CGFloat = 0

            // ── Page 1 ──────────────────────────────────────────────────
            ctx.beginPage()
            y = drawHeader(report: report, in: ctx)
            y = drawPatientRow(report: report, y: y)
            y = drawSummaryCards(report: report, y: y)
            y = drawSectionHeader("MIDAS Disability Score", y: y, ctx: ctx)
            y = drawMIDAS(report.midasScore, y: y, ctx: ctx)
            y = drawSectionHeader("HIT-6 Headache Impact Test", y: y, ctx: ctx)
            y = drawHIT6(report.hit6Score, y: y, ctx: ctx)
            y = drawSectionHeader("Medication Overuse Risk (MOH)", y: y, ctx: ctx)
            y = drawMOH(report.mohRisk, y: y, ctx: ctx)

            // ── Attack log (may paginate) ────────────────────────────────
            y = drawSectionHeader("Attack Log (90-Day Period)", y: y, ctx: ctx)
            y = drawAttackTable(report.events, y: y, ctx: ctx)

            // ── Medication log (may paginate) ────────────────────────────
            y = drawSectionHeader("Medication Log (90-Day Period)", y: y, ctx: ctx)
            y = drawMedicationTable(report.doses, y: y, ctx: ctx)

            // ── Disclaimer footer on current page ────────────────────────
            drawDisclaimer(y: y, report: report)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MigraineIQ_Report_\(reportDateStamp(report.generatedAt)).pdf")
        try data.write(to: url)
        return url
    }

    // MARK: - Header

    private func drawHeader(report: DoctorReport, in ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        let headerH: CGFloat = 80
        navyColor.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: headerH)).fill()

        // App name
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        "MigraineIQ".draw(at: CGPoint(x: margin, y: 16), withAttributes: titleAttr)

        // Report subtitle
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.75)
        ]
        "Clinical Headache Report — 90-Day Summary".draw(at: CGPoint(x: margin, y: 43), withAttributes: subAttr)

        // Generated date (right-aligned)
        let dateStr = "Generated: \(formatDate(report.generatedAt, style: .medium))"
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.75)
        ]
        let dateSize = (dateStr as NSString).size(withAttributes: dateAttr)
        (dateStr as NSString).draw(
            at: CGPoint(x: pageW - margin - dateSize.width, y: 20),
            withAttributes: dateAttr
        )

        // Period
        let period = "\(formatDate(report.periodStart, style: .medium)) – \(formatDate(report.periodEnd, style: .medium))"
        let periodSize = (period as NSString).size(withAttributes: dateAttr)
        (period as NSString).draw(
            at: CGPoint(x: pageW - margin - periodSize.width, y: 37),
            withAttributes: dateAttr
        )

        return headerH + 12
    }

    // MARK: - Patient row

    private func drawPatientRow(report: DoctorReport, y: CGFloat) -> CGFloat {
        let labelAttr = captionAttr(color: subColor)
        let valueAttr = bodyAttr(size: 11)
        let col: CGFloat = 180

        "PATIENT ID".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttr)
        report.patientID.draw(at: CGPoint(x: margin + col, y: y), withAttributes: valueAttr)

        let dateLabel = "REPORT DATE"
        let dateValue = formatDate(report.generatedAt, style: .long)
        dateLabel.draw(at: CGPoint(x: margin + contentW / 2, y: y), withAttributes: labelAttr)
        dateValue.draw(at: CGPoint(x: margin + contentW / 2 + col - 100, y: y), withAttributes: valueAttr)

        let nextY = y + 20
        drawRule(y: nextY)
        return nextY + 12
    }

    // MARK: - Summary stat cards

    private func drawSummaryCards(report: DoctorReport, y: CGFloat) -> CGFloat {
        let cards: [(String, String, UIColor)] = [
            ("Total Attacks",      "\(report.totalAttacks)",                        accentColor),
            ("Migraine Days",      "\(report.migraineDaysInPeriod)",                 report.meetsChronicMigraineCriteria ? redColor : amberColor),
            ("Avg. Intensity",     String(format: "%.1f / 10", report.averageIntensity), bodyColor),
            ("Headache Days",      "\(report.totalHeadacheDays)",                   bodyColor),
        ]

        let cardW  = (contentW - 12 * 3) / 4
        let cardH: CGFloat = 52
        let cornerR: CGFloat = 6

        for (i, (label, value, valueColor)) in cards.enumerated() {
            let x = margin + CGFloat(i) * (cardW + 12)
            // Card border
            ruleColor.setStroke()
            let path = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: cardW, height: cardH),
                                    cornerRadius: cornerR)
            path.lineWidth = 1
            path.stroke()

            // Value
            let valAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: valueColor
            ]
            value.draw(at: CGPoint(x: x + 10, y: y + 8), withAttributes: valAttr)

            // Label
            label.draw(at: CGPoint(x: x + 10, y: y + 33), withAttributes: captionAttr(color: subColor))
        }

        // Chronic migraine flag
        var nextY = y + cardH + 8
        if report.meetsChronicMigraineCriteria {
            let flagAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: redColor
            ]
            "⚠ Headache days meet the ICHD-3 chronic migraine threshold (≥45 days / 90-day period). Discuss with your neurologist."
                .draw(at: CGPoint(x: margin, y: nextY), withAttributes: flagAttr)
            nextY += 16
        }

        drawRule(y: nextY + 4)
        return nextY + 16
    }

    // MARK: - MIDAS section

    private func drawMIDAS(_ score: MIDASScore, y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = checkPageBreak(y: y, neededHeight: 90, ctx: ctx)

        // Grade badge
        let gradeColor = midasGradeColor(score.grade)
        let badge = "Grade \(midasGradeLetter(score.grade))  \(score.grade.displayName)  —  Score: \(score.totalScore)"
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: gradeColor
        ]
        badge.draw(at: CGPoint(x: margin, y: y), withAttributes: badgeAttr)
        y += 20

        // Domain breakdown (two-column label/value table)
        let rows: [(String, String)] = [
            ("Q1 — Days missed from work / school",              "\(score.missedWorkDays)"),
            ("Q2 — Days work / school productivity reduced ≥ ½", "\(score.reducedProductivityDays)"),
            ("Q3 — Days missed from household work",             "\(score.missedHouseholdDays)"),
            ("Q4 — Days household productivity reduced ≥ ½",    "\(score.reducedHouseholdDays)"),
            ("Q5 — Days missed social / family activities",      "\(score.missedSocialDays)"),
        ]
        for (label, value) in rows {
            label.draw(at: CGPoint(x: margin + 10, y: y), withAttributes: bodyAttr(size: 10))
            value.draw(at: CGPoint(x: margin + contentW - 20, y: y), withAttributes: bodyAttr(size: 10))
            y += 14
        }

        let note = "Scores derived from logged attack data (90-day window, \(score.attacksInWindow) attacks). Estimated — not from self-report questionnaire."
        note.draw(at: CGPoint(x: margin, y: y + 4), withAttributes: captionAttr(color: subColor))
        return y + 20
    }

    // MARK: - HIT-6 section

    private func drawHIT6(_ score: HIT6Score, y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = checkPageBreak(y: y, neededHeight: 110, ctx: ctx)

        let impactColor = hit6ImpactColor(score.impact)
        let badge = "\(score.impact.displayName)  —  Score: \(score.totalScore) / 78"
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: impactColor
        ]
        badge.draw(at: CGPoint(x: margin, y: y), withAttributes: badgeAttr)
        y += 20

        let items = score.itemScores
        let rows: [(String, Int)] = [
            ("Q1 — Pain severe enough to limit activities",    items.painSeverity),
            ("Q2 — Headaches limited usual daily activities",  items.dailyLimitation),
            ("Q3 — Wanted to lie down because of headaches",   items.wantedToLieDown),
            ("Q4 — Felt too tired to do work",                 items.fatigue),
            ("Q5 — Felt fed up or irritated",                  items.fedUp),
            ("Q6 — Difficulty concentrating",                  items.concentration),
        ]
        for (label, val) in rows {
            label.draw(at: CGPoint(x: margin + 10, y: y), withAttributes: bodyAttr(size: 10))
            let freq = hit6FrequencyLabel(val)
            "\(freq) (\(val))".draw(at: CGPoint(x: margin + contentW - 80, y: y),
                                     withAttributes: captionAttr(color: subColor))
            y += 14
        }

        let note = "Estimated from 28-day logged data (\(score.attacksInWindow) attacks). Score range: 36–78."
        note.draw(at: CGPoint(x: margin, y: y + 4), withAttributes: captionAttr(color: subColor))
        return y + 20
    }

    // MARK: - MOH section

    private func drawMOH(_ moh: MOHRiskAssessment, y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = checkPageBreak(y: y, neededHeight: 70, ctx: ctx)

        let levelColor = mohLevelColor(moh.level)
        let badge = "MOH Risk: \(moh.level.rawValue.capitalized)"
        let badgeAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: levelColor
        ]
        badge.draw(at: CGPoint(x: margin, y: y), withAttributes: badgeAttr)
        y += 18

        let rows: [(String, String)] = [
            ("Triptan days this month",          "\(moh.triptanDaysThisMonth) / 10 threshold"),
            ("NSAID / analgesic days this month", "\(moh.nsaidDaysThisMonth) / 15 threshold"),
            ("Combined acute days",              "\(moh.combinedAcuteDaysThisMonth)"),
        ]
        for (label, value) in rows {
            label.draw(at: CGPoint(x: margin + 10, y: y), withAttributes: bodyAttr(size: 10))
            value.draw(at: CGPoint(x: margin + contentW - 100, y: y), withAttributes: bodyAttr(size: 10))
            y += 14
        }

        moh.explanation.draw(
            in: CGRect(x: margin, y: y + 4, width: contentW, height: 28),
            withAttributes: captionAttr(color: subColor)
        )
        return y + 36
    }

    // MARK: - Attack table

    private func drawAttackTable(_ events: [HeadacheEvent], y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = y
        let cols: [CGFloat] = [margin, margin + 70, margin + 155, margin + 205, margin + 270, margin + contentW]
        let headers = ["Date", "Type", "Int.", "Duration", "Symptoms", ""]

        y = drawTableHeader(cols: cols, headers: headers, y: y)

        if events.isEmpty {
            "No attacks logged in this period.".draw(
                at: CGPoint(x: margin + 10, y: y + 4),
                withAttributes: captionAttr(color: subColor)
            )
            return y + 24
        }

        for event in events {
            let rowH: CGFloat = 16
            y = checkPageBreak(y: y, neededHeight: rowH, ctx: ctx)

            let dateStr = formatDate(event.startedAt, style: .short)
            let typeStr = event.classification.displayName
            let intStr  = "\(event.intensity)"
            let durStr  = event.durationHours.map { String(format: "%.0fh", $0) } ?? "Ongoing"
            let sympStr = event.symptoms.prefix(2).map(\.displayName).joined(separator: ", ")

            let row: [(String, CGFloat)] = [
                (dateStr, cols[0] + 4),
                (typeStr, cols[1] + 4),
                (intStr,  cols[2] + 4),
                (durStr,  cols[3] + 4),
                (sympStr, cols[4] + 4),
            ]
            for (text, x) in row {
                text.draw(at: CGPoint(x: x, y: y + 2), withAttributes: bodyAttr(size: 9))
            }

            ruleColor.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y + rowH))
            path.addLine(to: CGPoint(x: margin + contentW, y: y + rowH))
            path.lineWidth = 0.5
            path.stroke()

            y += rowH
        }
        return y + 8
    }

    // MARK: - Medication table

    private func drawMedicationTable(_ doses: [MedicationDose], y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = y
        let cols: [CGFloat] = [margin, margin + 75, margin + 215, margin + 295, margin + contentW]
        let headers = ["Date", "Medication", "Class", "Purpose", ""]

        y = drawTableHeader(cols: cols, headers: headers, y: y)

        if doses.isEmpty {
            "No medications logged in this period.".draw(
                at: CGPoint(x: margin + 10, y: y + 4),
                withAttributes: captionAttr(color: subColor)
            )
            return y + 24
        }

        for dose in doses {
            let rowH: CGFloat = 16
            y = checkPageBreak(y: y, neededHeight: rowH, ctx: ctx)

            let dateStr  = formatDate(dose.takenAt, style: .short)
            let nameStr  = dose.medicationName
            let classStr = dose.medicationClass.displayName
            let purposeStr = dose.purpose.rawValue.capitalized

            let row: [(String, CGFloat)] = [
                (dateStr,    cols[0] + 4),
                (nameStr,    cols[1] + 4),
                (classStr,   cols[2] + 4),
                (purposeStr, cols[3] + 4),
            ]
            for (text, x) in row {
                text.draw(at: CGPoint(x: x, y: y + 2), withAttributes: bodyAttr(size: 9))
            }

            ruleColor.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y + rowH))
            path.addLine(to: CGPoint(x: margin + contentW, y: y + rowH))
            path.lineWidth = 0.5
            path.stroke()

            y += rowH
        }
        return y + 8
    }

    // MARK: - Disclaimer

    private func drawDisclaimer(y: CGFloat, report: DoctorReport) {
        var y = y + 12
        drawRule(y: y)
        y += 8
        let text = "DISCLAIMER — This report was generated by MigraineIQ and is intended to support — not replace — clinical assessment. MIDAS and HIT-6 scores are estimates derived from self-reported logged data, not from validated self-administered questionnaires. Clinicians should verify scores directly with the patient. Patient identifier \(report.patientID) is a device-local anonymised ID and is not linked to any personal information."
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: subColor
        ]
        text.draw(in: CGRect(x: margin, y: y, width: contentW, height: 40), withAttributes: attr)
    }

    // MARK: - Shared drawing helpers

    private func drawSectionHeader(_ title: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = checkPageBreak(y: y, neededHeight: 28, ctx: ctx)
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: bodyColor
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attr)
        y += 16
        drawRule(y: y)
        return y + 8
    }

    private func drawTableHeader(cols: [CGFloat], headers: [String], y: CGFloat) -> CGFloat {
        // Header band
        UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: contentW, height: 16)).fill()

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: bodyColor
        ]
        for (i, header) in headers.enumerated() {
            guard i < cols.count else { break }
            header.draw(at: CGPoint(x: cols[i] + 4, y: y + 3), withAttributes: attr)
        }
        return y + 16
    }

    private func drawRule(y: CGFloat) {
        ruleColor.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + contentW, y: y))
        path.lineWidth = 0.5
        path.stroke()
    }

    /// If `neededHeight` won't fit on the current page, starts a new page
    /// and resets y to the top margin.
    private func checkPageBreak(y: CGFloat, neededHeight: CGFloat,
                                 ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        let bottomMargin: CGFloat = 60  // leave room for page footer
        if y + neededHeight > pageH - bottomMargin {
            ctx.beginPage()
            return margin
        }
        return y
    }

    // MARK: - Text attribute helpers

    private func bodyAttr(size: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: size, weight: .regular),
         .foregroundColor: bodyColor]
    }

    private func captionAttr(color: UIColor) -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 9, weight: .regular),
         .foregroundColor: color]
    }

    // MARK: - Clinical colour helpers

    private func midasGradeColor(_ grade: MIDASScore.Grade) -> UIColor {
        switch grade {
        case .littleOrNone: return greenColor
        case .mild:         return amberColor
        case .moderate:     return orangeColor
        case .severe:       return redColor
        }
    }

    private func midasGradeLetter(_ grade: MIDASScore.Grade) -> String {
        switch grade {
        case .littleOrNone: return "I"
        case .mild:         return "II"
        case .moderate:     return "III"
        case .severe:       return "IV"
        }
    }

    private func hit6ImpactColor(_ impact: HIT6Score.Impact) -> UIColor {
        switch impact {
        case .little:      return greenColor
        case .some:        return amberColor
        case .substantial: return orangeColor
        case .severe:      return redColor
        }
    }

    private func hit6FrequencyLabel(_ score: Int) -> String {
        switch score {
        case 6:  return "Never"
        case 8:  return "Rarely"
        case 10: return "Sometimes"
        case 11: return "Very often"
        default: return "Always"
        }
    }

    private func mohLevelColor(_ level: MOHRiskAssessment.Level) -> UIColor {
        switch level {
        case .safe:       return greenColor
        case .approaching: return amberColor
        case .atRisk:     return orangeColor
        case .overuse:    return redColor
        }
    }

    // MARK: - Date formatting

    private func formatDate(_ date: Date, style: DateFormatter.Style) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = style
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func reportDateStamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        return fmt.string(from: date)
    }
}
