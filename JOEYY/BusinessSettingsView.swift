import SwiftUI

/// The business side's You tab, matching the customer ProfileView with business-only sections.
struct BusinessSettingsView: View {
    let onSetup: () -> Void
    @Environment(PartnerStore.self) private var store
    @Environment(ScreenTracker.self) private var tracker
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("accent") private var accent = AppAccent.orange.rawValue
    @State private var confirmingSample = false
    @State private var confirmingStartOver = false
    @State private var reportingBug = false

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PageHeader("You", identifier: "heading.businessYou")
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(["System", "Light", "Dark"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .accessibilityIdentifier("settings.appearance")
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Accent color")
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 16) {
                            ForEach(AppAccent.allCases) { option in
                                Button {
                                    accent = option.rawValue
                                } label: {
                                    VStack(spacing: 7) {
                                        Circle()
                                            .fill(option.solidColor)
                                            .frame(width: 36, height: 36)
                                            .overlay {
                                                if accent == option.rawValue {
                                                    Image(systemName: "checkmark")
                                                        .font(.body.weight(.semibold))
                                                        .foregroundStyle(option.onSolidColor)
                                                }
                                            }
                                        Text(option.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.rawValue + " accent")
                                .accessibilityAddTraits(accent == option.rawValue ? .isSelected : [])
                                .accessibilityIdentifier("settings.accent.\(option.rawValue)")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Appearance").foregroundStyle(.tint)
                } footer: {
                    Text("Shared with the customer side. Your customers' card colors are set in Card.")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    Button(action: onSetup) {
                        HStack {
                            Text("Customer or business")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.subheadline)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("settings.setup")
                } header: {
                    Text("App setup").foregroundStyle(.tint)
                }

                Section {
                    Button(action: { reportingBug = true }) {
                        HStack {
                            Text("Report a bug")
                            Spacer()
                            Image(systemName: "ladybug").font(.subheadline)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("settings.bug")
                } header: {
                    Text("Feedback").foregroundStyle(.tint)
                } footer: {
                    Text("Opens a pre-filled GitHub issue with the app version, your device, and the current screen.")
                        .foregroundStyle(Color.muted)
                }

                Section {
                    Button("Load Norema Cafe sample") { confirmingSample = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.sample")
                    Button("Start over", role: .destructive) { confirmingStartOver = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.startOver")
                } header: {
                    Text("Sample data").foregroundStyle(.tint)
                } footer: {
                    Text("Business preview \(versionLabel). Business data stays on this device. Sign-in, live customer activity, and Wallet passes aren't connected yet. Norema Cafe activity is fictional.")
                        .foregroundStyle(Color.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .trackScreen("Business You")
            .sheet(isPresented: $reportingBug) {
                BugReportView(screen: tracker.current)
            }
            .confirmationDialog("Load the Norema Cafe sample?", isPresented: $confirmingSample, titleVisibility: .visible) {
                Button("Replace with sample", role: .destructive) { store.loadNoremaSample() }
            } message: {
                Text("Replaces this device's business, card versions, and activity with fictional Norema Cafe data.")
            }
            .confirmationDialog("Start over?", isPresented: $confirmingStartOver, titleVisibility: .visible) {
                Button("Delete business and activity", role: .destructive) { store.startOver() }
            } message: {
                Text("Removes the business, card versions, and activity from this device. Customer cards and appearance settings stay.")
            }
        }
    }
}
