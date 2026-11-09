import PhotosUI
import SwiftUI
import UIKit

struct BusinessProfileView: View {
    var body: some View {
        NavigationStack {
            BusinessEditor(mode: .edit)
        }
    }
}

struct BusinessEditor: View {
    enum Mode { case setup, edit }

    let mode: Mode
    @Environment(PartnerStore.self) private var store
    @Environment(\.appAccent) private var accent
    @State private var name = ""
    @State private var location = ""
    @State private var logoPNG: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var hasLoaded = false
    @State private var loadingLogo = false
    @State private var feedback: String?
    @State private var errorMessage: String?

    private var hasChanges: Bool {
        guard let business = store.business else { return true }
        return name.trimmingCharacters(in: .whitespacesAndNewlines) != business.name
            || location != business.location
            || logoPNG != business.logoPNG
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasChanges && !loadingLogo
    }

    var body: some View {
        Form {
            Section {
                if mode == .edit {
                    PageHeader("Business", identifier: "heading.business")
                } else {
                    PageTitle(text: "Your business")
                    Text("Customers see this name and logo on your card. You can change it later.")
                        .font(.subheadline)
                        .foregroundStyle(Color.muted)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))

            if let feedback {
                Section {
                    Label(feedback, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(accent.color)
                        .accessibilityIdentifier("business.feedback")
                }
            }

            Section {
                HStack(spacing: 16) {
                    ZStack {
                        LogoView(data: logoPNG, name: name, size: 72)
                        if loadingLogo { ProgressView() }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Text(logoPNG == nil ? "Choose logo" : "Replace logo")
                        }
                        .accessibilityIdentifier("business.logo")
                        if logoPNG != nil {
                            Button("Remove logo") { logoPNG = nil }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("Logo").foregroundStyle(.tint)
            } footer: {
                Text("Square images work best. Logos are resized and stored on this device.")
                    .foregroundStyle(Color.muted)
            }

            Section {
                TextField("Business name", text: $name)
                    .textContentType(.organizationName)
                    .accessibilityIdentifier("business.name")
            } header: {
                Text("Details").foregroundStyle(.tint)
            }

            Section {
                LocationField(location: $location)
            } header: {
                Text("Location").foregroundStyle(.tint)
            } footer: {
                Text("Choose your street address or your listing from Apple Maps so customers can find you. Typing a few letters, such as \u{201C}Sea\u{201D}, suggests matching places.")
                    .foregroundStyle(Color.muted)
            }

            if mode == .setup || hasChanges {
                Section {
                    Button(mode == .setup ? "Continue" : "Save changes") { save() }
                        .buttonStyle(PrimaryButton())
                        .disabled(!canSave)
                        .accessibilityIdentifier("business.save")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            if mode == .edit, let business = store.business {
                Section {
                    Text(business.id.uuidString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = business.id.uuidString
                        feedback = "Client ID copied."
                    } label: {
                        Label("Copy client ID", systemImage: "doc.on.doc")
                    }
                } header: {
                    Text("Client ID").foregroundStyle(.tint)
                } footer: {
                    Text("Customers search for a business by name or this ID. Your business isn't listed in customer search yet.")
                        .foregroundStyle(Color.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper.ignoresSafeArea())
        .toolbar(mode == .edit ? .hidden : .automatic, for: .navigationBar)
        .trackScreen(mode == .setup ? "Business setup" : "Business")
        .onAppear {
            if !hasLoaded { load() }
        }
        .onChange(of: pickerItem) { loadPickedLogo() }
        .onChange(of: name) { if hasChanges { feedback = nil } }
        .onChange(of: location) { if hasChanges { feedback = nil } }
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        if let business = store.business {
            name = business.name
            location = business.location
            logoPNG = business.logoPNG
        }
        hasLoaded = true
    }

    private func loadPickedLogo() {
        guard let item = pickerItem else { return }
        loadingLogo = true
        Task {
            defer {
                loadingLogo = false
                pickerItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let png = LogoProcessor.normalizedPNG(from: data) else {
                    errorMessage = PartnerError.invalidLogo.localizedDescription
                    return
                }
                logoPNG = png
                feedback = nil
            } catch {
                errorMessage = PartnerError.invalidLogo.localizedDescription
            }
        }
    }

    private func save() {
        do {
            try store.saveBusiness(name: name, location: location, logoPNG: logoPNG)
            load()
            if mode == .edit { feedback = "Business saved." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
