//
//  CalendarView.swift
//  MigraineIQ
//
//  Shell — reads DependencyContainer from the environment and creates
//  the CalendarViewModel, then hands it to CalendarContentView.
//

import SwiftUI

struct CalendarView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        CalendarContentView(viewModel: container.makeCalendarViewModel())
    }
}
