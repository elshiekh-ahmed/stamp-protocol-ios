import SwiftUI

struct ProfileView: View {
    let onSetup: () -> Void
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("accent") private var accent = AppAccent.orange.rawValue
    @AppStorage("rewardReminders") private var rewardReminders = false
    @AppStorage("newsAndOffers") private var newsAndOffers = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PageTitle(text: "You")
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
                }

                Section {
                    Toggle("Reward reminders", isOn: $rewardReminders)
                    Toggle("News & offers", isOn: $newsAndOffers)
                } header: {
                    Text("Notifications").foregroundStyle(.tint)
                } footer: {
                    Text("Notifications aren't connected yet.")
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
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
