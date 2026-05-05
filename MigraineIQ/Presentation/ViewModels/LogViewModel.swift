//
//  LogViewModel.swift
//  MigraineIQ
//
//  Phase 1 stub. Provides a minimal "start an attack now" flow that proves
//  the write path works end-to-end. Phase 3 will replace this with the
//  full intensity / location / quality / symptoms / aura form.
//

import Foundation
import Observation

@Observable
@MainActor
final class LogViewModel {
    enum ViewState: Equatable {
        case idle
        case saving
        case saved
        case failure(String)
    }

    private(set) var viewState: ViewState = .idle
    var draftIntensity: Int = 5
    var draftClassification: ICHD3Classification = .undetermined

    private let headacheRepository: HeadacheRepositoryProtocol

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.headacheRepository = headacheRepository
    }

    func quickLog() async {
        viewState = .saving
        let event = HeadacheEvent(
            startedAt: Date(),
            intensity: draftIntensity,
            classification: draftClassification,
            phase: .headache
        )
        do {
            try await headacheRepository.save(event)
            viewState = .saved
        } catch {
            viewState = .failure(ErrorPresenter.userMessage(for: error))
        }
    }

    func reset() {
        viewState = .idle
        draftIntensity = 5
        draftClassification = .undetermined
    }
}
