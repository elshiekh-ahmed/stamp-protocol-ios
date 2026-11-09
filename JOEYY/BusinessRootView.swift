import SwiftUI

enum BusinessTab: Hashable {
    case overview, card, business, you
}

/// The business side of JOEYY, opened from the setup landing's Business destination.
struct BusinessRootView: View {
    let onSetup: () -> Void
    @Environment(PartnerStore.self) private var store
    @State private var tab = BusinessTab.overview

    var body: some View {
        Group {
            if store.business == nil {
                BusinessWelcomeView(onSetup: onSetup)
            } else {
                TabView(selection: $tab) {
                    Tab("Overview", systemImage: "chart.bar", value: .overview) {
                        OverviewView(tab: $tab)
                    }
                    Tab("Card", systemImage: "rectangle.portrait.on.rectangle.portrait", value: .card) {
                        CardDesignerView()
                    }
                    Tab("Business", systemImage: "storefront", value: .business) {
                        BusinessProfileView()
                    }
                    Tab("You", systemImage: "person.crop.circle", value: .you) {
                        BusinessSettingsView(onSetup: onSetup)
                    }
                }
            }
        }
        .onChange(of: store.business == nil) { tab = .overview }
    }
}

/// First business screen: set up a business or explore the Norema Cafe sample.
struct BusinessWelcomeView: View {
    let onSetup: () -> Void
    @Environment(PartnerStore.self) private var store
    @State private var settingUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 4) {
                        BrandMark()
                        Spacer()
                        Button("Customer or business", action: onSetup)
                            .font(.subheadline)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("business.switch")
                        BugReportButton()
                    }
                    PageTitle(text: "Business")
                        .accessibilityIdentifier("heading.businessWelcome")
                    BusinessCardTile(
                        name: "Your business", location: "Seattle", reward: "Your reward",
                        requiredPunches: 10, design: .starter, detail: "4 of 10 punches"
                    )
                    .accessibilityHidden(true)
                    VStack(spacing: 16) {
                        BusinessDestination(
                            title: "Set up a business", subtitle: "Name, location, and logo",
                            symbol: "storefront", identifier: "business.setup"
                        ) {
                            settingUp = true
                        }
                        BusinessDestination(
                            title: "Explore a sample", subtitle: "Norema Cafe, with fictional activity",
                            symbol: "cup.and.saucer", identifier: "business.sample"
                        ) {
                            store.loadNoremaSample()
                        }
                    }
                    Notice(
                        symbol: "iphone",
                        title: "Stays on this device",
                        message: "Set the stamps a reward takes, design the card customers collect, and see how often they come back. Sign-in and live customer activity aren't connected yet."
                    )
                }
                .padding(24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background { AppBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .trackScreen("Business welcome")
            .sheet(isPresented: $settingUp) {
                NavigationStack {
                    BusinessEditor(mode: .setup)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { settingUp = false }
                            }
                        }
                }
            }
        }
    }
}
