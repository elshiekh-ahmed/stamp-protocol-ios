import SwiftUI

@main
struct JOEYYApp: App {
    @State private var store: LoyaltyStore
    @State private var branding: MerchantBrandingStore
    @State private var business: PartnerStore
    @State private var screens = ScreenTracker()
    private let defaults: UserDefaults
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("accent") private var accent = AppAccent.orange.rawValue

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults: UserDefaults
        if arguments.contains("-ui-testing"),
           let testDefaults = UserDefaults(suiteName: "com.joeyy.ui-tests") {
            if arguments.contains("-reset-demo") {
                testDefaults.removePersistentDomain(forName: "com.joeyy.ui-tests")
            }
            defaults = testDefaults
        } else {
            defaults = .standard
        }
        self.defaults = defaults
        _appearance = AppStorage(wrappedValue: "System", "appearance", store: defaults)
        _accent = AppStorage(wrappedValue: AppAccent.orange.rawValue, "accent", store: defaults)
        _store = State(initialValue: LoyaltyStore(
            defaults: defaults, reset: arguments.contains("-reset-demo")
        ))
        let directory = URL.applicationSupportDirectory.appendingPathComponent(
            arguments.contains("-ui-testing") ? "TestBrandingPreviews" : "BrandingPreviews"
        )
        let branding = MerchantBrandingStore(defaults: defaults, directory: directory)
        if arguments.contains("-ui-testing") && arguments.contains("-reset-demo") {
            do { try branding.clear() }
            catch { assertionFailure("Could not reset test artwork: \(error.localizedDescription)") }
        }
        _branding = State(initialValue: branding)
        let business = PartnerStore(
            fileURL: PartnerStore.fileURL(testing: arguments.contains("-ui-testing")),
            reset: arguments.contains("-ui-testing") && arguments.contains("-reset-demo")
        )
        if arguments.contains("-ui-testing") && arguments.contains("-business-sample") {
            business.loadNoremaSample()
        }
        _business = State(initialValue: business)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(branding)
                .environment(business)
                .environment(screens)
                .defaultAppStorage(defaults)
                .environment(\.appAccent, AppAccent(rawValue: accent) ?? .orange)
                .tint((AppAccent(rawValue: accent) ?? .orange).color)
                .accentColor((AppAccent(rawValue: accent) ?? .orange).color)
                .environment(
                    \.simulatingReducedMotion,
                    ProcessInfo.processInfo.arguments.contains("-ui-testing") &&
                    ProcessInfo.processInfo.arguments.contains("-reduce-motion")
                )
                .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
        }
    }
}

enum AppTab: Hashable {
    case home, search, redeemed, you
}

struct RootView: View {
    @Environment(LoyaltyStore.self) private var store
    @Environment(MerchantBrandingStore.self) private var branding
    @Environment(PartnerStore.self) private var business
    @AppStorage("hasSeenWelcome") private var hasCompletedSetup = false
    @State private var tab = AppTab.home
    /// The side chosen on the setup landing; reopened on the next launch.
    @AppStorage("experience") private var experience = Experience.customer
    @State private var setupEntry: SetupEntry?
    @State private var homeEntry = UUID()

    var body: some View {
        Group {
            switch experience {
            case .customer:
                TabView(selection: $tab) {
                    Tab("Home", systemImage: "house", value: .home) {
                        HomeView(tab: $tab)
                            .id(homeEntry)
                    }
                    Tab("Search", systemImage: "magnifyingglass", value: .search) {
                        SearchView()
                    }
                    Tab("Redeemed", systemImage: "ticket", value: .redeemed) {
                        RedeemedView()
                    }
                    .badge(store.redemptions.filter(\.isAvailable).count)
                    Tab("You", systemImage: "person.crop.circle", value: .you) {
                        ProfileView(onSetup: { setupEntry = .replay })
                    }
                }
            case .business:
                BusinessRootView(onSetup: { setupEntry = .replay })
            }
        }
        .onAppear {
            if experience == .customer && !hasCompletedSetup
                && !ProcessInfo.processInfo.arguments.contains("-skip-welcome") {
                setupEntry = .install
            }
        }
        .fullScreenCover(item: $setupEntry) { entry in
            SetupView(
                onCustomer: {
                    hasCompletedSetup = true
                    experience = .customer
                    homeEntry = UUID()
                    tab = .home
                    setupEntry = nil
                },
                onBusiness: {
                    experience = .business
                    setupEntry = nil
                },
                onClose: entry == .replay ? { setupEntry = nil } : nil
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = store.storageError ?? branding.storageError ?? (experience == .business ? business.storageError : nil) {
                Text(error)
                    .font(.footnote)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.surface)
                    .accessibilityAddTraits(.isStaticText)
            }
        }

    }

    private enum Experience: String {
        case customer, business
    }

    private enum SetupEntry: String, Identifiable {
        case install, replay

        var id: String { rawValue }
    }
}
