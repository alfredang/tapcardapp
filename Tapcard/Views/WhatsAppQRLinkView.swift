import SwiftUI
import PhotosUI
import Vision

/// Settings → Sharing → WhatsApp QR. Your WhatsApp contact link can't be made
/// by another app — WhatsApp issues it — so it's brought over from WhatsApp:
/// read off a screenshot of its QR code screen, or pasted. Once saved, the
/// WhatsApp QR on the Cards tab is the same code WhatsApp shows.
struct WhatsAppQRLinkView: View {
    @Environment(AccountStore.self) private var account
    @State private var entry = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var message: String?

    private var saved: String { account.preferences.whatsappQr }
    /// The link in the field, normalised, or nil while it holds none.
    private var link: String? { WhatsAppLink.contactLink(in: entry) }

    var body: some View {
        Form {
            if !saved.isEmpty {
                Section {
                    QRCodeImage(payload: saved, mode: .whatsapp)
                        .frame(width: 170, height: 170)
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1))
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .accessibilityLabel("Your WhatsApp QR code")
                } footer: {
                    Text("Scanning this adds you as a WhatsApp contact, the same as the code in WhatsApp.")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }

            Section {
                PhotosPicker(selection: $photoItem, matching: .screenshots) {
                    Label("Read from a screenshot", systemImage: "photo.on.rectangle")
                }
                Button {
                    entry = UIPasteboard.general.string ?? ""
                    message = link == nil ? "The clipboard has no WhatsApp QR link." : nil
                } label: {
                    Label("Paste link", systemImage: "doc.on.clipboard")
                }
                TextField("https://wa.me/qr/…", text: $entry, axis: .vertical)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                } else if !entry.trimmed.isEmpty && link == nil {
                    Text("That isn't a WhatsApp QR link — it looks like wa.me/qr/…")
                        .font(.footnote).foregroundStyle(.red)
                }
            } header: {
                Text(saved.isEmpty ? "Add your WhatsApp QR" : "Replace it")
            } footer: {
                Text("In WhatsApp, open Settings and tap the QR icon next to your name. Take a screenshot of the code, or tap share and copy the link, then come back here.")
            }

            Section {
                Button {
                    save(link)
                } label: {
                    HStack {
                        Text("Save")
                        if isSaving { Spacer(); ProgressView() }
                    }
                }
                .disabled(link == nil || link == saved || isSaving)

                if !saved.isEmpty {
                    Button("Remove — open a chat instead", role: .destructive) {
                        save("")
                    }
                    .disabled(isSaving)
                }
            } footer: {
                Text("Without it, your WhatsApp QR opens a chat with you and an intro message ready to send.")
            }
        }
        .navigationTitle("WhatsApp QR")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await read(item) }
        }
    }

    private func save(_ value: String?) {
        guard let value, !isSaving else { return }
        isSaving = true
        message = nil
        Task {
            message = await account.updatePreferences(whatsappQr: value)
            if message == nil { entry = "" }
            isSaving = false
        }
    }

    /// Find the WhatsApp contact link in a screenshot's QR code.
    private func read(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)?.cgImage else {
            message = "Couldn't open that image."
            return
        }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: image).perform([request])
        let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
        if let found = payloads.lazy.compactMap(WhatsAppLink.contactLink(in:)).first {
            entry = found
            message = nil
        } else {
            message = payloads.isEmpty
                ? "No QR code found in that image."
                : "That QR code isn't a WhatsApp contact code."
        }
    }
}
