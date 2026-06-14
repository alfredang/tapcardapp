import SwiftUI

/// Full-screen flow: scan → recognize → review/edit → publish → result.
struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountStore.self) private var account
    @State private var model = ScanViewModel()
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .idle:
                    startScreen
                case .recognizing:
                    progress("Reading the card…")
                case .review:
                    ReviewCardView(model: model)
                case .submitting:
                    progress("Setting up your digital card…")
                case .done(let result):
                    CardResultView(result: result) { dismiss() }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isTerminal {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                CardScannerView(
                    onScan: { image in
                        showScanner = false
                        Task { await model.handleScanned(image: image) }
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled(model.stage == .submitting)
    }

    private var title: String {
        switch model.stage {
        case .idle: "Scan"
        case .recognizing, .review: "Review details"
        case .submitting: "Publishing"
        case .done: "Your card is live"
        }
    }

    private var isTerminal: Bool {
        if case .done = model.stage { return true }
        return false
    }

    private var startScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.dashed.and.paperclip")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: Constants.accentHex))
            Text("Point your camera at a business card")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("VisionKit captures and straightens the card, then it's read on-device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button {
                showScanner = true
            } label: {
                Label("Open camera", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            Button("Enter details manually") {
                model.startManualEntry()
            }
            .font(.subheadline)
        }
        .padding()
        .onAppear {
            // Auto-open the scanner the first time the flow appears.
            if model.stage == .idle && !showScanner {
                showScanner = true
            }
        }
    }

    private func progress(_ message: String) -> some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(message).font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
