//
//  ReportViewModel.swift
//  MigraineIQ
//

import Foundation

@Observable
@MainActor
final class ReportViewModel {

    // MARK: - State

    enum ViewState: Equatable {
        case idle
        case generating
        case generated(URL)
        case failed(String)
    }

    private(set) var viewState: ViewState = .idle

    // MARK: - Dependencies

    private let generateReportUseCase: GenerateDoctorReportUseCase
    private let renderer:              DoctorReportPDFRenderer

    // MARK: - Init

    init(
        generateReportUseCase: GenerateDoctorReportUseCase,
        renderer:              DoctorReportPDFRenderer
    ) {
        self.generateReportUseCase = generateReportUseCase
        self.renderer              = renderer
    }

    // MARK: - Actions

    func generate() async {
        viewState = .generating
        do {
            let report = try await generateReportUseCase.execute()
            let url    = try renderer.render(report: report)
            viewState  = .generated(url)
        } catch {
            viewState = .failed(ErrorPresenter.userMessage(for: error))
        }
    }

    func reset() {
        viewState = .idle
    }
}
