import PhotosUI
import SwiftUI

struct CardDesignerView: View {
    @Environment(PartnerStore.self) private var store
    @Environment(\.appAccent) private var accent
    @State private var draft = ProgramDraft.starter
    @State private var hasLoaded = false
    @State private var previewStamps = 4
    @State private var confirmingPublish = false
    @State private var coverItem: PhotosPickerItem?
    @State private var loadingCover = false
    @State private var feedback: String?
    @State private var failure: String?

    private var current: ProgramVersion? { store.currentProgram }

    private var hasChanges: Bool {
        guard let current else { return true }
        return !draft.matches(current)
    }

    private var validationMessage: String? {
        do {
            _ = try draft.validated()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var canPublish: Bool { hasChanges && validationMessage == nil && !loadingCover }

    private var reward: String { draft.rewardDescription.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var previewPlace: Place {
        .businessPreview(
            business: store.business, requiredPunches: draft.requiredPunches,
            reward: reward, artwork: draft.design.theme.artwork
        )
    }

    /// Explains which customers keep their current rules and which get the new version.
    private var publishImpact: String {
        guard current != nil else {
            return "Publishing makes this card available to new customers."
        }
        let next = store.nextVersionNumber
        let impact = store.publishImpact()
        func cards(_ count: Int) -> String { count == 1 ? "1 card" : "\(count) cards" }
        return """
            Publishing creates version \(next). \(cards(impact.keepRules)) with stamps keep the rules and \
            look they started with until complete, so no customer loses progress. \
            \(cards(impact.switchToNew)) with no stamps yet, new customers, and customers starting their \
            next card get version \(next).
            """
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        PageHeader("Card", identifier: "heading.card")
                        Text(current.map {
                            "Version \($0.version) is live / published \($0.publishedAt.formatted(date: .abbreviated, time: .omitted))"
                        } ?? "Design your card and publish it so customers can start collecting.")
                            .font(.subheadline)
                            .foregroundStyle(Color.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    VStack(alignment: .leading, spacing: 20) {
                        BusinessCardTile(
                            name: store.business?.name ?? "Your business",
                            location: store.business?.location ?? "",
                            reward: reward, requiredPunches: draft.requiredPunches, design: draft.design,
                            detail: "\(min(previewStamps, draft.requiredPunches)) of \(draft.requiredPunches) punches"
                        )
                        PunchCard(
                            place: previewPlace, stamps: min(previewStamps, draft.requiredPunches),
                            themeOverride: draft.design.theme
                        )
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .accessibilityIdentifier("card.preview")
                    Stepper(
                        "Preview \(min(previewStamps, draft.requiredPunches)) of \(draft.requiredPunches) stamps",
                        value: $previewStamps, in: 0...draft.requiredPunches
                    )
                } header: {
                    Text("How customers see it").foregroundStyle(.tint)
                } footer: {
                    Text("Home collection tile and punch card, as rendered in the customer app. Preview stamps aren't saved.")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    Stepper(value: $draft.requiredPunches, in: ProgramDraft.punchRange) {
                        LabeledContent("Stamps for a reward") {
                            Text("\(draft.requiredPunches)").monospacedDigit().foregroundStyle(accent.color)
                        }
                    }
                    .accessibilityIdentifier("card.punches")
                    TextField("Reward, such as Espresso", text: $draft.rewardDescription)
                        .accessibilityIdentifier("card.reward")
                } header: {
                    Text("Rules").foregroundStyle(.tint)
                } footer: {
                    Text("Choose \(ProgramDraft.punchRange.lowerBound)–\(ProgramDraft.punchRange.upperBound) stamps. Customers collect one per visit and claim this reward when the card is full.")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    PalettePicker(theme: $draft.design.theme)
                    Picker("Typeface", selection: $draft.design.theme.typeface) {
                        ForEach(MerchantTheme.Typeface.allCases, id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }
                    .accessibilityIdentifier("card.typeface")
                    Picker("Card stock", selection: $draft.design.theme.artwork) {
                        ForEach(MerchantTheme.Artwork.allCases, id: \.self) {
                            Text($0.stockName).tag($0)
                        }
                    }
                    .accessibilityIdentifier("card.stock")
                    Toggle("Card motion", isOn: $draft.design.theme.allowsMotion)
                } header: {
                    Text("Design").foregroundStyle(.tint)
                } footer: {
                    Text("Colors are paired for light and dark mode with readable contrast. Reduce Motion on a customer's device always turns motion off.")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    PhotosPicker(selection: $coverItem, matching: .images, photoLibrary: .shared()) {
                        Text(draft.design.coverJPEG == nil ? "Choose cover photo" : "Replace cover photo")
                            .frame(minHeight: 44)
                    }
                    .disabled(loadingCover)
                    .accessibilityIdentifier("card.cover")
                    if loadingCover { ProgressView("Preparing image...") }
                    if draft.design.coverJPEG != nil {
                        Button("Use original artwork") { draft.design.coverJPEG = nil }
                    }
                } header: {
                    Text("Cover").foregroundStyle(.tint)
                } footer: {
                    Text("Without a photo, customers see artwork generated from your colors and card stock. Photos stay on this device.")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    if let feedback {
                        Label(feedback, systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("card.feedback")
                    }
                    if hasChanges, let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.muted)
                    }
                    if hasChanges {
                        Button(current == nil ? "Publish card" : "Publish version \(store.nextVersionNumber)") {
                            if current == nil { publish() } else { confirmingPublish = true }
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(!canPublish)
                        .accessibilityIdentifier("card.publish")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } else if feedback == nil {
                        Text("No changes to publish.")
                            .font(.subheadline)
                            .foregroundStyle(Color.muted)
                            .accessibilityIdentifier("card.upToDate")
                    }
                    if current != nil && hasChanges {
                        Button("Discard changes") { loadDraft() }
                            .buttonStyle(TextButton())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .listRowBackground(Color.clear)
                    }
                } footer: {
                    Text(publishImpact).accessibilityIdentifier("card.impact")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    Button {} label: {
                        Label("Add to Apple Wallet", systemImage: "wallet.pass")
                    }
                    .buttonStyle(SecondaryButton())
                    .disabled(true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .accessibilityIdentifier("card.wallet")
                } header: {
                    Text("Apple Wallet").foregroundStyle(.tint)
                } footer: {
                    Text("Not available yet. Wallet passes must be signed with an Apple Developer certificate before iPhone accepts them.")
                        .foregroundStyle(Color.muted)
                }

                if !store.versionsNewestFirst.isEmpty {
                    Section {
                        NavigationLink {
                            VersionHistoryView()
                        } label: {
                            LabeledContent("Published versions", value: "\(store.versionsNewestFirst.count)")
                        }
                        .accessibilityIdentifier("card.history")
                    } header: {
                        Text("History").foregroundStyle(.tint)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .trackScreen("Card designer")
            .onAppear {
                if !hasLoaded { loadDraft() }
            }
            .onChange(of: current?.id) { loadDraft() }
            .onChange(of: draft) {
                if hasChanges { feedback = nil }
            }
            .task(id: coverItem) {
                guard let coverItem else { return }
                loadingCover = true
                defer {
                    loadingCover = false
                    self.coverItem = nil
                }
                do {
                    guard let data = try await coverItem.loadTransferable(type: Data.self) else { return }
                    let prepared = try await Task.detached { try ArtworkLoader.prepare(data) }.value
                    draft.design.coverJPEG = prepared
                } catch is CancellationError {
                    // Choosing another photo replaces this one.
                } catch {
                    failure = error.localizedDescription
                }
            }
            .confirmationDialog(
                "Publish version \(store.nextVersionNumber)?",
                isPresented: $confirmingPublish, titleVisibility: .visible
            ) {
                Button("Publish version \(store.nextVersionNumber)") { publish() }
            } message: {
                Text(publishImpact)
            }
            .alert("Couldn't update the card", isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private func loadDraft() {
        draft = current.map(ProgramDraft.init(version:)) ?? .starter
        hasLoaded = true
    }

    private func publish() {
        do {
            let version = try store.publish(draft)
            loadDraft()
            feedback = version.version == 1 ? "Card published." : "Version \(version.version) published."
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// Contrast-checked color pairs, shown as card swatches.
private struct PalettePicker: View {
    @Binding var theme: MerchantTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card colors")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 16) {
                ForEach(CardPalette.all) { palette in
                    let selected = palette.matches(theme)
                    Button {
                        palette.apply(to: &theme)
                    } label: {
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.adaptive(light: palette.lightPaper, dark: palette.darkPaper))
                                .frame(width: 44, height: 32)
                                .overlay {
                                    Text("Aa")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.adaptive(light: palette.lightInk, dark: palette.darkInk))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(selected ? Color.primary : Color.rule, lineWidth: selected ? 2 : 1)
                                }
                            Text(palette.name).font(.caption).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(palette.name) colors")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("card.palette.\(palette.name)")
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct VersionHistoryView: View {
    @Environment(PartnerStore.self) private var store

    var body: some View {
        Form {
            Section {
                Notice(
                    symbol: "arrow.triangle.branch",
                    title: "How versions work",
                    message: "A card with stamps keeps the rules and look of its version until it's complete, so customers never lose progress. Cards with no stamps yet switch to a newly published version. Every new card uses the live version."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            ForEach(store.versionsNewestFirst) { version in
                let usage = store.usage(of: version)
                Section {
                    LabeledContent("Status") {
                        Text(statusText(usage.status)).foregroundStyle(.tint)
                    }
                    .accessibilityIdentifier("history.status.\(version.version)")
                    LabeledContent("Rule", value: "\(version.requiredPunches) stamps")
                    LabeledContent("Reward", value: version.rewardDescription)
                    LabeledContent("Cards in progress", value: "\(usage.inProgress)")
                    LabeledContent("Cards completed", value: "\(usage.completed)")
                } header: {
                    HStack {
                        Text("Version \(version.version)").foregroundStyle(.tint)
                        Spacer()
                        Text(version.publishedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } footer: {
                    Text(statusDetail(usage))
                        .foregroundStyle(Color.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper.ignoresSafeArea())
        .appNavigationTitle("Version history")
        .toolbar(.visible, for: .navigationBar)
        .trackScreen("Version history")
    }

    private func statusText(_ status: VersionUsage.Status) -> String {
        switch status {
        case .live: "Live"
        case .finishing: "Finishing"
        case .retired: "Retired"
        }
    }

    private func statusDetail(_ usage: VersionUsage) -> String {
        switch usage.status {
        case .live:
            "New cards are issued under this version."
        case .finishing:
            "No longer issued. \(usage.inProgress == 1 ? "1 customer is" : "\(usage.inProgress) customers are") still completing cards under these rules."
        case .retired:
            "No longer issued, and every card under this version is complete."
        }
    }
}
