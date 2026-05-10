//
//  ReportContentView.swift
//  MigraineIQ
//
//  Generates a 90-day clinical PDF and displays it inline with a Share
//  button. Accessed from Settings → "Generate Report".
//

import SwiftUI
import PDFKit

struct ReportContentView: View {

    @State var viewModel: ReportViewModel
    @State private var showShareSheet = false
    @State private var showPaywall = false

    private var isPro: Bool { SubscriptionManager.shared.isProSubscriber }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                if !isPro {
                    lockedView
                } else {
                    switch viewModel.viewState {
                    case .idle:
                        idleView

                    case .generating:
                        generatingView

                    case .generated(let url):
                        pdfPreview(url: url)

                    case .failed(let message):
                        errorView(message: message)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .navigationTitle("Clinical Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarItems }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Locked (free tier)

    private var lockedView: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.8))

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Pro Feature")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text("Doctor-ready PDF reports with MIDAS, HIT-6, and a full attack log are available on MigraineIQ Pro.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            Button {
                showPaywall = true
            } label: {
                Label("Upgrade to Pro", systemImage: "crown.fill")
                    .font(AppTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.s)
                    .background(AppTheme.Colors.accent, in: Capsule())
            }
        }
        .padding(AppTheme.Spacing.xl)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: AppTheme.Spacing.l) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.8))

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("90-Day Clinical Report")
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text("Includes MIDAS disability score, HIT-6 headache impact, MOH risk assessment, and a full attack + medication log suitable for your neurologist.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            Button {
                Task { await viewModel.generate() }
            } label: {
                Label("Generate Report", systemImage: "wand.and.stars")
                    .font(AppTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.s)
                    .background(AppTheme.Colors.accent, in: Capsule())
            }
        }
        .padding(AppTheme.Spacing.xl)
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            ProgressView()
                .tint(AppTheme.Colors.accent)
                .scaleEffect(1.5)
            Text("Building your report…")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    // MARK: - PDF preview

    private func pdfPreview(url: URL) -> some View {
        PDFKitView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(url: url)
            }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.Colors.riskHigh)
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            Button("Try Again") {
                viewModel.reset()
            }
            .foregroundStyle(AppTheme.Colors.accent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if case .generated(let url) = viewModel.viewState {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
        if case .generated = viewModel.viewState {
            ToolbarItem(placement: .topBarLeading) {
                Button("New Report") {
                    viewModel.reset()
                }
                .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }
}

// MARK: - PDFKitView (UIViewRepresentable)

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales   = true
        pdfView.displayMode  = .singlePageContinuous
        pdfView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1)
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - ShareSheet (UIViewControllerRepresentable)

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ReportContentView(
        viewModel: ReportViewModel(
            generateReportUseCase: GenerateDoctorReportUseCase(
                headacheRepository:   MockHeadacheRepository(),
                medicationRepository: MockMedicationRepository()
            ),
            renderer: DoctorReportPDFRenderer()
        )
    )
}
